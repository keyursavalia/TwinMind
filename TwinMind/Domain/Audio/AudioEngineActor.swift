//
//  AudioEngineActor.swift
//  TwinMind
//
//  Purpose: Actor managing AVAudioEngine lifecycle and real-time segmentation.
//  Design decision: Actor isolation ensures thread-safe access to AVAudioEngine.
//  Rolling 30s file writer with encryption at boundary prevents data loss.
//

import Foundation
import AVFAudio
internal import os

/// Actor managing audio recording with AVAudioEngine and real-time segmentation.
///
/// This actor handles all audio session configuration, engine lifecycle, interruption
/// recovery, route changes, and automatic 30-second segment creation with encryption.
public actor AudioEngineActor: AudioEngineProtocol {

    // MARK: - Properties

    /// The AVAudio engine instance.
    private let audioEngine: AVAudioEngine

    /// The audio session.
    private let audioSession: AVAudioSession

    /// Current recording state.
    private var _currentState: RecordingState = .idle

    /// Current audio route information.
    private var _currentRoute: AudioRouteInfo = .default

    /// Current session ID.
    private var currentSessionId: UUID?

    /// Current recording quality.
    private var currentQuality: RecordingQuality?

    /// Current segment writer.
    private var segmentWriter: AudioSegmentWriter?

    /// Event stream continuation.
    private var eventContinuation: AsyncStream<AudioEngineEvent>.Continuation?

    /// The audio file manager.
    private let audioFileManager: AudioFileManager

    /// The encryption service.
    private let encryptionService: any EncryptionServiceProtocol

    /// Observation tokens for notifications.
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var configChangeObserver: NSObjectProtocol?

    // MARK: - Initialization

    /// Creates a new audio engine actor.
    ///
    /// - Parameters:
    ///   - audioFileManager: File manager for segment paths.
    ///   - encryptionService: Service for encrypting audio files.
    public init(
        audioFileManager: AudioFileManager,
        encryptionService: any EncryptionServiceProtocol
    ) {
        self.audioEngine = AVAudioEngine()
        self.audioSession = AVAudioSession.sharedInstance()
        self.audioFileManager = audioFileManager
        self.encryptionService = encryptionService

        AppLogger.audio.info("AudioEngineActor initialized")

        // Register for notifications
        Task {
            await registerNotifications()
        }
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Protocol Properties

    public nonisolated var eventStream: AsyncStream<AudioEngineEvent> {
        AsyncStream { continuation in
            Task {
                await setEventContinuation(continuation)
            }
        }
    }

    private func setEventContinuation(_ continuation: AsyncStream<AudioEngineEvent>.Continuation) {
        self.eventContinuation = continuation
    }

    public var currentState: RecordingState {
        _currentState
    }

    public var currentRoute: AudioRouteInfo {
        _currentRoute
    }

    // MARK: - Recording Control

    public func startRecording(sessionId: UUID, quality: RecordingQuality) async throws {
        guard _currentState.canStartRecording else {
            throw AppError.audioEngineFailure(reason: "Cannot start recording in current state: \(_currentState.displayString)")
        }

        AppLogger.audio.info("Starting recording session: \(sessionId.uuidString) with quality: \(quality.rawValue)")

        currentSessionId = sessionId
        currentQuality = quality

        // Configure audio session
        try configureAudioSession()

        // Create session directory
        _ = try audioFileManager.createSessionDirectory(sessionId: sessionId)

        // Start the audio engine
        try startEngine()

        // Initialize segment writer
        let segmentURL = audioFileManager.segmentFilePath(sessionId: sessionId, segmentIndex: 0)
        segmentWriter = try AudioSegmentWriter(
            outputURL: segmentURL,
            sampleRate: quality.sampleRate,
            channelCount: quality.channelCount,
            segmentDuration: quality.segmentDuration
        )

        // Install tap on input node
        try installInputTap(sessionId: sessionId, quality: quality)

        // Update state
        setState(.recording(startedAt: Date()))
    }

    public func stopRecording() async throws {
        guard _currentState.canStop else {
            throw AppError.audioEngineFailure(reason: "Cannot stop recording in current state: \(_currentState.displayString)")
        }

        AppLogger.audio.info("Stopping recording")

        // Flush final segment
        if let writer = segmentWriter {
            try await writer.finalize(
                sessionId: currentSessionId!,
                encryptionService: encryptionService,
                audioFileManager: audioFileManager
            ) { job in
                emitSegmentReady(job)
            }
        }

        // Stop engine
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        // Clean up
        segmentWriter = nil
        currentSessionId = nil
        currentQuality = nil

        // Update state
        setState(.completed(endedAt: Date()))
    }

    public func pauseRecording() async throws {
        guard _currentState.canPause else {
            throw AppError.audioEngineFailure(reason: "Cannot pause recording in current state: \(_currentState.displayString)")
        }

        AppLogger.audio.info("Pausing recording")

        // Remove tap and stop engine
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        // Update state
        setState(.paused(pausedAt: Date()))
    }

    public func resumeRecording() async throws {
        guard _currentState.canResume else {
            throw AppError.audioEngineFailure(reason: "Cannot resume recording in current state: \(_currentState.displayString)")
        }

        guard let sessionId = currentSessionId, let quality = currentQuality else {
            throw AppError.audioEngineFailure(reason: "Missing session context for resume")
        }

        AppLogger.audio.info("Resuming recording")

        // Restart engine
        try startEngine()

        // Reinstall tap
        try installInputTap(sessionId: sessionId, quality: quality)

        // Update state
        setState(.recording(startedAt: Date()))
    }

    // MARK: - Permissions

    public func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                AppLogger.audio.info("Microphone permission: \(granted ? "granted" : "denied")")
                continuation.resume(returning: granted)
            }
        }
    }

    public func checkMicrophonePermission() async -> Bool {
        switch audioSession.recordPermission {
        case .granted:
            return true
        case .denied, .undetermined:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Configuration

    public func updateQuality(_ quality: RecordingQuality) async throws {
        guard _currentState == .recording(startedAt: Date()) || _currentState == .paused(pausedAt: Date()) else {
            throw AppError.audioEngineFailure(reason: "Can only update quality during active session")
        }

        AppLogger.audio.info("Updating quality to: \(quality.rawValue)")

        // Finalize current segment
        if let writer = segmentWriter, let sessionId = currentSessionId {
            try await writer.finalize(
                sessionId: sessionId,
                encryptionService: encryptionService,
                audioFileManager: audioFileManager
            ) { job in
                emitSegmentReady(job)
            }
        }

        currentQuality = quality

        // If recording, reinstall tap with new quality
        if case .recording = _currentState {
            audioEngine.inputNode.removeTap(onBus: 0)
            try installInputTap(sessionId: currentSessionId!, quality: quality)
        }
    }

    // MARK: - Cleanup

    public func reset() async {
        AppLogger.audio.info("Resetting audio engine")

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        segmentWriter = nil
        currentSessionId = nil
        currentQuality = nil

        setState(.idle)
    }

    // MARK: - Private Helpers

    private func configureAudioSession() throws {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true)

            AppLogger.audio.info("Audio session configured successfully")

            // Update route info
            updateRouteInfo()

        } catch {
            AppLogger.audio.error("Failed to configure audio session", error: error)
            throw AppError.audioSessionConfigurationFailed(reason: error.localizedDescription)
        }
    }

    private func startEngine() throws {
        do {
            try audioEngine.start()
            AppLogger.audio.info("Audio engine started")
        } catch {
            AppLogger.audio.error("Failed to start audio engine", error: error)
            throw AppError.audioEngineFailure(reason: error.localizedDescription)
        }
    }

    private func installInputTap(sessionId: UUID, quality: RecordingQuality) throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AppError.audioEngineFailure(reason: "Invalid input format")
        }

        AppLogger.audio.debug("Installing tap: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            Task {
                await self?.processAudioBuffer(buffer: buffer, time: time, sessionId: sessionId, quality: quality)
            }
        }
    }

    private func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime, sessionId: UUID, quality: RecordingQuality) async {
        guard let writer = segmentWriter else { return }

        do {
            // Write buffer to segment file
            try writer.writeBuffer(buffer)

            // Calculate audio level
            let level = calculateAudioLevel(buffer: buffer)
            emitLevelUpdate(level)

            // Check if segment is complete
            if writer.shouldFinalize() {
                try await writer.finalize(
                    sessionId: sessionId,
                    encryptionService: encryptionService,
                    audioFileManager: audioFileManager
                ) { job in
                    emitSegmentReady(job)
                }

                // Start new segment
                let nextIndex = writer.segmentIndex + 1
                let nextURL = audioFileManager.segmentFilePath(sessionId: sessionId, segmentIndex: nextIndex)
                segmentWriter = try AudioSegmentWriter(
                    outputURL: nextURL,
                    sampleRate: quality.sampleRate,
                    channelCount: quality.channelCount,
                    segmentDuration: quality.segmentDuration,
                    segmentIndex: nextIndex,
                    startOffset: writer.totalDuration
                )
            }

        } catch {
            AppLogger.audio.error("Failed to process audio buffer", error: error)
            emitError(.audioFileWriteFailure(path: writer.currentURL.path, reason: error.localizedDescription))
        }
    }

    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0.0
        for frame in 0..<frameLength {
            let sample = channelDataValue[frame]
            sum += abs(sample)
        }

        let average = sum / Float(frameLength)
        return min(1.0, average * 10.0) // Normalize and amplify
    }

    private func updateRouteInfo() {
        let currentRoute = audioSession.currentRoute

        let inputPort = currentRoute.inputs.first
        let outputPort = currentRoute.outputs.first

        _currentRoute = AudioRouteInfo(
            inputDeviceName: inputPort?.portName ?? "Unknown",
            inputDeviceType: inputPort?.portType.rawValue ?? "Unknown",
            outputDeviceName: outputPort?.portName ?? "Unknown",
            outputDeviceType: outputPort?.portType.rawValue ?? "Unknown",
            isInputWireless: inputPort?.portType == .bluetoothHFP || inputPort?.portType == .bluetoothA2DP,
            isOutputWireless: outputPort?.portType == .bluetoothHFP || outputPort?.portType == .bluetoothA2DP
        )

        AppLogger.audio.debug("Route updated: \(self._currentRoute.inputDisplayString) → \(self._currentRoute.outputDisplayString)")
    }

    // MARK: - State Management

    private func setState(_ newState: RecordingState) {
        _currentState = newState
        eventContinuation?.yield(.stateChanged(newState))
        AppLogger.audio.info("State changed to: \(newState.displayString)")
    }

    private func emitSegmentReady(_ job: SegmentJob) {
        eventContinuation?.yield(.segmentReady(job))
        AppLogger.audio.info("Segment ready: index \(job.segmentIndex)")
    }

    private func emitLevelUpdate(_ level: Float) {
        eventContinuation?.yield(.levelUpdate(level))
    }

    private func emitError(_ error: AppError) {
        eventContinuation?.yield(.error(error))
        AppLogger.audio.error("Error emitted", error: error)
    }

    // MARK: - Notification Handlers

    private func registerNotifications() {
        let center = NotificationCenter.default

        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            Task {
                await self?.handleInterruption(notification)
            }
        }

        routeChangeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            Task {
                await self?.handleRouteChange(notification)
            }
        }

        configChangeObserver = center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: nil
        ) { [weak self] _ in
            Task {
                await self?.handleConfigurationChange()
            }
        }
    }

    private func handleInterruption(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            AppLogger.audio.warning("Interruption began")
            setState(.interrupted(reason: .unknown, canResume: true))
            eventContinuation?.yield(.interrupted(.unknown))

        case .ended:
            let shouldResume = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt == AVAudioSession.InterruptionOptions.shouldResume.rawValue

            AppLogger.audio.info("Interruption ended, shouldResume: \(shouldResume)")
            eventContinuation?.yield(.interruptionEnded(shouldResume: shouldResume))

            if shouldResume {
                try? await resumeRecording()
            }

        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt else {
            return
        }

        updateRouteInfo()

        let reason: RouteChangeReason = {
            switch AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
            case .newDeviceAvailable: return .newDeviceAvailable
            case .oldDeviceUnavailable: return .oldDeviceUnavailable
            case .categoryChange: return .categoryChange
            case .override: return .override
            case .wakeFromSleep: return .wakeFromSleep
            case .noSuitableRouteForCategory: return .noSuitableRouteForCategory
            case .routeConfigurationChange: return .routeConfigurationChange
            default: return .unknown
            }
        }()

        AppLogger.audio.info("Route changed: \(reason.displayString)")
        eventContinuation?.yield(.routeChanged(_currentRoute, reason: reason))
    }

    private func handleConfigurationChange() async {
        AppLogger.audio.warning("Engine configuration changed")
        eventContinuation?.yield(.configurationChanged)

        // Rebuild engine if recording
        if case .recording = _currentState {
            do {
                audioEngine.inputNode.removeTap(onBus: 0)
                audioEngine.stop()
                try startEngine()
                try installInputTap(sessionId: currentSessionId!, quality: currentQuality!)
            } catch {
                AppLogger.audio.error("Failed to recover from configuration change", error: error)
                emitError(.audioEngineFailure(reason: "Configuration change recovery failed"))
            }
        }
    }
}

// MARK: - AudioSegmentWriter

/// Helper class for writing audio segments to disk.
private class AudioSegmentWriter {
    let currentURL: URL
    let segmentDuration: TimeInterval
    let segmentIndex: Int
    let startOffset: TimeInterval

    private var audioFile: AVAudioFile?
    private var currentDuration: TimeInterval = 0
    var totalDuration: TimeInterval

    init(
        outputURL: URL,
        sampleRate: Double,
        channelCount: Int,
        segmentDuration: TimeInterval,
        segmentIndex: Int = 0,
        startOffset: TimeInterval = 0
    ) throws {
        self.currentURL = outputURL
        self.segmentDuration = segmentDuration
        self.segmentIndex = segmentIndex
        self.startOffset = startOffset
        self.totalDuration = startOffset

        // Create audio format
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: false
        )

        guard let format = format else {
            throw AppError.audioEngineFailure(reason: "Failed to create audio format")
        }

        // Create audio file
        audioFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
    }

    func writeBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard let file = audioFile else {
            throw AppError.audioFileWriteFailure(path: currentURL.path, reason: "Audio file not open")
        }

        try file.write(from: buffer)

        let bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
        currentDuration += bufferDuration
        totalDuration += bufferDuration
    }

    func shouldFinalize() -> Bool {
        currentDuration >= segmentDuration
    }

    func finalize(
        sessionId: UUID,
        encryptionService: any EncryptionServiceProtocol,
        audioFileManager: AudioFileManager,
        onComplete: (SegmentJob) -> Void
    ) async throws {
        // Close file
        audioFile = nil

        // Encrypt file
        _ = try await encryptionService.encryptFile(at: currentURL)

        // Create segment job
        let job = SegmentJob(
            sessionId: sessionId,
            segmentIndex: segmentIndex,
            encryptedFilePath: currentURL.path,
            startOffset: startOffset,
            duration: currentDuration,
            quality: .medium // This should be passed in properly
        )

        onComplete(job)
    }
}

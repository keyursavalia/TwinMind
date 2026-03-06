//
//  RecordingViewModel.swift
//  TwinMind
//
//  Purpose: ViewModel for the recording screen.
//  Design decision: @Observable with @MainActor ensures all UI updates happen
//  on the main thread. Delegates to AudioEngineActor for all recording logic.
//

import Foundation
import Observation
internal import os

// MARK: - TranscriptionSegment

/// A transcription segment for display in the recording view.
public struct TranscriptionSegment: Identifiable, Equatable {
    public let id: UUID
    public let index: Int
    public let text: String
    public let confidence: Double?
    public let timestamp: Date

    public init(id: UUID, index: Int, text: String, confidence: Double?, timestamp: Date) {
        self.id = id
        self.index = index
        self.text = text
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

// MARK: - RecordingViewModel

/// ViewModel managing the recording screen state and user interactions.
///
/// This view model coordinates between the UI and the AudioEngineActor,
/// handling recording controls, state updates, and error presentation.
@MainActor
@Observable
public final class RecordingViewModel {

    // MARK: - Published State

    /// Current recording state.
    public var recordingState: RecordingState = .idle

    /// Current audio route information.
    public var audioRoute: AudioRouteInfo = .default

    /// Current audio level (0.0 to 1.0).
    public var audioLevel: Float = 0.0

    /// Current recording duration in seconds.
    public var elapsedTime: TimeInterval = 0

    /// Current error to display.
    public var currentError: AppError?

    /// Whether to show the error banner.
    public var showErrorBanner: Bool = false

    /// Current session name.
    public var sessionName: String = ""

    /// Selected recording quality.
    public var selectedQuality: RecordingQuality = .medium

    /// Live transcription segments as they complete.
    public var transcriptionSegments: [TranscriptionSegment] = []

    /// Total segment count for progress tracking.
    public var totalSegmentCount: Int = 0

    // MARK: - Dependencies

    private let audioEngine: any AudioEngineProtocol
    private let transcriptionPipeline: any TranscriptionPipelineProtocol
    private let dataManager: any DataManagerProtocol

    // MARK: - Private State

    private var eventStreamTask: Task<Void, Never>?
    private var transcriptionEventTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var currentSessionId: UUID?
    private var recordingStartTime: Date?

    // MARK: - Initialization

    /// Creates a new recording view model.
    ///
    /// - Parameters:
    ///   - audioEngine: The audio engine actor.
    ///   - transcriptionPipeline: The transcription pipeline actor.
    ///   - dataManager: The data manager actor.
    public init(
        audioEngine: any AudioEngineProtocol,
        transcriptionPipeline: any TranscriptionPipelineProtocol,
        dataManager: any DataManagerProtocol
    ) {
        self.audioEngine = audioEngine
        self.transcriptionPipeline = transcriptionPipeline
        self.dataManager = dataManager
    }

    // MARK: - Lifecycle

    /// Starts observing audio engine and transcription events.
    public func startObserving() {
        eventStreamTask = Task { @MainActor in
            for await event in await audioEngine.eventStream {
                handleAudioEvent(event)
            }
        }

        transcriptionEventTask = Task { @MainActor in
            for await event in await transcriptionPipeline.eventStream {
                handleTranscriptionEvent(event)
            }
        }
    }

    /// Stops observing events.
    public func stopObserving() {
        eventStreamTask?.cancel()
        eventStreamTask = nil
        transcriptionEventTask?.cancel()
        transcriptionEventTask = nil
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Recording Controls

    /// Starts a new recording session.
    public func startRecording() {
        Task {
            do {
                // Generate session name if empty
                if sessionName.isEmpty {
                    sessionName = "Recording \(Date().formattedDateTime)"
                }

                // Reset transcription state
                transcriptionSegments = []
                totalSegmentCount = 0

                // Create session in database
                currentSessionId = UUID()
                _ = try await dataManager.createSession(
                    id: currentSessionId!,
                    name: sessionName,
                    quality: selectedQuality
                )

                // Start audio engine
                try await audioEngine.startRecording(
                    sessionId: currentSessionId!,
                    quality: selectedQuality
                )

                // Start timer
                recordingStartTime = Date()
                startTimer()

                AppLogger.ui.info("Recording started: \(self.sessionName)")

            } catch {
                handleError(error)
            }
        }
    }

    /// Stops the current recording session.
    public func stopRecording() {
        Task {
            do {
                try await audioEngine.stopRecording()

                // Update session in database
                if let sessionId = currentSessionId {
                    if let session = try await dataManager.fetchSession(id: sessionId) {
                        session.endedAt = Date()
                        session.durationSeconds = elapsedTime
                        session.state = .completed
                        try await dataManager.updateSession(session)
                    }
                }

                // Reset state
                stopTimer()
                currentSessionId = nil
                recordingStartTime = nil
                sessionName = ""

                AppLogger.ui.info("Recording stopped")

            } catch {
                handleError(error)
            }
        }
    }

    /// Pauses the current recording.
    public func pauseRecording() {
        Task {
            do {
                try await audioEngine.pauseRecording()
                stopTimer()

                AppLogger.ui.info("Recording paused")

            } catch {
                handleError(error)
            }
        }
    }

    /// Resumes the paused recording.
    public func resumeRecording() {
        Task {
            do {
                try await audioEngine.resumeRecording()
                startTimer()

                AppLogger.ui.info("Recording resumed")

            } catch {
                handleError(error)
            }
        }
    }

    // MARK: - Error Handling

    /// Dismisses the current error banner.
    public func dismissError() {
        showErrorBanner = false
        currentError = nil
    }

    /// Retries the last failed operation.
    public func retryAfterError() {
        dismissError()
        // Attempt to restart recording if idle
        if case .idle = recordingState {
            startRecording()
        }
    }

    // MARK: - Private Helpers

    private func handleAudioEvent(_ event: AudioEngineEvent) {
        switch event {
        case .stateChanged(let state):
            recordingState = state

        case .segmentReady(let job):
            // Increment total segment count
            totalSegmentCount += 1

            // Submit to transcription pipeline
            Task {
                await transcriptionPipeline.submitJob(job)
            }

        case .levelUpdate(let level):
            audioLevel = level

        case .routeChanged(let route, _):
            audioRoute = route

        case .error(let error):
            handleError(error)

        case .interrupted, .interruptionEnded, .configurationChanged:
            // These are logged but don't require UI action
            break
        }
    }

    private func handleTranscriptionEvent(_ event: TranscriptionPipelineEvent) {
        switch event {
        case .jobCompleted(let segmentId, let result):
            // Add completed transcription to the list
            Task {
                // Fetch segment to get the index
                if let segment = try? await dataManager.fetchSegment(id: segmentId) {
                    let transcriptionSegment = TranscriptionSegment(
                        id: segmentId,
                        index: segment.index,
                        text: result.text,
                        confidence: result.confidence,
                        timestamp: Date()
                    )

                    // Insert in order by index
                    if let insertIndex = transcriptionSegments.firstIndex(where: { $0.index > segment.index }) {
                        transcriptionSegments.insert(transcriptionSegment, at: insertIndex)
                    } else {
                        transcriptionSegments.append(transcriptionSegment)
                    }

                    AppLogger.ui.info("Transcription completed for segment \(segment.index)")
                }
            }

        case .jobQueued, .jobStarted, .jobRetrying, .jobFailed,
             .serviceSwitched, .connectivityChanged, .drainingOfflineQueue:
            // These events don't require UI updates in the recording view
            break
        }
    }

    private func handleError(_ error: Error) {
        let appError = error as? AppError ?? .unknown(message: error.localizedDescription)
        currentError = appError
        showErrorBanner = true

        AppLogger.ui.error("Recording error", error: appError)
    }

    private func startTimer() {
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                if let startTime = recordingStartTime {
                    elapsedTime = Date().timeIntervalSince(startTime)
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}

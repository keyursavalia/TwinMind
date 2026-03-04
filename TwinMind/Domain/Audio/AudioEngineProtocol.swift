//
//  AudioEngineProtocol.swift
//  TwinMind
//
//  Purpose: Protocol defining the contract for audio recording engine actors.
//  Design decision: Protocol-based dependency injection enables testing with
//  mock implementations and ensures clean separation between interface and implementation.
//

import Foundation

/// Protocol defining the interface for audio recording engine operations.
///
/// Conforming types (typically actors) handle all AVAudioEngine lifecycle,
/// session configuration, interruption handling, and real-time audio segmentation.
public protocol AudioEngineProtocol: Actor {

    // MARK: - State Observation

    /// An async stream of audio engine events.
    ///
    /// Subscribers receive events for state changes, audio levels, segment completion,
    /// route changes, and errors.
    var eventStream: AsyncStream<AudioEngineEvent> { get }

    /// The current recording state.
    var currentState: RecordingState { get }

    /// The current audio route information (input/output devices).
    var currentRoute: AudioRouteInfo { get }

    // MARK: - Recording Control

    /// Starts a new recording session.
    ///
    /// - Parameters:
    ///   - sessionId: Unique identifier for the session.
    ///   - quality: Recording quality preset.
    /// - Throws: `AppError` if audio session configuration or engine start fails.
    func startRecording(sessionId: UUID, quality: RecordingQuality) async throws

    /// Stops the current recording session.
    ///
    /// Flushes any remaining audio data to the final segment and stops the engine.
    ///
    /// - Throws: `AppError` if stopping fails or there's no active session.
    func stopRecording() async throws

    /// Pauses the current recording session.
    ///
    /// The audio engine is stopped but the session remains open for resumption.
    ///
    /// - Throws: `AppError` if pausing fails or there's no active session.
    func pauseRecording() async throws

    /// Resumes a paused recording session.
    ///
    /// Restarts the audio engine and continues writing to a new segment.
    ///
    /// - Throws: `AppError` if resuming fails or the session cannot be resumed.
    func resumeRecording() async throws

    // MARK: - Permissions

    /// Requests microphone permission from the user.
    ///
    /// - Returns: `true` if permission is granted, `false` otherwise.
    func requestMicrophonePermission() async -> Bool

    /// Checks the current microphone permission status.
    ///
    /// - Returns: `true` if permission is granted, `false` otherwise.
    func checkMicrophonePermission() async -> Bool

    // MARK: - Configuration

    /// Updates the recording quality preset mid-session.
    ///
    /// This will close the current segment and start a new one with the new settings.
    ///
    /// - Parameter quality: The new recording quality preset.
    /// - Throws: `AppError` if the quality change fails.
    func updateQuality(_ quality: RecordingQuality) async throws

    // MARK: - Cleanup

    /// Resets the engine state and cleans up resources.
    ///
    /// Called when recovering from errors or when the app terminates.
    func reset() async
}

// MARK: - AudioEngineEvent

/// Events emitted by the audio engine through the event stream.
public enum AudioEngineEvent: Sendable, Equatable {

    /// Recording state changed.
    case stateChanged(RecordingState)

    /// A new audio segment is ready for transcription.
    case segmentReady(SegmentJob)

    /// Audio level updated (normalized 0.0 to 1.0).
    case levelUpdate(Float)

    /// Audio route changed (e.g., headphones plugged/unplugged).
    case routeChanged(AudioRouteInfo, reason: RouteChangeReason)

    /// An interruption occurred (phone call, Siri, etc.).
    case interrupted(InterruptionReason)

    /// An interruption ended.
    case interruptionEnded(shouldResume: Bool)

    /// An error occurred during recording.
    case error(AppError)

    /// Audio engine configuration changed (system reset).
    case configurationChanged
}

// MARK: - RouteChangeReason

/// Reasons for audio route changes.
public enum RouteChangeReason: Sendable, Equatable {

    /// A new device became available (e.g., headphones plugged in).
    case newDeviceAvailable

    /// The old device became unavailable (e.g., headphones unplugged).
    case oldDeviceUnavailable

    /// Audio category changed.
    case categoryChange

    /// Route was overridden by the system.
    case override

    /// Wake from sleep.
    case wakeFromSleep

    /// No suitable route is available.
    case noSuitableRouteForCategory

    /// Route change for app preference.
    case routeConfigurationChange

    /// Unknown reason.
    case unknown
}

// MARK: - Helper Extensions

extension RouteChangeReason {

    /// User-facing display string for the route change reason.
    public var displayString: String {
        switch self {
        case .newDeviceAvailable:
            return "New Device Connected"
        case .oldDeviceUnavailable:
            return "Device Disconnected"
        case .categoryChange:
            return "Audio Category Changed"
        case .override:
            return "Route Overridden"
        case .wakeFromSleep:
            return "Wake from Sleep"
        case .noSuitableRouteForCategory:
            return "No Suitable Route"
        case .routeConfigurationChange:
            return "Route Configuration Changed"
        case .unknown:
            return "Unknown Route Change"
        }
    }
}

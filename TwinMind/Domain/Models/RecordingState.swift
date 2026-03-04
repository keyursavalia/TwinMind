//
//  RecordingState.swift
//  TwinMind
//
//  Purpose: Represents the current state of the audio recording engine.
//  Design decision: Enum with associated values for state-specific data allows
//  for exhaustive pattern matching and clear state transitions.
//

import Foundation

/// The current state of an audio recording session.
///
/// This enum represents the complete lifecycle of a recording, from idle
/// through active recording, pausing, interruptions, and completion.
public enum RecordingState: Sendable, Equatable {

    /// No recording is active. Engine is stopped.
    case idle

    /// Recording is actively capturing audio.
    ///
    /// - Parameter startedAt: The timestamp when recording began.
    case recording(startedAt: Date)

    /// Recording is paused by user action. Engine is stopped but session remains open.
    ///
    /// - Parameter pausedAt: The timestamp when recording was paused.
    case paused(pausedAt: Date)

    /// Recording is interrupted by system event (call, Siri, route change).
    ///
    /// - Parameters:
    ///   - reason: The cause of the interruption.
    ///   - canResume: Whether automatic resumption is possible when interruption ends.
    case interrupted(reason: InterruptionReason, canResume: Bool)

    /// Recording has completed successfully.
    ///
    /// - Parameter endedAt: The timestamp when recording ended.
    case completed(endedAt: Date)

    /// Recording has failed and cannot continue.
    ///
    /// - Parameter error: The error that caused the failure.
    case failed(error: AppError)
}

// MARK: - Computed Properties

extension RecordingState {

    /// Whether the audio engine should be actively running.
    public var isEngineRunning: Bool {
        switch self {
        case .recording:
            return true
        case .idle, .paused, .interrupted, .completed, .failed:
            return false
        }
    }

    /// Whether the session is in a terminal state (completed or failed).
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        case .idle, .recording, .paused, .interrupted:
            return false
        }
    }

    /// Whether the state allows starting a new recording.
    public var canStartRecording: Bool {
        switch self {
        case .idle, .completed, .failed:
            return true
        case .recording, .paused, .interrupted:
            return false
        }
    }

    /// Whether the state allows pausing the recording.
    public var canPause: Bool {
        switch self {
        case .recording:
            return true
        case .idle, .paused, .interrupted, .completed, .failed:
            return false
        }
    }

    /// Whether the state allows resuming the recording.
    public var canResume: Bool {
        switch self {
        case .paused:
            return true
        case .interrupted(_, let canResume):
            return canResume
        case .idle, .recording, .completed, .failed:
            return false
        }
    }

    /// Whether the state allows stopping the recording.
    public var canStop: Bool {
        switch self {
        case .recording, .paused, .interrupted:
            return true
        case .idle, .completed, .failed:
            return false
        }
    }

    /// A user-facing display string for the current state.
    public var displayString: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording"
        case .paused:
            return "Paused"
        case .interrupted(let reason, _):
            return "Interrupted: \(reason.displayString)"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}

// MARK: - Codable Conformance

extension RecordingState: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case startedAt
        case pausedAt
        case endedAt
        case interruptionReason
        case canResume
        case error
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .idle:
            try container.encode("idle", forKey: .type)

        case .recording(let startedAt):
            try container.encode("recording", forKey: .type)
            try container.encode(startedAt, forKey: .startedAt)

        case .paused(let pausedAt):
            try container.encode("paused", forKey: .type)
            try container.encode(pausedAt, forKey: .pausedAt)

        case .interrupted(let reason, let canResume):
            try container.encode("interrupted", forKey: .type)
            try container.encode(reason, forKey: .interruptionReason)
            try container.encode(canResume, forKey: .canResume)

        case .completed(let endedAt):
            try container.encode("completed", forKey: .type)
            try container.encode(endedAt, forKey: .endedAt)

        case .failed(let error):
            try container.encode("failed", forKey: .type)
            try container.encode(error, forKey: .error)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "idle":
            self = .idle

        case "recording":
            let startedAt = try container.decode(Date.self, forKey: .startedAt)
            self = .recording(startedAt: startedAt)

        case "paused":
            let pausedAt = try container.decode(Date.self, forKey: .pausedAt)
            self = .paused(pausedAt: pausedAt)

        case "interrupted":
            let reason = try container.decode(InterruptionReason.self, forKey: .interruptionReason)
            let canResume = try container.decode(Bool.self, forKey: .canResume)
            self = .interrupted(reason: reason, canResume: canResume)

        case "completed":
            let endedAt = try container.decode(Date.self, forKey: .endedAt)
            self = .completed(endedAt: endedAt)

        case "failed":
            let error = try container.decode(AppError.self, forKey: .error)
            self = .failed(error: error)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid RecordingState type: \(type)"
            )
        }
    }
}

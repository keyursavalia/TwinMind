//
//  TranscriptionState.swift
//  TwinMind
//
//  Purpose: Represents the processing state of a single audio segment's transcription.
//  Design decision: Separate state enum allows the UI to display progress
//  and retry information independently of the recording state.
//

import Foundation

/// The current processing state of an audio segment's transcription.
///
/// Each audio segment moves through a lifecycle from pending transcription,
/// through processing and retries, to either completion or failure.
public enum TranscriptionState: Sendable, Equatable {

    /// Segment is queued for transcription but not yet started.
    case pending

    /// Transcription is actively being processed.
    ///
    /// - Parameters:
    ///   - attempt: Current attempt number (1-based).
    ///   - service: The transcription service being used.
    case processing(attempt: Int, service: String)

    /// Transcription completed successfully.
    ///
    /// - Parameters:
    ///   - processedAt: Timestamp when transcription completed.
    ///   - service: The service that processed the transcription.
    case completed(processedAt: Date, service: String)

    /// Transcription failed after all retry attempts.
    ///
    /// - Parameters:
    ///   - lastAttempt: The final attempt number.
    ///   - error: The error that caused the failure.
    case failed(lastAttempt: Int, error: AppError)

    /// Transcription is queued for retry after a failure.
    ///
    /// - Parameters:
    ///   - attempt: Next attempt number (1-based).
    ///   - retryAt: Timestamp when retry will be attempted.
    case retrying(attempt: Int, retryAt: Date)
}

// MARK: - Computed Properties

extension TranscriptionState {

    /// Whether the segment is in a terminal state (completed or failed).
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        case .pending, .processing, .retrying:
            return false
        }
    }

    /// Whether the segment is currently being processed.
    public var isProcessing: Bool {
        switch self {
        case .processing:
            return true
        case .pending, .retrying, .completed, .failed:
            return false
        }
    }

    /// Whether the segment is waiting to be processed or retried.
    public var isWaiting: Bool {
        switch self {
        case .pending, .retrying:
            return true
        case .processing, .completed, .failed:
            return false
        }
    }

    /// The current attempt number, if actively processing or retrying.
    public var currentAttempt: Int? {
        switch self {
        case .processing(let attempt, _):
            return attempt
        case .retrying(let attempt, _):
            return attempt
        case .failed(let lastAttempt, _):
            return lastAttempt
        case .pending, .completed:
            return nil
        }
    }

    /// A user-facing display string for the current state.
    public var displayString: String {
        switch self {
        case .pending:
            return "Pending"
        case .processing(let attempt, _):
            return "Processing (attempt \(attempt))"
        case .completed:
            return "Completed"
        case .failed(let lastAttempt, _):
            return "Failed after \(lastAttempt) attempts"
        case .retrying(let attempt, let retryAt):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Retrying at \(formatter.string(from: retryAt)) (attempt \(attempt))"
        }
    }
}

// MARK: - Codable Conformance

extension TranscriptionState: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case attempt
        case service
        case processedAt
        case error
        case retryAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .pending:
            try container.encode("pending", forKey: .type)

        case .processing(let attempt, let service):
            try container.encode("processing", forKey: .type)
            try container.encode(attempt, forKey: .attempt)
            try container.encode(service, forKey: .service)

        case .completed(let processedAt, let service):
            try container.encode("completed", forKey: .type)
            try container.encode(processedAt, forKey: .processedAt)
            try container.encode(service, forKey: .service)

        case .failed(let lastAttempt, let error):
            try container.encode("failed", forKey: .type)
            try container.encode(lastAttempt, forKey: .attempt)
            try container.encode(error, forKey: .error)

        case .retrying(let attempt, let retryAt):
            try container.encode("retrying", forKey: .type)
            try container.encode(attempt, forKey: .attempt)
            try container.encode(retryAt, forKey: .retryAt)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "pending":
            self = .pending

        case "processing":
            let attempt = try container.decode(Int.self, forKey: .attempt)
            let service = try container.decode(String.self, forKey: .service)
            self = .processing(attempt: attempt, service: service)

        case "completed":
            let processedAt = try container.decode(Date.self, forKey: .processedAt)
            let service = try container.decode(String.self, forKey: .service)
            self = .completed(processedAt: processedAt, service: service)

        case "failed":
            let lastAttempt = try container.decode(Int.self, forKey: .attempt)
            let error = try container.decode(AppError.self, forKey: .error)
            self = .failed(lastAttempt: lastAttempt, error: error)

        case "retrying":
            let attempt = try container.decode(Int.self, forKey: .attempt)
            let retryAt = try container.decode(Date.self, forKey: .retryAt)
            self = .retrying(attempt: attempt, retryAt: retryAt)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid TranscriptionState type: \(type)"
            )
        }
    }
}

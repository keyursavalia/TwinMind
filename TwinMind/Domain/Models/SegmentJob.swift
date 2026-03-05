//
//  SegmentJob.swift
//  TwinMind
//
//  Purpose: Represents a transcription job for a single audio segment.
//  Design decision: Value type that flows through the AsyncStream from
//  AudioEngineActor to TranscriptionPipelineActor.
//

import Foundation

/// A transcription job for a single audio segment.
///
/// This type encapsulates all information needed to transcribe an audio segment,
/// including the encrypted file path, segment metadata, and retry context.
/// Jobs flow from the AudioEngineActor to the TranscriptionPipelineActor via AsyncStream.
public struct SegmentJob: Sendable, Equatable, Identifiable {

    /// Unique identifier for this segment.
    public let id: UUID

    /// The ID of the recording session this segment belongs to.
    public let sessionId: UUID

    /// The index of this segment within the session (0-based).
    public let segmentIndex: Int

    /// The file path to the encrypted audio segment.
    public let encryptedFilePath: String

    /// The start offset of this segment from the beginning of the session (in seconds).
    public let startOffset: TimeInterval

    /// The duration of this segment (in seconds).
    public let duration: TimeInterval

    /// The recording quality preset used for this segment.
    public let quality: RecordingQuality

    /// The timestamp when this segment was created.
    public let createdAt: Date

    /// The number of times this job has been attempted (0 for new jobs).
    public let attemptCount: Int

    /// The preferred transcription service to use (e.g., "gemini-api", "apple-stt").
    public let preferredService: String?

    /// Creates a new segment job.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the segment.
    ///   - sessionId: The parent recording session ID.
    ///   - segmentIndex: The index of this segment within the session.
    ///   - encryptedFilePath: Path to the encrypted audio file.
    ///   - startOffset: Start time offset from session start (seconds).
    ///   - duration: Duration of the segment (seconds).
    ///   - quality: Recording quality preset.
    ///   - createdAt: Timestamp when the segment was created.
    ///   - attemptCount: Number of previous attempts (default: 0).
    ///   - preferredService: Preferred transcription service (default: nil).
    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        segmentIndex: Int,
        encryptedFilePath: String,
        startOffset: TimeInterval,
        duration: TimeInterval,
        quality: RecordingQuality,
        createdAt: Date = Date(),
        attemptCount: Int = 0,
        preferredService: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.segmentIndex = segmentIndex
        self.encryptedFilePath = encryptedFilePath
        self.startOffset = startOffset
        self.duration = duration
        self.quality = quality
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.preferredService = preferredService
    }
}

// MARK: - Job Creation Helpers

extension SegmentJob {

    /// Creates a retry job with incremented attempt count.
    ///
    /// - Returns: A new SegmentJob with attemptCount incremented by 1.
    public func withIncrementedAttempt() -> SegmentJob {
        SegmentJob(
            id: id,
            sessionId: sessionId,
            segmentIndex: segmentIndex,
            encryptedFilePath: encryptedFilePath,
            startOffset: startOffset,
            duration: duration,
            quality: quality,
            createdAt: createdAt,
            attemptCount: attemptCount + 1,
            preferredService: preferredService
        )
    }

    /// Creates a job with a fallback service.
    ///
    /// - Parameter service: The fallback service name.
    /// - Returns: A new SegmentJob with the specified preferred service.
    public func withFallbackService(_ service: String) -> SegmentJob {
        SegmentJob(
            id: id,
            sessionId: sessionId,
            segmentIndex: segmentIndex,
            encryptedFilePath: encryptedFilePath,
            startOffset: startOffset,
            duration: duration,
            quality: quality,
            createdAt: createdAt,
            attemptCount: attemptCount,
            preferredService: service
        )
    }
}

// MARK: - Display Properties

extension SegmentJob {

    /// A user-facing display string for this job.
    public var displayString: String {
        let formattedOffset = String(format: "%.1f", startOffset)
        return "Segment \(segmentIndex + 1) at \(formattedOffset)s"
    }

    /// Whether this job has exceeded the maximum retry limit.
    public var hasExceededRetryLimit: Bool {
        return attemptCount >= 5
    }

    /// The retry delay in seconds for the current attempt.
    public var retryDelay: TimeInterval {
        // Exponential backoff: [0, 2, 4, 8, 16] seconds for attempts 1-5
        let delays: [TimeInterval] = [0, 2, 4, 8, 16]
        let index = min(attemptCount, delays.count - 1)
        return delays[index]
    }
}

//
//  TranscriptionPipelineProtocol.swift
//  TwinMind
//
//  Purpose: Protocol defining the contract for transcription pipeline actors.
//  Design decision: Separate protocol enables testing with mock implementations
//  and decouples the pipeline from specific transcription services.
//

import Foundation

/// Protocol defining the interface for transcription pipeline operations.
///
/// Conforming types (typically actors) handle queuing, processing, retry logic,
/// and offline management for audio segment transcriptions.
public protocol TranscriptionPipelineProtocol: Actor {

    // MARK: - Job Management

    /// Submits a segment job for transcription.
    ///
    /// - Parameter job: The segment job to process.
    func submitJob(_ job: SegmentJob) async

    /// Cancels a pending job by segment ID.
    ///
    /// - Parameter segmentId: The segment ID to cancel.
    func cancelJob(segmentId: UUID) async

    /// Drains the offline queue when connectivity returns.
    func drainOfflineQueue() async

    // MARK: - State Observation

    /// An async stream of transcription events.
    var eventStream: AsyncStream<TranscriptionPipelineEvent> { get }

    /// The number of jobs currently queued.
    var queuedJobCount: Int { get async }

    /// The number of jobs currently processing.
    var processingJobCount: Int { get async }

    // MARK: - Service Management

    /// Switches to a fallback transcription service.
    ///
    /// - Parameter serviceIdentifier: The service identifier to switch to.
    func switchService(to serviceIdentifier: String) async

    /// Gets the currently active service identifier.
    var activeServiceIdentifier: String { get async }
}

// MARK: - TranscriptionPipelineEvent

/// Events emitted by the transcription pipeline.
public enum TranscriptionPipelineEvent: Sendable, Equatable {

    /// A job was added to the queue.
    case jobQueued(SegmentJob)

    /// A job started processing.
    case jobStarted(segmentId: UUID, attempt: Int, service: String)

    /// A job completed successfully.
    case jobCompleted(segmentId: UUID, result: TranscriptionServiceResult)

    /// A job failed and will be retried.
    case jobRetrying(segmentId: UUID, attempt: Int, retryDelay: TimeInterval, error: AppError)

    /// A job failed permanently after all retries.
    case jobFailed(segmentId: UUID, finalAttempt: Int, error: AppError)

    /// Service switched to fallback.
    case serviceSwitched(from: String, to: String, reason: String)

    /// Network connectivity changed.
    case connectivityChanged(isOnline: Bool)

    /// Offline queue is being drained.
    case drainingOfflineQueue(jobCount: Int)
}

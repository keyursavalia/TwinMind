//
//  TranscriptionPipelineActor.swift
//  TwinMind
//
//  Purpose: Actor managing transcription job queue, retry logic, and fallback.
//  Design decision: TaskGroup with max 3 concurrent jobs prevents memory spikes.
//  Exponential backoff and global failure counting enable robust fallback strategy.
//

import Foundation
internal import os

/// Actor managing the transcription pipeline with queuing, retry, and fallback.
///
/// This actor receives segment jobs from the audio engine, queues them for processing,
/// handles retries with exponential backoff, and switches to fallback services on failure.
public actor TranscriptionPipelineActor: TranscriptionPipelineProtocol {

    // MARK: - Properties

    /// The primary transcription service.
    private var primaryService: any TranscriptionServiceProtocol

    /// The fallback transcription service (Apple STT).
    private var fallbackService: any TranscriptionServiceProtocol

    /// The currently active service.
    private var activeService: any TranscriptionServiceProtocol

    /// The data manager for persisting transcription results.
    private let dataManager: any DataManagerProtocol

    /// The encryption service for decrypting audio files.
    private let encryptionService: any EncryptionServiceProtocol

    /// Network service for connectivity monitoring.
    private let networkService: any NetworkServiceProtocol

    /// Pending job queue.
    private var jobQueue: [SegmentJob] = []

    /// Currently processing job IDs.
    private var processingJobs: Set<UUID> = []

    /// Consecutive failure counter for global fallback logic.
    private var consecutiveFailureCount: Int = 0

    /// Maximum concurrent jobs.
    private let maxConcurrentJobs: Int = 3

    /// Event stream continuation.
    private var eventContinuation: AsyncStream<TranscriptionPipelineEvent>.Continuation?

    /// Whether network is currently available.
    private var isOnline: Bool = true

    /// Processing task.
    private var processingTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new transcription pipeline actor.
    ///
    /// - Parameters:
    ///   - primaryService: The primary transcription service (Gemini API).
    ///   - fallbackService: The fallback transcription service (Apple STT).
    ///   - dataManager: The data manager for persistence.
    ///   - encryptionService: The encryption service.
    ///   - networkService: The network service for connectivity monitoring.
    public init(
        primaryService: any TranscriptionServiceProtocol,
        fallbackService: any TranscriptionServiceProtocol,
        dataManager: any DataManagerProtocol,
        encryptionService: any EncryptionServiceProtocol,
        networkService: any NetworkServiceProtocol
    ) {
        self.primaryService = primaryService
        self.fallbackService = fallbackService
        self.activeService = primaryService
        self.dataManager = dataManager
        self.encryptionService = encryptionService
        self.networkService = networkService

        AppLogger.transcription.info("TranscriptionPipelineActor initialized with primary: \(primaryService.serviceIdentifier)")

        // Start connectivity monitoring
        startConnectivityMonitoring()
    }

    // MARK: - Event Stream

    public nonisolated var eventStream: AsyncStream<TranscriptionPipelineEvent> {
        AsyncStream { continuation in
            Task {
                await setEventContinuation(continuation)
            }
        }
    }

    private func setEventContinuation(_ continuation: AsyncStream<TranscriptionPipelineEvent>.Continuation) {
        self.eventContinuation = continuation
    }

    // MARK: - Job Management

    public func submitJob(_ job: SegmentJob) async {
        AppLogger.transcription.info("Submitting job for segment \(job.segmentIndex) of session \(job.sessionId.uuidString)")

        // Create the AudioSegment record in the database if it doesn't exist
        do {
            _ = try await dataManager.createSegment(
                sessionId: job.sessionId,
                index: job.segmentIndex,
                startOffset: job.startOffset,
                duration: job.duration,
                audioFilePath: job.encryptedFilePath,
                id: job.id
            )
            AppLogger.transcription.info("Created segment record for segment \(job.segmentIndex)")
        } catch {
            // If segment already exists, that's fine - continue
            AppLogger.transcription.debug("Segment may already exist: \(error.localizedDescription)")
        }

        jobQueue.append(job)
        eventContinuation?.yield(.jobQueued(job))

        // Update segment state to pending
        try? await dataManager.updateSegmentTranscriptionState(
            segmentId: job.id,
            state: .pending
        )

        // Start processing if not already running
        ensureProcessing()
    }

    public func cancelJob(segmentId: UUID) async {
        // Remove from queue
        jobQueue.removeAll { $0.id == segmentId }

        // Cancel if processing (this is a simplified implementation)
        processingJobs.remove(segmentId)

        AppLogger.transcription.info("Cancelled job for segment: \(segmentId.uuidString)")
    }

    public func drainOfflineQueue() async {
        guard isOnline else {
            AppLogger.transcription.warning("Cannot drain offline queue: still offline")
            return
        }

        let pendingJobs = jobQueue.filter { !processingJobs.contains($0.id) }

        if !pendingJobs.isEmpty {
            AppLogger.transcription.info("Draining offline queue: \(pendingJobs.count) jobs")
            eventContinuation?.yield(.drainingOfflineQueue(jobCount: pendingJobs.count))
            ensureProcessing()
        }
    }

    // MARK: - State Observation

    public var queuedJobCount: Int {
        jobQueue.count
    }

    public var processingJobCount: Int {
        processingJobs.count
    }

    // MARK: - Service Management

    public func switchService(to serviceIdentifier: String) async {
        let previousService = activeService.serviceIdentifier

        if serviceIdentifier == primaryService.serviceIdentifier {
            activeService = primaryService
        } else if serviceIdentifier == fallbackService.serviceIdentifier {
            activeService = fallbackService
        } else {
            AppLogger.transcription.warning("Unknown service identifier: \(serviceIdentifier)")
            return
        }

        await AppLogger.transcription.notice("Switched service from \(previousService) to \(self.activeService.serviceIdentifier)")
        eventContinuation?.yield(.serviceSwitched(
            from: previousService,
            to: activeService.serviceIdentifier,
            reason: "Manual switch"
        ))

        // Reset consecutive failure count on manual switch
        consecutiveFailureCount = 0
    }

    public var activeServiceIdentifier: String {
        activeService.serviceIdentifier
    }

    // MARK: - Processing

    private func ensureProcessing() {
        // Start processing task if not already running or if it has finished
        if processingTask == nil {
            processingTask = Task {
                await processQueue()
            }
        } else if let task = processingTask, task.isCancelled {
            processingTask = Task {
                await processQueue()
            }
        }
        // If task exists and is still running, do nothing - it will pick up new jobs
    }

    private func processQueue() async {
        // Keep processing loop running - don't exit when queue is temporarily empty
        while true {
            // Exit only if explicitly cancelled
            if Task.isCancelled {
                break
            }

            // Check if there are jobs to process
            guard !jobQueue.isEmpty else {
                // Queue is empty, wait a bit before checking again
                try? await Task.sleep(for: .seconds(0.5))
                continue
            }

            // Get jobs to process (up to max concurrent)
            let availableSlots = maxConcurrentJobs - processingJobs.count
            guard availableSlots > 0 else {
                // All slots busy, wait a bit and check again
                try? await Task.sleep(for: .seconds(0.5))
                continue
            }

            let jobsToProcess = jobQueue.prefix(availableSlots).filter { job in
                !processingJobs.contains(job.id) && (isOnline || !activeService.requiresNetwork)
            }

            guard !jobsToProcess.isEmpty else {
                // No eligible jobs right now, wait and retry
                try? await Task.sleep(for: .seconds(0.5))
                continue
            }

            // Process jobs concurrently
            await withTaskGroup(of: Void.self) { group in
                for job in jobsToProcess {
                    group.addTask {
                        await self.processJob(job)
                    }
                }
            }

            // Small delay before next iteration to avoid tight loop
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func processJob(_ job: SegmentJob) async {
        let segmentId = job.id
        processingJobs.insert(segmentId)

        defer {
            processingJobs.remove(segmentId)
            jobQueue.removeAll { $0.id == segmentId }
        }

        let attempt = job.attemptCount + 1
        let serviceId = job.preferredService ?? activeService.serviceIdentifier

        AppLogger.transcription.info("Processing segment \(job.segmentIndex) (attempt \(attempt)) with \(serviceId)")

        eventContinuation?.yield(.jobStarted(
            segmentId: segmentId,
            attempt: attempt,
            service: serviceId
        ))

        // Update state to processing
        try? await dataManager.updateSegmentTranscriptionState(
            segmentId: segmentId,
            state: .processing(attempt: attempt, service: serviceId)
        )

        do {
            // Transcribe the segment
            let result = try await transcribeSegment(job: job)

            // Save transcription result
            try await dataManager.createTranscriptionResult(
                segmentId: segmentId,
                text: result.text,
                confidence: result.confidence,
                language: result.language,
                modelUsed: serviceId
            )

            // Update state to completed
            try await dataManager.updateSegmentTranscriptionState(
                segmentId: segmentId,
                state: .completed(processedAt: Date(), service: serviceId)
            )

            // Reset consecutive failure count on success
            consecutiveFailureCount = 0

            AppLogger.transcription.info("Completed segment \(job.segmentIndex)")
            eventContinuation?.yield(.jobCompleted(segmentId: segmentId, result: result))

        } catch {
            await handleJobFailure(job: job, attempt: attempt, error: error)
        }
    }

    private func transcribeSegment(job: SegmentJob) async throws -> TranscriptionServiceResult {
        let fileURL = URL(fileURLWithPath: job.encryptedFilePath)

        // Use the preferred service or active service
        let service = job.preferredService == primaryService.serviceIdentifier ? primaryService :
                      job.preferredService == fallbackService.serviceIdentifier ? fallbackService :
                      activeService

        // Transcribe with decryption
        return try await service.transcribe(fileURL: fileURL, language: "en", decrypt: true)
    }

    private func handleJobFailure(job: SegmentJob, attempt: Int, error: Error) async {
        let appError = error as? AppError ?? .unknown(message: error.localizedDescription)

        consecutiveFailureCount += 1

        AppLogger.transcription.warning("Job failed (attempt \(attempt)): \(appError.localizedDescription)")

        // Check if we should retry
        if attempt < 5 {
            let retryJob = job.withIncrementedAttempt()
            let retryDelay = retryJob.retryDelay

            AppLogger.transcription.info("Retrying segment \(job.segmentIndex) in \(retryDelay)s")

            eventContinuation?.yield(.jobRetrying(
                segmentId: job.id,
                attempt: attempt + 1,
                retryDelay: retryDelay,
                error: appError
            ))

            // Update state to retrying
            try? await dataManager.updateSegmentTranscriptionState(
                segmentId: job.id,
                state: .retrying(attempt: attempt + 1, retryAt: Date().addingTimeInterval(retryDelay))
            )

            // Schedule retry
            Task {
                try? await Task.sleep(for: .seconds(retryDelay))
                await self.submitJob(retryJob)
            }

        } else {
            // Permanent failure
            AppLogger.transcription.error("Job permanently failed after \(attempt) attempts")

            try? await dataManager.updateSegmentTranscriptionState(
                segmentId: job.id,
                state: .failed(lastAttempt: attempt, error: appError)
            )

            eventContinuation?.yield(.jobFailed(
                segmentId: job.id,
                finalAttempt: attempt,
                error: appError
            ))
        }

        // Check for global fallback
        if consecutiveFailureCount >= 5 && activeService.serviceIdentifier == primaryService.serviceIdentifier {
            AppLogger.transcription.notice("Switching to fallback service after 5 consecutive failures")

            eventContinuation?.yield(.serviceSwitched(
                from: primaryService.serviceIdentifier,
                to: fallbackService.serviceIdentifier,
                reason: "5 consecutive failures"
            ))

            activeService = fallbackService
            consecutiveFailureCount = 0
        }
    }

    // MARK: - Connectivity Monitoring

    private func startConnectivityMonitoring() {
        Task {
            for await isConnected in networkService.startMonitoring() {
                await updateConnectivity(isConnected)
            }
        }
    }

    private func updateConnectivity(_ isConnected: Bool) {
        let wasOnline = isOnline
        isOnline = isConnected

        if wasOnline != isOnline {
            AppLogger.transcription.info("Connectivity changed: \(self.isOnline ? "online" : "offline")")
            eventContinuation?.yield(.connectivityChanged(isOnline: isOnline))

            if isOnline {
                // Drain offline queue when coming back online
                Task {
                    await drainOfflineQueue()
                }
            }
        }
    }
}

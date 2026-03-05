//
//  DataManagerActor.swift
//  TwinMind
//
//  Purpose: Actor-isolated SwiftData persistence manager.
//  Design decision: All SwiftData operations go through this actor to ensure
//  thread-safe access and prevent data races in Swift 6 strict concurrency.
//

import Foundation
import SwiftData
internal import os

/// Actor managing all SwiftData persistence operations.
///
/// This actor owns the ModelContainer and provides thread-safe CRUD operations
/// for RecordingSession, AudioSegment, and TranscriptionResult entities.
public actor DataManagerActor: DataManagerProtocol {

    // MARK: - Properties

    /// The SwiftData model container.
    private let modelContainer: ModelContainer

    /// The main model context for database operations.
    @MainActor
    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Initialization

    /// Creates a new data manager actor.
    ///
    /// - Parameter modelContainer: The SwiftData model container.
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        AppLogger.data.info("DataManagerActor initialized")
    }

    /// Creates a data manager with an in-memory store (for testing).
    ///
    /// - Returns: A data manager configured for in-memory storage.
    /// - Throws: `AppError.modelContainerInitializationFailed` if creation fails.
    public static func inMemory() throws -> DataManagerActor {
        let schema = Schema([
            RecordingSession.self,
            AudioSegment.self,
            TranscriptionResult.self
        ])

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            return DataManagerActor(modelContainer: container)
        } catch {
            throw AppError.modelContainerInitializationFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Session Operations

    public func createSession(id: UUID, name: String, quality: RecordingQuality) async throws -> RecordingSession {
        let context = ModelContext(modelContainer)

        let session = RecordingSession(
            id: id,
            name: name,
            startedAt: Date(),
            qualityPreset: quality.rawValue,
            state: .active
        )

        context.insert(session)

        do {
            try context.save()
            AppLogger.data.info("Created session: \(id.uuidString)")
            return session
        } catch {
            AppLogger.data.error("Failed to create session", error: error)
            throw AppError.dataOperationFailed(operation: "createSession", reason: error.localizedDescription)
        }
    }

    public func updateSession(_ session: RecordingSession) async throws {
        let context = ModelContext(modelContainer)

        // Capture the session ID to use in the predicate
        let sessionId = session.id
        let predicate = #Predicate<RecordingSession> { s in
            s.id == sessionId
        }
        let descriptor = FetchDescriptor<RecordingSession>(predicate: predicate)

        do {
            guard let existingSession = try context.fetch(descriptor).first else {
                throw AppError.dataOperationFailed(
                    operation: "updateSession",
                    reason: "Session not found: \(sessionId.uuidString)"
                )
            }

            // Update the properties on the tracked object
            existingSession.endedAt = session.endedAt
            existingSession.durationSeconds = session.durationSeconds
            existingSession.state = session.state
            existingSession.name = session.name
            existingSession.audioFilePath = session.audioFilePath

            try context.save()
            AppLogger.data.info("Updated session: \(sessionId.uuidString)")
        } catch {
            AppLogger.data.error("Failed to update session", error: error)
            throw AppError.dataOperationFailed(operation: "updateSession", reason: error.localizedDescription)
        }
    }

    public func fetchSession(id: UUID) async throws -> RecordingSession? {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<RecordingSession> { session in
            session.id == id
        }

        let descriptor = FetchDescriptor<RecordingSession>(predicate: predicate)

        do {
            let sessions = try context.fetch(descriptor)
            return sessions.first
        } catch {
            AppLogger.data.error("Failed to fetch session", error: error)
            throw AppError.dataOperationFailed(operation: "fetchSession", reason: error.localizedDescription)
        }
    }

    public func fetchSessions(
        predicate: Predicate<RecordingSession>?,
        sortDescriptors: [SortDescriptor<RecordingSession>],
        limit: Int,
        offset: Int
    ) async throws -> [RecordingSession] {
        let context = ModelContext(modelContainer)

        var descriptor = FetchDescriptor<RecordingSession>(
            predicate: predicate,
            sortBy: sortDescriptors
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        descriptor.relationshipKeyPathsForPrefetching = [\.segments]

        do {
            let sessions = try context.fetch(descriptor)
            AppLogger.data.debug("Fetched \(sessions.count) sessions (limit: \(limit), offset: \(offset))")

            // Log segment counts for debugging
            for session in sessions {
                AppLogger.data.debug("Session \(session.name): \(session.segments.count) segments, duration: \(session.durationSeconds)s")
            }

            return sessions
        } catch {
            AppLogger.data.error("Failed to fetch sessions", error: error)
            throw AppError.dataOperationFailed(operation: "fetchSessions", reason: error.localizedDescription)
        }
    }

    public func deleteSession(id: UUID) async throws {
        let context = ModelContext(modelContainer)

        guard let session = try await fetchSession(id: id) else {
            throw AppError.recordNotFound(entityType: "RecordingSession", id: id.uuidString)
        }

        context.delete(session)

        do {
            try context.save()
            AppLogger.data.info("Deleted session: \(id.uuidString)")
        } catch {
            AppLogger.data.error("Failed to delete session", error: error)
            throw AppError.dataOperationFailed(operation: "deleteSession", reason: error.localizedDescription)
        }
    }

    // MARK: - Segment Operations

    public func createSegment(
        sessionId: UUID,
        index: Int,
        startOffset: Double,
        duration: Double,
        audioFilePath: String,
        id: UUID? = nil
    ) async throws -> AudioSegment {
        let context = ModelContext(modelContainer)

        // Capture variables for use in predicate
        let capturedSessionId = sessionId
        let segmentId = id ?? UUID()

        // Check if segment already exists (to prevent duplicates)
        let existingSegmentPredicate = #Predicate<AudioSegment> { seg in
            seg.id == segmentId
        }
        let existingSegmentDescriptor = FetchDescriptor<AudioSegment>(predicate: existingSegmentPredicate)

        do {
            // Return existing segment if found
            if let existingSegment = try context.fetch(existingSegmentDescriptor).first {
                AppLogger.data.debug("Segment \(index) already exists for session: \(sessionId.uuidString)")
                return existingSegment
            }

            // Fetch session in THIS context (not from another context)
            let sessionPredicate = #Predicate<RecordingSession> { s in
                s.id == capturedSessionId
            }
            let sessionDescriptor = FetchDescriptor<RecordingSession>(predicate: sessionPredicate)

            guard let session = try context.fetch(sessionDescriptor).first else {
                throw AppError.recordNotFound(entityType: "RecordingSession", id: sessionId.uuidString)
            }

            let segment = AudioSegment(
                id: segmentId,
                index: index,
                startOffset: startOffset,
                durationSeconds: duration,
                audioFilePath: audioFilePath,
                session: session
            )

            context.insert(segment)
            try context.save()

            AppLogger.data.info("Created segment \(index) for session: \(sessionId.uuidString)")
            return segment
        } catch {
            AppLogger.data.error("Failed to create segment", error: error)
            throw AppError.dataOperationFailed(operation: "createSegment", reason: error.localizedDescription)
        }
    }

    public func batchInsertSegments(_ segments: [AudioSegment], sessionId: UUID) async throws {
        let context = ModelContext(modelContainer)

        guard let session = try await fetchSession(id: sessionId) else {
            throw AppError.recordNotFound(entityType: "RecordingSession", id: sessionId.uuidString)
        }

        for segment in segments {
            segment.session = session
            context.insert(segment)
        }

        do {
            try context.save()
            AppLogger.data.info("Batch inserted \(segments.count) segments for session: \(sessionId.uuidString)")
        } catch {
            AppLogger.data.error("Failed to batch insert segments", error: error)
            throw AppError.dataOperationFailed(operation: "batchInsertSegments", reason: error.localizedDescription)
        }
    }

    public func updateSegmentTranscriptionState(segmentId: UUID, state: TranscriptionState) async throws {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<AudioSegment> { segment in
            segment.id == segmentId
        }

        let descriptor = FetchDescriptor<AudioSegment>(predicate: predicate)

        do {
            let segments = try context.fetch(descriptor)
            guard let segment = segments.first else {
                throw AppError.recordNotFound(entityType: "AudioSegment", id: segmentId.uuidString)
            }

            segment.transcriptionState = state
            try context.save()

            AppLogger.data.debug("Updated segment \(segmentId.uuidString) state to: \(state.displayString)")
        } catch let error as AppError {
            throw error
        } catch {
            AppLogger.data.error("Failed to update segment state", error: error)
            throw AppError.dataOperationFailed(operation: "updateSegmentTranscriptionState", reason: error.localizedDescription)
        }
    }

    public func fetchSegments(
        sessionId: UUID,
        sortDescriptors: [SortDescriptor<AudioSegment>]
    ) async throws -> [AudioSegment] {
        let context = ModelContext(modelContainer)

        // Fetch the session first, then access its segments
        let sessionPredicate = #Predicate<RecordingSession> { s in
            s.id == sessionId
        }
        let sessionDescriptor = FetchDescriptor<RecordingSession>(
            predicate: sessionPredicate
        )

        do {
            guard let session = try context.fetch(sessionDescriptor).first else {
                throw AppError.recordNotFound(entityType: "RecordingSession", id: sessionId.uuidString)
            }

            // Get segments from the session's relationship
            let segments = session.segments

            // Sort manually since we can't use FetchDescriptor here
            let sortedSegments: [AudioSegment]
            if let firstDescriptor = sortDescriptors.first {
                sortedSegments = segments.sorted { lhs, rhs in
                    switch firstDescriptor.order {
                    case .forward:
                        return lhs.index < rhs.index
                    case .reverse:
                        return lhs.index > rhs.index
                    }
                }
            } else {
                sortedSegments = segments.sorted { $0.index < $1.index }
            }

            AppLogger.data.debug("Fetched \(sortedSegments.count) segments for session: \(sessionId.uuidString)")

            // Log transcription status for debugging
            let transcribedCount = sortedSegments.filter { $0.transcription != nil }.count
            AppLogger.data.debug("  → \(transcribedCount) segments have transcriptions")

            return sortedSegments
        } catch let error as AppError {
            throw error
        } catch {
            AppLogger.data.error("Failed to fetch segments", error: error)
            throw AppError.dataOperationFailed(operation: "fetchSegments", reason: error.localizedDescription)
        }
    }

    public func fetchPendingSegments() async throws -> [AudioSegment] {
        let context = ModelContext(modelContainer)

        // Fetch all segments and filter in memory (TranscriptionState can't be used in predicates)
        let descriptor = FetchDescriptor<AudioSegment>()

        do {
            let allSegments = try context.fetch(descriptor)

            // Filter for pending state in memory
            let pendingSegments = allSegments.filter { segment in
                if case .pending = segment.transcriptionState {
                    return true
                }
                return false
            }

            AppLogger.data.debug("Fetched \(pendingSegments.count) pending segments out of \(allSegments.count) total")
            return pendingSegments
        } catch {
            AppLogger.data.error("Failed to fetch pending segments", error: error)
            throw AppError.dataOperationFailed(operation: "fetchPendingSegments", reason: error.localizedDescription)
        }
    }

    // MARK: - Transcription Result Operations

    public func createTranscriptionResult(
        segmentId: UUID,
        text: String,
        confidence: Double?,
        language: String?,
        modelUsed: String
    ) async throws -> TranscriptionResult {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<AudioSegment> { segment in
            segment.id == segmentId
        }

        let descriptor = FetchDescriptor<AudioSegment>(predicate: predicate)

        do {
            let segments = try context.fetch(descriptor)
            guard let segment = segments.first else {
                throw AppError.recordNotFound(entityType: "AudioSegment", id: segmentId.uuidString)
            }

            let result = TranscriptionResult(
                text: text,
                confidence: confidence,
                language: language,
                modelUsed: modelUsed,
                segment: segment
            )

            context.insert(result)
            try context.save()

            AppLogger.data.info("Created transcription result for segment: \(segmentId.uuidString)")
            return result
        } catch let error as AppError {
            throw error
        } catch {
            AppLogger.data.error("Failed to create transcription result", error: error)
            throw AppError.dataOperationFailed(operation: "createTranscriptionResult", reason: error.localizedDescription)
        }
    }

    public func fetchTranscriptionResult(segmentId: UUID) async throws -> TranscriptionResult? {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<TranscriptionResult> { result in
            result.segment?.id == segmentId
        }

        let descriptor = FetchDescriptor<TranscriptionResult>(predicate: predicate)

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            AppLogger.data.error("Failed to fetch transcription result", error: error)
            throw AppError.dataOperationFailed(operation: "fetchTranscriptionResult", reason: error.localizedDescription)
        }
    }

    // MARK: - Maintenance

    public func deleteSessionsOlderThan(_ date: Date) async throws -> Int {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<RecordingSession> { session in
            session.startedAt < date
        }

        let descriptor = FetchDescriptor<RecordingSession>(predicate: predicate)

        do {
            let sessions = try context.fetch(descriptor)
            let count = sessions.count

            for session in sessions {
                context.delete(session)
            }

            try context.save()

            AppLogger.data.info("Deleted \(count) sessions older than \(date.description)")
            return count
        } catch {
            AppLogger.data.error("Failed to delete old sessions", error: error)
            throw AppError.dataOperationFailed(operation: "deleteSessionsOlderThan", reason: error.localizedDescription)
        }
    }

    public func countSessions(predicate: Predicate<RecordingSession>?) async throws -> Int {
        let context = ModelContext(modelContainer)

        let descriptor = FetchDescriptor<RecordingSession>(predicate: predicate)

        do {
            let sessions = try context.fetch(descriptor)
            return sessions.count
        } catch {
            AppLogger.data.error("Failed to count sessions", error: error)
            throw AppError.dataOperationFailed(operation: "countSessions", reason: error.localizedDescription)
        }
    }

    public func save() async throws {
        let context = ModelContext(modelContainer)

        do {
            try context.save()
            AppLogger.data.debug("Context saved successfully")
        } catch {
            AppLogger.data.error("Failed to save context", error: error)
            throw AppError.dataOperationFailed(operation: "save", reason: error.localizedDescription)
        }
    }
}

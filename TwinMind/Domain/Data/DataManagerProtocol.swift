//
//  DataManagerProtocol.swift
//  TwinMind
//
//  Purpose: Protocol defining the contract for SwiftData persistence operations.
//  Design decision: All SwiftData operations go through this actor to ensure
//  thread-safe access and centralized data integrity management.
//

import Foundation
import SwiftData

/// Protocol defining the interface for SwiftData persistence operations.
///
/// Conforming types (typically `DataManagerActor`) handle all CRUD operations
/// for RecordingSession, AudioSegment, and TranscriptionResult entities.
public protocol DataManagerProtocol: Actor {

    // MARK: - Session Operations

    /// Creates a new recording session.
    ///
    /// - Parameters:
    ///   - id: Unique session identifier.
    ///   - name: Session name.
    ///   - quality: Recording quality preset.
    /// - Returns: The created `RecordingSession`.
    /// - Throws: `AppError.dataOperationFailed` if creation fails.
    func createSession(id: UUID, name: String, quality: RecordingQuality) async throws -> RecordingSession

    /// Updates an existing recording session.
    ///
    /// - Parameter session: The session to update.
    /// - Throws: `AppError.dataOperationFailed` if update fails.
    func updateSession(_ session: RecordingSession) async throws

    /// Fetches a recording session by ID.
    ///
    /// - Parameter id: The session ID.
    /// - Returns: The session, or `nil` if not found.
    /// - Throws: `AppError.dataOperationFailed` if fetch fails.
    func fetchSession(id: UUID) async throws -> RecordingSession?

    /// Fetches sessions matching a predicate with pagination.
    ///
    /// - Parameters:
    ///   - predicate: Optional filter predicate.
    ///   - sortDescriptors: Sort order.
    ///   - limit: Number of results per page.
    ///   - offset: Number of results to skip.
    /// - Returns: Array of matching sessions.
    /// - Throws: `AppError.dataOperationFailed` if fetch fails.
    func fetchSessions(
        predicate: Predicate<RecordingSession>?,
        sortDescriptors: [SortDescriptor<RecordingSession>],
        limit: Int,
        offset: Int
    ) async throws -> [RecordingSession]

    /// Deletes a recording session and all its segments.
    ///
    /// - Parameter id: The session ID to delete.
    /// - Throws: `AppError.dataOperationFailed` if deletion fails.
    func deleteSession(id: UUID) async throws

    // MARK: - Segment Operations

    /// Creates a new audio segment.
    ///
    /// - Parameters:
    ///   - sessionId: The parent session ID.
    ///   - index: Segment index within the session.
    ///   - startOffset: Start time from session start (seconds).
    ///   - duration: Segment duration (seconds).
    ///   - audioFilePath: Path to the encrypted audio file.
    ///   - id: Optional segment ID (defaults to new UUID if not provided).
    /// - Returns: The created `AudioSegment`.
    /// - Throws: `AppError.dataOperationFailed` if creation fails.
    func createSegment(
        sessionId: UUID,
        index: Int,
        startOffset: Double,
        duration: Double,
        audioFilePath: String,
        id: UUID?
    ) async throws -> AudioSegment

    /// Batch inserts multiple audio segments.
    ///
    /// - Parameters:
    ///   - segments: Array of segments to insert.
    ///   - sessionId: The parent session ID.
    /// - Throws: `AppError.dataOperationFailed` if batch insert fails.
    func batchInsertSegments(_ segments: [AudioSegment], sessionId: UUID) async throws

    /// Updates an audio segment's transcription state.
    ///
    /// - Parameters:
    ///   - segmentId: The segment ID.
    ///   - state: The new transcription state.
    /// - Throws: `AppError.dataOperationFailed` if update fails.
    func updateSegmentTranscriptionState(segmentId: UUID, state: TranscriptionState) async throws

    /// Fetches a single segment by ID.
    ///
    /// - Parameter id: The segment ID.
    /// - Returns: The segment, or `nil` if not found.
    /// - Throws: `AppError.dataOperationFailed` if fetch fails.
    func fetchSegment(id: UUID) async throws -> AudioSegment?

    /// Fetches segments for a specific session.
    ///
    /// - Parameters:
    ///   - sessionId: The parent session ID.
    ///   - sortDescriptors: Sort order (defaults to by index).
    /// - Returns: Array of segments.
    /// - Throws: `AppError.dataOperationFailed` if fetch fails.
    func fetchSegments(
        sessionId: UUID,
        sortDescriptors: [SortDescriptor<AudioSegment>]
    ) async throws -> [AudioSegment]

    /// Fetches segments with pending transcription.
    ///
    /// - Returns: Array of segments awaiting transcription.
    /// - Throws: `AppError.dataOperationFailed` if fetch fails.
    func fetchPendingSegments() async throws -> [AudioSegment]

    // MARK: - Transcription Result Operations

    /// Creates a transcription result for a segment.
    ///
    /// - Parameters:
    ///   - segmentId: The segment ID.
    ///   - text: Transcribed text.
    ///   - confidence: Optional confidence score.
    ///   - language: Optional language code.
    ///   - modelUsed: Service identifier (e.g., "gemini-api").
    /// - Returns: The created `TranscriptionResult`.
    /// - Throws: `AppError.dataOperationFailed` if creation fails.
    func createTranscriptionResult(
        segmentId: UUID,
        text: String,
        confidence: Double?,
        language: String?,
        modelUsed: String
    ) async throws -> TranscriptionResult

    /// Fetches the transcription result for a segment.
    ///
    /// - Parameter segmentId: The segment ID.
    /// - Returns: The transcription result, or `nil` if not found.
    /// - Throws: `AppError.dataOperationFailed` if fetch fails.
    func fetchTranscriptionResult(segmentId: UUID) async throws -> TranscriptionResult?

    // MARK: - Maintenance

    /// Deletes sessions older than a given date.
    ///
    /// - Parameter date: Sessions started before this date will be deleted.
    /// - Returns: The number of sessions deleted.
    /// - Throws: `AppError.dataOperationFailed` if deletion fails.
    func deleteSessionsOlderThan(_ date: Date) async throws -> Int

    /// Counts total sessions matching a predicate.
    ///
    /// - Parameter predicate: Optional filter predicate.
    /// - Returns: The count of matching sessions.
    /// - Throws: `AppError.dataOperationFailed` if count fails.
    func countSessions(predicate: Predicate<RecordingSession>?) async throws -> Int

    /// Saves any pending changes to the model context.
    ///
    /// - Throws: `AppError.dataOperationFailed` if save fails.
    func save() async throws
}

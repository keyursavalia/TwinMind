//
//  SessionQueries.swift
//  TwinMind
//
//  Purpose: Reusable SwiftData predicates and sort descriptors for querying sessions.
//  Design decision: Centralized query definitions ensure consistency across
//  the app and make it easier to optimize query performance.
//

import Foundation
import SwiftData

/// Reusable query components for RecordingSession entities.
public enum SessionQueries {

    // MARK: - Predicates

    /// Predicate for all sessions.
    public static var all: Predicate<RecordingSession> {
        #Predicate<RecordingSession> { _ in true }
    }

    /// Predicate for active sessions (recording or paused).
    public static var active: Predicate<RecordingSession> {
        #Predicate<RecordingSession> { session in
            session.state.rawValue == "active" || session.state.rawValue == "paused"
        }
    }

    /// Predicate for completed sessions.
    public static var completed: Predicate<RecordingSession> {
        #Predicate<RecordingSession> { session in
            session.state.rawValue == "completed"
        }
    }

    /// Predicate for failed sessions.
    public static var failed: Predicate<RecordingSession> {
        #Predicate<RecordingSession> { session in
            session.state.rawValue == "failed"
        }
    }

    /// Predicate for cancelled sessions.
    public static var cancelled: Predicate<RecordingSession> {
        #Predicate<RecordingSession> { session in
            session.state.rawValue == "cancelled"
        }
    }

    /// Predicate for sessions in a specific state.
    ///
    /// - Parameter state: The session state to filter by.
    /// - Returns: A predicate matching sessions in the given state.
    public static func withState(_ state: SessionState) -> Predicate<RecordingSession> {
        let stateValue = state.rawValue
        return #Predicate<RecordingSession> { session in
            session.state.rawValue == stateValue
        }
    }

    /// Predicate for sessions started after a given date.
    ///
    /// - Parameter date: The minimum start date.
    /// - Returns: A predicate matching sessions started after the date.
    public static func startedAfter(_ date: Date) -> Predicate<RecordingSession> {
        #Predicate<RecordingSession> { session in
            session.startedAt > date
        }
    }

    /// Predicate for sessions started before a given date.
    ///
    /// - Parameter date: The maximum start date.
    /// - Returns: A predicate matching sessions started before the date.
    public static func startedBefore(_ date: Date) -> Predicate<RecordingSession> {
        #Predicate<RecordingSession> { session in
            session.startedAt < date
        }
    }

    /// Predicate for sessions within a date range.
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range.
    ///   - endDate: The end of the date range.
    /// - Returns: A predicate matching sessions within the range.
    public static func between(startDate: Date, endDate: Date) -> Predicate<RecordingSession> {
        #Predicate<RecordingSession> { session in
            session.startedAt >= startDate && session.startedAt <= endDate
        }
    }

    /// Predicate for sessions started today.
    public static var today: Predicate<RecordingSession> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        return #Predicate<RecordingSession> { session in
            session.startedAt >= startOfDay && session.startedAt < endOfDay
        }
    }

    /// Predicate for sessions with a name containing a search string.
    ///
    /// - Parameter searchText: The text to search for (case-insensitive).
    /// - Returns: A predicate matching sessions with names containing the text.
    public static func nameContains(_ searchText: String) -> Predicate<RecordingSession> {
        #Predicate<RecordingSession> { session in
            session.name.localizedStandardContains(searchText)
        }
    }

    /// Predicate for sessions with a minimum duration.
    ///
    /// - Parameter minimumSeconds: The minimum duration in seconds.
    /// - Returns: A predicate matching sessions with at least the given duration.
    public static func durationAtLeast(_ minimumSeconds: Double) -> Predicate<RecordingSession> {
        #Predicate<RecordingSession> { session in
            session.durationSeconds >= minimumSeconds
        }
    }

    /// Predicate for sessions with a specific quality preset.
    ///
    /// - Parameter quality: The recording quality preset.
    /// - Returns: A predicate matching sessions with the given quality.
    public static func withQuality(_ quality: RecordingQuality) -> Predicate<RecordingSession> {
        let qualityString = quality.rawValue
        return #Predicate<RecordingSession> { session in
            session.qualityPreset == qualityString
        }
    }

    // MARK: - Sort Descriptors

    /// Sort by start date, newest first.
    public static var sortByNewest: [SortDescriptor<RecordingSession>] {
        [SortDescriptor(\.startedAt, order: .reverse)]
    }

    /// Sort by start date, oldest first.
    public static var sortByOldest: [SortDescriptor<RecordingSession>] {
        [SortDescriptor(\.startedAt, order: .forward)]
    }

    /// Sort by duration, longest first.
    public static var sortByLongest: [SortDescriptor<RecordingSession>] {
        [SortDescriptor(\.durationSeconds, order: .reverse)]
    }

    /// Sort by duration, shortest first.
    public static var sortByShortest: [SortDescriptor<RecordingSession>] {
        [SortDescriptor(\.durationSeconds, order: .forward)]
    }

    /// Sort by name, alphabetically.
    public static var sortByName: [SortDescriptor<RecordingSession>] {
        [SortDescriptor(\.name, order: .forward)]
    }

    /// Sort by state, then by start date (newest first).
    public static var sortByStateAndDate: [SortDescriptor<RecordingSession>] {
        [
            SortDescriptor(\.state, order: .forward),
            SortDescriptor(\.startedAt, order: .reverse)
        ]
    }
}

// MARK: - Segment Queries

/// Reusable query components for AudioSegment entities.
///
/// Note: TranscriptionState is an enum with associated values, which cannot be
/// compared directly in SwiftData predicates. Fetch segments using these predicates
/// and filter in memory using the `TranscriptionState` computed properties
/// (`isProcessing`, `isWaiting`, `isTerminal`, etc.).
public enum SegmentQueries {

    // MARK: - Predicates

    /// Predicate for all segments.
    public static var all: Predicate<AudioSegment> {
        #Predicate<AudioSegment> { _ in true }
    }

    // MARK: - Sort Descriptors

    /// Sort by index (playback order).
    public static var sortByIndex: [SortDescriptor<AudioSegment>] {
        [SortDescriptor(\.index, order: .forward)]
    }

    /// Sort by creation time, newest first.
    public static var sortByNewest: [SortDescriptor<AudioSegment>] {
        [SortDescriptor(\.createdAt, order: .reverse)]
    }

    /// Sort by start offset (chronological order in session).
    public static var sortByStartOffset: [SortDescriptor<AudioSegment>] {
        [SortDescriptor(\.startOffset, order: .forward)]
    }
}

// MARK: - FetchDescriptor Builders

extension SessionQueries {

    /// Creates a paginated fetch descriptor for sessions.
    ///
    /// - Parameters:
    ///   - predicate: The filter predicate.
    ///   - sortDescriptors: The sort order.
    ///   - limit: Number of results per page.
    ///   - offset: Number of results to skip.
    /// - Returns: A configured FetchDescriptor.
    public static func paginated(
        predicate: Predicate<RecordingSession>? = nil,
        sortDescriptors: [SortDescriptor<RecordingSession>] = sortByNewest,
        limit: Int = 20,
        offset: Int = 0
    ) -> FetchDescriptor<RecordingSession> {
        var descriptor = FetchDescriptor<RecordingSession>(
            predicate: predicate,
            sortBy: sortDescriptors
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return descriptor
    }
}

extension SegmentQueries {

    /// Creates a fetch descriptor for segments in a session.
    ///
    /// - Parameters:
    ///   - sessionId: The parent session ID.
    ///   - sortDescriptors: The sort order.
    /// - Returns: A configured FetchDescriptor.
    public static func forSession(
        _ sessionId: UUID,
        sortDescriptors: [SortDescriptor<AudioSegment>] = sortByIndex
    ) -> FetchDescriptor<AudioSegment> {
        let predicate = #Predicate<AudioSegment> { segment in
            segment.session?.id == sessionId
        }
        return FetchDescriptor<AudioSegment>(
            predicate: predicate,
            sortBy: sortDescriptors
        )
    }
}

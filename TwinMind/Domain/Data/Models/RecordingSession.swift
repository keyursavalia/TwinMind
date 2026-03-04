//
//  RecordingSession.swift
//  TwinMind
//
//  Purpose: SwiftData model representing a complete recording session.
//  Design decision: Top-level entity that owns a cascade of AudioSegments.
//  Indexed on startedAt and state for efficient querying and sorting.
//

import Foundation
import SwiftData

/// A recording session entity persisted in SwiftData.
///
/// Each session represents a complete recording from start to stop, containing
/// metadata, state, and a collection of 30-second audio segments. Sessions are
/// the primary entity users interact with in the session list view.
@Model
public final class RecordingSession {

    // MARK: - Properties

    /// Unique identifier for this session.
    @Attribute(.unique)
    public var id: UUID

    /// User-provided or auto-generated name for the session.
    public var name: String

    /// Timestamp when recording started.
    public var startedAt: Date

    /// Timestamp when recording ended (nil if still active or paused).
    public var endedAt: Date?

    /// Total duration of the recording in seconds.
    public var durationSeconds: Double

    /// The recording quality preset used for this session.
    public var qualityPreset: String

    /// File path to the merged encrypted audio file (optional, for playback).
    public var audioFilePath: String?

    /// Current state of the session.
    public var state: SessionState

    /// All audio segments belonging to this session.
    @Relationship(deleteRule: .cascade, inverse: \AudioSegment.session)
    public var segments: [AudioSegment]

    // MARK: - Initialization

    /// Creates a new recording session.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - name: Session name.
    ///   - startedAt: Start timestamp (defaults to current date).
    ///   - endedAt: End timestamp (nil for active sessions).
    ///   - durationSeconds: Total duration in seconds.
    ///   - qualityPreset: Quality preset raw value ("high", "medium", "low").
    ///   - audioFilePath: Optional path to merged audio file.
    ///   - state: Session state (defaults to .active).
    ///   - segments: Initial segments (defaults to empty array).
    public init(
        id: UUID = UUID(),
        name: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        durationSeconds: Double = 0,
        qualityPreset: String,
        audioFilePath: String? = nil,
        state: SessionState = .active,
        segments: [AudioSegment] = []
    ) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.qualityPreset = qualityPreset
        self.audioFilePath = audioFilePath
        self.state = state
        self.segments = segments
    }
}

// MARK: - Computed Properties

extension RecordingSession {

    /// The recording quality preset as a typed enum.
    public var quality: RecordingQuality? {
        RecordingQuality(rawValue: qualityPreset)
    }

    /// Whether the session is currently active (recording or paused).
    public var isActive: Bool {
        state == .active || state == .paused
    }

    /// The number of segments in this session.
    public var segmentCount: Int {
        segments.count
    }

    /// The number of segments that have completed transcription.
    public var transcribedSegmentCount: Int {
        segments.filter { segment in
            if case .completed = segment.transcriptionState {
                return true
            }
            return false
        }.count
    }

    /// The transcription completion progress (0.0 to 1.0).
    public var transcriptionProgress: Double {
        guard segmentCount > 0 else { return 0.0 }
        return Double(transcribedSegmentCount) / Double(segmentCount)
    }

    /// Formatted duration string (e.g., "1:23:45" or "5:30").
    public var formattedDuration: String {
        let hours = Int(durationSeconds) / 3600
        let minutes = (Int(durationSeconds) % 3600) / 60
        let seconds = Int(durationSeconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Formatted start date string (e.g., "Mar 4, 2026 at 2:30 PM").
    public var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startedAt)
    }

    /// Date string for grouping in lists (e.g., "Today", "Yesterday", "Mar 4, 2026").
    public var groupingDateString: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(startedAt) {
            return "Today"
        } else if calendar.isDateInYesterday(startedAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: startedAt)
        }
    }
}

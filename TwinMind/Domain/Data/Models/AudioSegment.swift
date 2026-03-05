//
//  AudioSegment.swift
//  TwinMind
//
//  Purpose: SwiftData model representing a 30-second audio segment.
//  Design decision: Segments are created in real-time during recording and
//  queued for transcription. Indexed on transcriptionState for status queries.
//

import Foundation
import SwiftData

/// An audio segment entity persisted in SwiftData.
///
/// Each segment represents a 30-second (configurable) slice of a recording session.
/// Segments are created as the recording progresses and are individually transcribed.
@Model
public final class AudioSegment {

    // MARK: - Properties

    /// Unique identifier for this segment.
    @Attribute(.unique)
    public var id: UUID

    /// The index of this segment within its parent session (0-based).
    public var index: Int

    /// The start offset from the beginning of the session (in seconds).
    public var startOffset: Double

    /// The duration of this segment (in seconds).
    public var durationSeconds: Double

    /// File path to the encrypted audio segment file.
    public var audioFilePath: String

    /// Encoded transcription state data (private storage).
    private var transcriptionStateData: Data

    /// Current transcription processing state.
    @Transient
    public var transcriptionState: TranscriptionState {
        get {
            guard let decoded = try? JSONDecoder().decode(TranscriptionState.self, from: transcriptionStateData) else {
                return .pending
            }
            return decoded
        }
        set {
            guard let encoded = try? JSONEncoder().encode(newValue) else {
                transcriptionStateData = Data()
                return
            }
            transcriptionStateData = encoded
        }
    }

    /// Timestamp when this segment was created.
    public var createdAt: Date

    /// The transcription result for this segment (nil until completed).
    @Relationship(deleteRule: .cascade, inverse: \TranscriptionResult.segment)
    public var transcription: TranscriptionResult?

    /// The parent recording session.
    public var session: RecordingSession?

    // MARK: - Initialization

    /// Creates a new audio segment.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - index: Segment index within the session.
    ///   - startOffset: Start time from session start (seconds).
    ///   - durationSeconds: Segment duration (seconds).
    ///   - audioFilePath: Path to the encrypted audio file.
    ///   - transcriptionState: Initial transcription state (defaults to .pending).
    ///   - createdAt: Timestamp when segment was created (defaults to now).
    ///   - transcription: Optional transcription result.
    ///   - session: Parent recording session.
    public init(
        id: UUID = UUID(),
        index: Int,
        startOffset: Double,
        durationSeconds: Double,
        audioFilePath: String,
        transcriptionState: TranscriptionState = .pending,
        createdAt: Date = Date(),
        transcription: TranscriptionResult? = nil,
        session: RecordingSession? = nil
    ) {
        self.id = id
        self.index = index
        self.startOffset = startOffset
        self.durationSeconds = durationSeconds
        self.audioFilePath = audioFilePath
        self.createdAt = createdAt
        self.transcription = transcription
        self.session = session

        // Encode the transcription state
        self.transcriptionStateData = (try? JSONEncoder().encode(transcriptionState)) ?? Data()
    }
}

// MARK: - Computed Properties

extension AudioSegment {

    /// Whether this segment has a completed transcription.
    public var isTranscribed: Bool {
        if case .completed = transcriptionState {
            return true
        }
        return false
    }

    /// Whether this segment is currently being processed.
    public var isProcessing: Bool {
        transcriptionState.isProcessing
    }

    /// Whether this segment is waiting to be processed.
    public var isWaiting: Bool {
        transcriptionState.isWaiting
    }

    /// Whether this segment's transcription has failed.
    public var hasFailed: Bool {
        if case .failed = transcriptionState {
            return true
        }
        return false
    }

    /// The end offset of this segment (startOffset + duration).
    public var endOffset: Double {
        startOffset + durationSeconds
    }

    /// Formatted time range string (e.g., "0:30 - 1:00").
    public var formattedTimeRange: String {
        let start = formatSeconds(startOffset)
        let end = formatSeconds(endOffset)
        return "\(start) - \(end)"
    }

    /// Formatted duration string (e.g., "30s" or "1:00").
    public var formattedDuration: String {
        formatSeconds(durationSeconds)
    }

    /// The transcription text, if available.
    public var transcriptionText: String? {
        transcription?.text
    }

    /// The service that processed this segment, if available.
    public var processingService: String? {
        switch transcriptionState {
        case .processing(_, let service), .completed(_, let service):
            return service
        default:
            return transcription?.modelUsed
        }
    }

    // MARK: - Private Helpers

    private func formatSeconds(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

//
//  TranscriptionResult.swift
//  TwinMind
//
//  Purpose: SwiftData model representing a completed transcription.
//  Design decision: Separate entity to store rich metadata (confidence, language)
//  and support future features like alternative transcriptions or speaker diarization.
//

import Foundation
import SwiftData

/// A transcription result entity persisted in SwiftData.
///
/// Each result represents the final transcribed text for a single audio segment,
/// along with metadata about confidence, language, and the service used.
@Model
public final class TranscriptionResult {

    // MARK: - Properties

    /// Unique identifier for this transcription result.
    @Attribute(.unique)
    public var id: UUID

    /// The transcribed text content.
    public var text: String

    /// Confidence score from the transcription service (0.0 to 1.0, if available).
    public var confidence: Double?

    /// Detected or specified language code (e.g., "en", "es", if available).
    public var language: String?

    /// The transcription model/service used.
    public var modelUsed: String

    /// Timestamp when this transcription was processed.
    public var processedAt: Date

    /// The parent audio segment.
    public var segment: AudioSegment?

    // MARK: - Initialization

    /// Creates a new transcription result.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - text: The transcribed text.
    ///   - confidence: Optional confidence score (0.0 to 1.0).
    ///   - language: Optional language code.
    ///   - modelUsed: The service/model identifier (e.g., "whisper-api", "apple-stt").
    ///   - processedAt: Processing timestamp (defaults to now).
    ///   - segment: Parent audio segment.
    public init(
        id: UUID = UUID(),
        text: String,
        confidence: Double? = nil,
        language: String? = nil,
        modelUsed: String,
        processedAt: Date = Date(),
        segment: AudioSegment? = nil
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.language = language
        self.modelUsed = modelUsed
        self.processedAt = processedAt
        self.segment = segment
    }
}

// MARK: - Computed Properties

extension TranscriptionResult {

    /// User-facing display name for the model used.
    public var modelDisplayName: String {
        switch modelUsed {
        case "whisper-api":
            return "Whisper API"
        case "apple-stt":
            return "Apple Speech Recognition"
        case "local-whisper":
            return "Local Whisper"
        default:
            return modelUsed.capitalized
        }
    }

    /// Formatted confidence percentage (e.g., "95%"), if available.
    public var formattedConfidence: String? {
        guard let confidence = confidence else { return nil }
        let percentage = Int(confidence * 100)
        return "\(percentage)%"
    }

    /// Formatted language name (e.g., "English"), if available.
    public var formattedLanguage: String? {
        guard let language = language else { return nil }
        let locale = Locale(identifier: language)
        return locale.localizedString(forLanguageCode: language)?.capitalized
    }

    /// Formatted processing date (e.g., "Mar 4, 2026 at 2:30 PM").
    public var formattedProcessedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: processedAt)
    }

    /// Word count of the transcribed text.
    public var wordCount: Int {
        text.split(separator: " ").count
    }

    /// Character count of the transcribed text.
    public var characterCount: Int {
        text.count
    }

    /// Whether the transcription appears to be empty or contains only whitespace.
    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Confidence level category for UI display.
    public var confidenceLevel: ConfidenceLevel {
        guard let confidence = confidence else { return .unknown }
        switch confidence {
        case 0.9...1.0:
            return .high
        case 0.7..<0.9:
            return .medium
        case 0.0..<0.7:
            return .low
        default:
            return .unknown
        }
    }
}

// MARK: - ConfidenceLevel

/// Categorized confidence levels for UI presentation.
public enum ConfidenceLevel: String, Sendable {
    case high
    case medium
    case low
    case unknown

    /// User-facing display string.
    public var displayString: String {
        switch self {
        case .high:
            return "High Confidence"
        case .medium:
            return "Medium Confidence"
        case .low:
            return "Low Confidence"
        case .unknown:
            return "Unknown"
        }
    }

    /// SF Symbol icon name for the confidence level.
    public var iconName: String {
        switch self {
        case .high:
            return "checkmark.circle.fill"
        case .medium:
            return "checkmark.circle"
        case .low:
            return "exclamationmark.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }

    /// Color name for the confidence level.
    public var colorName: String {
        switch self {
        case .high:
            return "green"
        case .medium:
            return "orange"
        case .low:
            return "red"
        case .unknown:
            return "gray"
        }
    }
}

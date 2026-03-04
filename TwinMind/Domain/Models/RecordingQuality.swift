//
//  RecordingQuality.swift
//  TwinMind
//
//  Purpose: Defines recording quality presets that control sample rate,
//  bit depth, and segment duration.
//  Design decision: Presets balance transcription accuracy vs storage/battery.
//

import Foundation

/// Recording quality preset with audio format and segmentation parameters.
///
/// Each preset defines the sample rate, bit depth, and segment duration
/// used for audio recording. Higher quality improves transcription accuracy
/// but increases storage usage and battery consumption.
public enum RecordingQuality: String, Sendable, Equatable, Codable, CaseIterable {

    /// High quality: 48kHz, 32-bit float, 30-second segments.
    case high

    /// Medium quality: 22.05kHz, 16-bit, 30-second segments (default).
    case medium

    /// Low quality: 16kHz, 16-bit, 60-second segments (battery saver).
    case low
}

// MARK: - Audio Format Parameters

extension RecordingQuality {

    /// The audio sample rate in Hz.
    public var sampleRate: Double {
        switch self {
        case .high:
            return 48000.0
        case .medium:
            return 22050.0
        case .low:
            return 16000.0
        }
    }

    /// The audio bit depth.
    public var bitDepth: Int {
        switch self {
        case .high:
            return 32
        case .medium:
            return 16
        case .low:
            return 16
        }
    }

    /// Whether to use floating-point samples.
    public var isFloat: Bool {
        switch self {
        case .high:
            return true
        case .medium, .low:
            return false
        }
    }

    /// The duration of each audio segment in seconds.
    public var segmentDuration: TimeInterval {
        switch self {
        case .high:
            return 30.0
        case .medium:
            return 30.0
        case .low:
            return 60.0
        }
    }

    /// The number of audio channels (always mono for voice).
    public var channelCount: Int {
        return 1
    }

    /// Estimated storage usage in MB per minute of recording.
    public var estimatedMBPerMinute: Double {
        switch self {
        case .high:
            return 5.5
        case .medium:
            return 1.3
        case .low:
            return 0.9
        }
    }

    /// A user-facing display name for the quality preset.
    public var displayName: String {
        switch self {
        case .high:
            return "High Quality"
        case .medium:
            return "Medium Quality"
        case .low:
            return "Low Quality (Battery Saver)"
        }
    }

    /// A user-facing description of the quality preset.
    public var description: String {
        switch self {
        case .high:
            return "\(Int(sampleRate / 1000))kHz · \(bitDepth)-bit · ~\(String(format: "%.1f", estimatedMBPerMinute))MB/min"
        case .medium:
            return "\(Int(sampleRate / 1000))kHz · \(bitDepth)-bit · ~\(String(format: "%.1f", estimatedMBPerMinute))MB/min (Recommended)"
        case .low:
            return "\(Int(sampleRate / 1000))kHz · \(bitDepth)-bit · ~\(String(format: "%.1f", estimatedMBPerMinute))MB/min"
        }
    }
}

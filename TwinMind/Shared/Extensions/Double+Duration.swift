//
//  Double+Duration.swift
//  TwinMind
//
//  Purpose: Duration formatting utilities for audio playback and recording times.
//  Design decision: Consistent time formatting across recording duration displays,
//  segment timecodes, and playback position indicators.
//

import Foundation

// MARK: - Double Extension (Duration)

extension Double {

    // MARK: - Formatted Duration

    /// Formats duration in seconds as "H:MM:SS" or "M:SS".
    ///
    /// Examples:
    /// - 45.5 → "0:45"
    /// - 125.0 → "2:05"
    /// - 3725.0 → "1:02:05"
    public var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Formats duration with millisecond precision as "H:MM:SS.mmm" or "M:SS.mmm".
    ///
    /// Examples:
    /// - 45.567 → "0:45.567"
    /// - 125.123 → "2:05.123"
    public var formattedDurationWithMilliseconds: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        let milliseconds = Int((self.truncatingRemainder(dividingBy: 1.0)) * 1000)

        if hours > 0 {
            return String(format: "%d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
        }
    }

    /// Formats duration in a compact form (e.g., "45s", "2m 5s", "1h 2m").
    ///
    /// Examples:
    /// - 45.0 → "45s"
    /// - 125.0 → "2m 5s"
    /// - 3725.0 → "1h 2m"
    public var compactDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Formats duration in a verbose form (e.g., "45 seconds", "2 minutes, 5 seconds").
    ///
    /// Examples:
    /// - 1.0 → "1 second"
    /// - 45.0 → "45 seconds"
    /// - 125.0 → "2 minutes, 5 seconds"
    /// - 3725.0 → "1 hour, 2 minutes"
    public var verboseDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        var components: [String] = []

        if hours > 0 {
            components.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 {
            components.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        if seconds > 0 || components.isEmpty {
            components.append("\(seconds) second\(seconds == 1 ? "" : "s")")
        }

        return components.joined(separator: ", ")
    }

    // MARK: - Duration Components

    /// Returns duration components (hours, minutes, seconds).
    public var durationComponents: (hours: Int, minutes: Int, seconds: Int) {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        return (hours, minutes, seconds)
    }

    // MARK: - File Size Formatting

    /// Formats bytes as human-readable size (e.g., "1.5 MB", "234 KB").
    ///
    /// Useful for displaying file sizes of audio segments.
    public var formattedFileSize: String {
        let bytes = self
        let kilobyte = 1024.0
        let megabyte = kilobyte * 1024.0
        let gigabyte = megabyte * 1024.0

        if bytes >= gigabyte {
            return String(format: "%.1f GB", bytes / gigabyte)
        } else if bytes >= megabyte {
            return String(format: "%.1f MB", bytes / megabyte)
        } else if bytes >= kilobyte {
            return String(format: "%.1f KB", bytes / kilobyte)
        } else {
            return String(format: "%.0f bytes", bytes)
        }
    }
}

// MARK: - TimeInterval Typealias Extension

extension TimeInterval {

    /// Formats the time interval as a duration string.
    ///
    /// Convenience wrapper for `Double.formattedDuration`.
    public var formatted: String {
        return self.formattedDuration
    }

    /// Formats the time interval as a compact duration string.
    ///
    /// Convenience wrapper for `Double.compactDuration`.
    public var compact: String {
        return self.compactDuration
    }

    /// Formats the time interval as a verbose duration string.
    ///
    /// Convenience wrapper for `Double.verboseDuration`.
    public var verbose: String {
        return self.verboseDuration
    }
}

// MARK: - Int64 Extension (File Size)

extension Int64 {

    /// Formats bytes as human-readable size (e.g., "1.5 MB", "234 KB").
    public var formattedFileSize: String {
        return Double(self).formattedFileSize
    }
}

//
//  AppLogger.swift
//  TwinMind
//
//  Purpose: Centralized logging infrastructure using os.Logger.
//  Design decision: Structured logging per subsystem with consistent categories
//  enables filtered log viewing and performance profiling in Instruments.
//

import Foundation
import OSLog

/// Centralized logging infrastructure for the TwinMind application.
///
/// This utility provides category-specific loggers for different subsystems,
/// enabling structured logging with proper log levels and Instruments integration.
public enum AppLogger {

    // MARK: - Subsystem

    /// The app's subsystem identifier for all loggers.
    private static let subsystem = "com.twinmind.app"

    // MARK: - Category Loggers

    /// Logger for audio engine operations.
    public static let audio = Logger(subsystem: subsystem, category: "audio")

    /// Logger for transcription pipeline operations.
    public static let transcription = Logger(subsystem: subsystem, category: "transcription")

    /// Logger for SwiftData persistence operations.
    public static let data = Logger(subsystem: subsystem, category: "data")

    /// Logger for network operations.
    public static let network = Logger(subsystem: subsystem, category: "network")

    /// Logger for encryption and security operations.
    public static let security = Logger(subsystem: subsystem, category: "security")

    /// Logger for Keychain operations.
    public static let keychain = Logger(subsystem: subsystem, category: "keychain")

    /// Logger for UI and view operations.
    public static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Logger for app lifecycle events.
    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")

    /// Logger for Live Activity operations.
    public static let liveActivity = Logger(subsystem: subsystem, category: "live-activity")

    /// Logger for App Intents and Shortcuts.
    public static let appIntents = Logger(subsystem: subsystem, category: "app-intents")

    /// Logger for background tasks.
    public static let background = Logger(subsystem: subsystem, category: "background")

    /// Logger for general application events.
    public static let general = Logger(subsystem: subsystem, category: "general")
}

// MARK: - Logger Extensions

extension Logger {

    /// Logs a debug message with source location information (DEBUG builds only).
    ///
    /// This is a convenience wrapper that adds file, function, and line information
    /// to debug logs, making it easier to locate log statements during development.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - file: Source file (default: #file).
    ///   - function: Source function (default: #function).
    ///   - line: Source line (default: #line).
    public func logDebug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        self.debug("\(fileName):\(line) \(function) - \(message)")
        #endif
    }

    /// Logs an error message with optional error details.
    ///
    /// This is a convenience wrapper for logging errors with automatic error description formatting.
    ///
    /// - Parameters:
    ///   - message: The error message.
    ///   - error: Optional associated error to include in the log.
    public func error(_ message: String, error: Error?) {
        if let error = error {
            self.error("\(message): \(error.localizedDescription)")
        } else {
            self.error("\(message)")
        }
    }
}

// MARK: - Signpost Support

extension AppLogger {

    /// Creates a signpost logger for performance profiling.
    ///
    /// Signposts enable interval-based performance measurement in Instruments.
    ///
    /// - Parameter category: The category for the signpost.
    /// - Returns: A configured OSLog instance for signposts.
    public static func signpost(category: String) -> OSLog {
        return OSLog(subsystem: subsystem, category: category)
    }
}

// MARK: - Usage Examples

/*
 Example usage:

 // Basic logging - use os.Logger methods directly
 AppLogger.audio.info("Audio engine started")
 AppLogger.transcription.warning("API rate limit approaching")
 AppLogger.data.notice("Configuration updated")

 // Error logging with error details
 AppLogger.data.error("Failed to save session", error: error)  // Uses the extension overload
 AppLogger.network.error("Request failed")  // Uses os.Logger's error() directly

 // Debug logging with source location (only in DEBUG builds)
 AppLogger.network.logDebug("Request headers: \(headers)")

 // Standard debug logging (if source location not needed)
 AppLogger.audio.debug("Buffer size: \(bufferSize)")

 // Performance profiling with signposts
 let log = AppLogger.signpost(category: "transcription")
 let signpostID = OSSignpostID(log: log)
 os_signpost(.begin, log: log, name: "Transcribe Segment", signpostID: signpostID)
 // ... perform work ...
 os_signpost(.end, log: log, name: "Transcribe Segment", signpostID: signpostID)
 */

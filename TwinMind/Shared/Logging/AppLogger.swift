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

    /// Logs a message at the debug level.
    ///
    /// Debug messages are only visible during development and are stripped in release builds.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - file: Source file (default: #file).
    ///   - function: Source function (default: #function).
    ///   - line: Source line (default: #line).
    public func debug(
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

    /// Logs a message at the info level.
    ///
    /// Info messages represent normal application flow.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    public func info(_ message: String) {
        self.info("\(message)")
    }

    /// Logs a message at the notice level.
    ///
    /// Notice messages represent important but non-error events.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    public func notice(_ message: String) {
        self.notice("\(message)")
    }

    /// Logs a message at the warning level.
    ///
    /// Warning messages represent potential issues that don't prevent operation.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    public func warning(_ message: String) {
        self.warning("\(message)")
    }

    /// Logs a message at the error level.
    ///
    /// Error messages represent failures that impact functionality.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - error: Optional associated error.
    public func error(_ message: String, error: Error? = nil) {
        if let error = error {
            self.error("\(message): \(error.localizedDescription)")
        } else {
            self.error("\(message)")
        }
    }

    /// Logs a message at the fault level.
    ///
    /// Fault messages represent critical failures that should never occur.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - error: Optional associated error.
    public func fault(_ message: String, error: Error? = nil) {
        if let error = error {
            self.fault("\(message): \(error.localizedDescription)")
        } else {
            self.fault("\(message)")
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

 // Basic logging
 AppLogger.audio.info("Audio engine started")
 AppLogger.transcription.warning("API rate limit approaching")
 AppLogger.data.error("Failed to save session", error: error)

 // Debug logging (only in DEBUG builds)
 AppLogger.network.debug("Request headers: \(headers)")

 // Performance profiling with signposts
 let log = AppLogger.signpost(category: "transcription")
 let signpostID = OSSignpostID(log: log)
 os_signpost(.begin, log: log, name: "Transcribe Segment", signpostID: signpostID)
 // ... perform work ...
 os_signpost(.end, log: log, name: "Transcribe Segment", signpostID: signpostID)
 */

//
//  AppError.swift
//  TwinMind
//
//  Purpose: Centralized typed error definitions for all app domains.
//  Design decision: Using a single enum with associated values per domain
//  ensures compile-time exhaustive error handling and clear error propagation.
//

import Foundation

/// Typed error cases for all domains in the TwinMind application.
///
/// This enum provides exhaustive error handling across audio, transcription,
/// data persistence, network, and security domains. Each case includes
/// associated values with context for debugging and user-facing messages.
public enum AppError: Error, Equatable, Sendable, Codable {

    // MARK: - Audio Domain Errors

    /// Audio engine failed to start or configure.
    case audioEngineFailure(reason: String)

    /// Audio session configuration failed.
    case audioSessionConfigurationFailed(reason: String)

    /// Audio recording permission was denied by the user.
    case microphonePermissionDenied

    /// Audio route is unavailable (e.g., no input device).
    case audioRouteUnavailable

    /// Audio interruption that could not be recovered.
    case unrecoverableInterruption(reason: String)

    /// Audio file write operation failed.
    case audioFileWriteFailure(path: String, reason: String)

    // MARK: - Transcription Domain Errors

    /// Transcription service API call failed.
    case transcriptionServiceFailure(statusCode: Int?, reason: String)

    /// Transcription retry limit exceeded for a segment.
    case transcriptionRetryLimitExceeded(segmentId: String, attempts: Int)

    /// Invalid audio format for transcription.
    case invalidAudioFormat(expectedFormat: String)

    /// Transcription service API key is missing or invalid.
    case missingAPIKey(service: String)

    // MARK: - Data Domain Errors

    /// SwiftData persistence operation failed.
    case dataOperationFailed(operation: String, reason: String)

    /// Record not found in the data store.
    case recordNotFound(entityType: String, id: String)

    /// Data integrity violation (e.g., orphaned relationships).
    case dataIntegrityViolation(details: String)

    /// Model container initialization failed.
    case modelContainerInitializationFailed(reason: String)

    // MARK: - Network Domain Errors

    /// Network request failed.
    case networkRequestFailed(statusCode: Int?, reason: String)

    /// No internet connection available.
    case noInternetConnection

    /// Network request timed out.
    case networkTimeout

    /// Invalid response format from server.
    case invalidResponseFormat(expectedFormat: String)

    // MARK: - Security Domain Errors

    /// Keychain operation failed.
    case keychainOperationFailed(operation: String, status: OSStatus)

    /// File encryption or decryption failed.
    case encryptionOperationFailed(operation: String, reason: String)

    /// Encryption key not found in Keychain.
    case encryptionKeyNotFound

    /// Invalid encryption key format or size.
    case invalidEncryptionKey

    // MARK: - Storage Domain Errors

    /// Insufficient storage space available.
    case insufficientStorage(requiredBytes: Int64, availableBytes: Int64)

    /// File not found at expected path.
    case fileNotFound(path: String)

    /// File deletion failed.
    case fileDeletionFailed(path: String, reason: String)

    // MARK: - Configuration Errors

    /// Required configuration value is missing.
    case missingConfiguration(key: String)

    /// Invalid configuration value format.
    case invalidConfiguration(key: String, reason: String)

    // MARK: - Live Activity Errors

    /// Live Activity operation failed.
    case liveActivityFailed(operation: String, reason: String)

    // MARK: - App Intent Errors

    /// App Intent execution failed.
    case appIntentFailed(intent: String, reason: String)

    // MARK: - Unknown Errors

    /// An unexpected error occurred.
    case unknown(description: String)
}

// MARK: - Equatable Conformance

extension AppError {

    /// Custom equality check for AppError.
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.audioEngineFailure(let l), .audioEngineFailure(let r)):
            return l == r
        case (.audioSessionConfigurationFailed(let l), .audioSessionConfigurationFailed(let r)):
            return l == r
        case (.microphonePermissionDenied, .microphonePermissionDenied):
            return true
        case (.audioRouteUnavailable, .audioRouteUnavailable):
            return true
        case (.unrecoverableInterruption(let l), .unrecoverableInterruption(let r)):
            return l == r
        case (.audioFileWriteFailure(let l1, let l2), .audioFileWriteFailure(let r1, let r2)):
            return l1 == r1 && l2 == r2

        case (.transcriptionServiceFailure(let l1, let l2), .transcriptionServiceFailure(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.transcriptionRetryLimitExceeded(let l1, let l2), .transcriptionRetryLimitExceeded(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.invalidAudioFormat(let l), .invalidAudioFormat(let r)):
            return l == r
        case (.missingAPIKey(let l), .missingAPIKey(let r)):
            return l == r

        case (.dataOperationFailed(let l1, let l2), .dataOperationFailed(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.recordNotFound(let l1, let l2), .recordNotFound(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.dataIntegrityViolation(let l), .dataIntegrityViolation(let r)):
            return l == r
        case (.modelContainerInitializationFailed(let l), .modelContainerInitializationFailed(let r)):
            return l == r

        case (.networkRequestFailed(let l1, let l2), .networkRequestFailed(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.noInternetConnection, .noInternetConnection):
            return true
        case (.networkTimeout, .networkTimeout):
            return true
        case (.invalidResponseFormat(let l), .invalidResponseFormat(let r)):
            return l == r

        case (.keychainOperationFailed(let l1, let l2), .keychainOperationFailed(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.encryptionOperationFailed(let l1, let l2), .encryptionOperationFailed(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.encryptionKeyNotFound, .encryptionKeyNotFound):
            return true
        case (.invalidEncryptionKey, .invalidEncryptionKey):
            return true

        case (.insufficientStorage(let l1, let l2), .insufficientStorage(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.fileNotFound(let l), .fileNotFound(let r)):
            return l == r
        case (.fileDeletionFailed(let l1, let l2), .fileDeletionFailed(let r1, let r2)):
            return l1 == r1 && l2 == r2

        case (.missingConfiguration(let l), .missingConfiguration(let r)):
            return l == r
        case (.invalidConfiguration(let l1, let l2), .invalidConfiguration(let r1, let r2)):
            return l1 == r1 && l2 == r2

        case (.liveActivityFailed(let l1, let l2), .liveActivityFailed(let r1, let r2)):
            return l1 == r1 && l2 == r2

        case (.appIntentFailed(let l1, let l2), .appIntentFailed(let r1, let r2)):
            return l1 == r1 && l2 == r2

        case (.unknown(let l), .unknown(let r)):
            return l == r

        default:
            return false
        }
    }
}

// MARK: - LocalizedError Conformance

extension AppError: LocalizedError {

    /// User-facing error description.
    public var errorDescription: String? {
        switch self {
        case .audioEngineFailure(let reason):
            return "Audio engine failed: \(reason)"
        case .audioSessionConfigurationFailed(let reason):
            return "Audio session configuration failed: \(reason)"
        case .microphonePermissionDenied:
            return "Microphone access is required. Please grant permission in Settings."
        case .audioRouteUnavailable:
            return "No audio input device available."
        case .unrecoverableInterruption(let reason):
            return "Recording interrupted: \(reason)"
        case .audioFileWriteFailure(let path, let reason):
            return "Failed to write audio file at \(path): \(reason)"

        case .transcriptionServiceFailure(let statusCode, let reason):
            let code = statusCode.map { " (Status: \($0))" } ?? ""
            return "Transcription failed\(code): \(reason)"
        case .transcriptionRetryLimitExceeded(let segmentId, let attempts):
            return "Transcription failed after \(attempts) attempts for segment \(segmentId)."
        case .invalidAudioFormat(let expectedFormat):
            return "Invalid audio format. Expected: \(expectedFormat)"
        case .missingAPIKey(let service):
            return "API key for \(service) is not configured."

        case .dataOperationFailed(let operation, let reason):
            return "Data operation '\(operation)' failed: \(reason)"
        case .recordNotFound(let entityType, let id):
            return "\(entityType) with ID \(id) not found."
        case .dataIntegrityViolation(let details):
            return "Data integrity violation: \(details)"
        case .modelContainerInitializationFailed(let reason):
            return "Failed to initialize data store: \(reason)"

        case .networkRequestFailed(let statusCode, let reason):
            let code = statusCode.map { " (Status: \($0))" } ?? ""
            return "Network request failed\(code): \(reason)"
        case .noInternetConnection:
            return "No internet connection. Please check your network settings."
        case .networkTimeout:
            return "Network request timed out. Please try again."
        case .invalidResponseFormat(let expectedFormat):
            return "Invalid response format. Expected: \(expectedFormat)"

        case .keychainOperationFailed(let operation, let status):
            return "Keychain operation '\(operation)' failed with status: \(status)"
        case .encryptionOperationFailed(let operation, let reason):
            return "Encryption operation '\(operation)' failed: \(reason)"
        case .encryptionKeyNotFound:
            return "Encryption key not found. Please restart the app."
        case .invalidEncryptionKey:
            return "Invalid encryption key."

        case .insufficientStorage(let required, let available):
            let requiredMB = Double(required) / 1_000_000
            let availableMB = Double(available) / 1_000_000
            return "Insufficient storage. Required: \(String(format: "%.1f", requiredMB))MB, Available: \(String(format: "%.1f", availableMB))MB"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileDeletionFailed(let path, let reason):
            return "Failed to delete file at \(path): \(reason)"

        case .missingConfiguration(let key):
            return "Missing configuration for key: \(key)"
        case .invalidConfiguration(let key, let reason):
            return "Invalid configuration for key '\(key)': \(reason)"

        case .liveActivityFailed(let operation, let reason):
            return "Live Activity operation '\(operation)' failed: \(reason)"

        case .appIntentFailed(let intent, let reason):
            return "App Intent '\(intent)' failed: \(reason)"

        case .unknown(let description):
            return "An unexpected error occurred: \(description)"
        }
    }
}

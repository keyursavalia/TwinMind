//
//  TranscriptionServiceProtocol.swift
//  TwinMind
//
//  Purpose: Protocol defining the contract for transcription service implementations.
//  Design decision: Multiple conforming types (Whisper API, Apple STT, local Whisper)
//  enable fallback strategy and swappable backends.
//

import Foundation

/// Protocol defining the interface for audio transcription services.
///
/// Conforming types handle the actual transcription of audio files,
/// whether via remote API (Whisper), on-device framework (Apple Speech),
/// or local model (Whisper GGML).
public protocol TranscriptionServiceProtocol: Sendable {

    /// The unique identifier for this transcription service.
    ///
    /// Examples: "whisper-api", "apple-stt", "local-whisper"
    var serviceIdentifier: String { get }

    /// The display name for this service (user-facing).
    ///
    /// Examples: "Whisper API", "Apple Speech Recognition", "Local Whisper"
    var displayName: String { get }

    /// Whether this service requires an internet connection.
    var requiresNetwork: Bool { get }

    /// Whether this service is currently available.
    ///
    /// Checks API key availability, network connectivity, or model file presence.
    ///
    /// - Returns: `true` if the service can be used, `false` otherwise.
    func isAvailable() async -> Bool

    /// Transcribes an audio file.
    ///
    /// - Parameters:
    ///   - fileURL: URL to the audio file (encrypted or decrypted).
    ///   - language: Optional language code (e.g., "en", "es"). If nil, auto-detect.
    ///   - decrypt: Whether to decrypt the file before transcription (default: true).
    /// - Returns: A `TranscriptionResult` with text and metadata.
    /// - Throws: `AppError` if transcription fails, network is unavailable, or API key is missing.
    func transcribe(
        fileURL: URL,
        language: String?,
        decrypt: Bool
    ) async throws -> TranscriptionServiceResult

    /// Cancels any in-progress transcription for the given file.
    ///
    /// - Parameter fileURL: URL to the audio file being transcribed.
    func cancelTranscription(for fileURL: URL) async
}

// MARK: - TranscriptionServiceResult

/// The result of a transcription operation.
public struct TranscriptionServiceResult: Sendable, Equatable {

    /// The transcribed text.
    public let text: String

    /// Confidence score (0.0 to 1.0), if available.
    public let confidence: Double?

    /// Detected or specified language code (e.g., "en"), if available.
    public let language: String?

    /// The duration of the audio file that was transcribed (in seconds).
    public let duration: TimeInterval?

    /// Additional metadata from the service (JSON dictionary).
    public let metadata: [String: String]

    /// Creates a new transcription service result.
    ///
    /// - Parameters:
    ///   - text: The transcribed text.
    ///   - confidence: Optional confidence score.
    ///   - language: Optional language code.
    ///   - duration: Optional audio duration.
    ///   - metadata: Additional metadata dictionary.
    public init(
        text: String,
        confidence: Double? = nil,
        language: String? = nil,
        duration: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) {
        self.text = text
        self.confidence = confidence
        self.language = language
        self.duration = duration
        self.metadata = metadata
    }
}

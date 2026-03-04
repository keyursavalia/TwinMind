//
//  AppleSpeechService.swift
//  TwinMind
//
//  Purpose: Apple Speech framework integration for on-device transcription.
//  Design decision: Fallback service that works offline, lower accuracy than Whisper.
//  Requires speech recognition permission from the user.
//

import Foundation
import Speech
internal import os

/// Apple Speech Recognition service for audio transcription.
///
/// This service uses SFSpeechRecognizer for on-device or server-based transcription,
/// serving as a fallback when Whisper API is unavailable.
public struct AppleSpeechService: TranscriptionServiceProtocol {

    // MARK: - Properties

    /// Encryption service for decrypting audio files.
    private let encryptionService: any EncryptionServiceProtocol

    /// The speech recognizer instance.
    private let recognizer: SFSpeechRecognizer

    // MARK: - Initialization

    /// Creates a new Apple Speech service.
    ///
    /// - Parameters:
    ///   - encryptionService: Encryption service for audio files.
    ///   - locale: Locale for speech recognition (default: en_US).
    public init(
        encryptionService: any EncryptionServiceProtocol,
        locale: Locale = Locale(identifier: "en_US")
    ) {
        self.encryptionService = encryptionService
        self.recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()!
    }

    // MARK: - TranscriptionServiceProtocol

    public var serviceIdentifier: String {
        "apple-stt"
    }

    public var displayName: String {
        "Apple Speech Recognition"
    }

    public var requiresNetwork: Bool {
        false // Can work offline
    }

    public func isAvailable() async -> Bool {
        // Check authorization
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .authorized else {
            AppLogger.transcription.warning("Apple Speech not authorized: \(status.rawValue)")
            return false
        }

        // Check if recognizer is available
        guard recognizer.isAvailable else {
            AppLogger.transcription.warning("Apple Speech recognizer not available")
            return false
        }

        return true
    }

    public func transcribe(
        fileURL: URL,
        language: String?,
        decrypt: Bool
    ) async throws -> TranscriptionServiceResult {
        AppLogger.transcription.info("Transcribing with Apple Speech: \(fileURL.lastPathComponent)")

        // Request authorization if needed
        let authorized = await requestAuthorization()
        guard authorized else {
            throw AppError.transcriptionServiceFailure(
                statusCode: nil,
                reason: "Speech recognition not authorized"
            )
        }

        // Decrypt file if needed
        let audioFileURL: URL
        if decrypt {
            let decryptedURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileURL.pathExtension)

            audioFileURL = try await encryptionService.decryptFile(at: fileURL, to: decryptedURL)
        } else {
            audioFileURL = fileURL
        }

        defer {
            // Clean up decrypted file
            if decrypt {
                try? FileManager.default.removeItem(at: audioFileURL)
            }
        }

        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false // Allow server-based for better accuracy

        // Perform recognition
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    AppLogger.transcription.error("Apple Speech recognition failed", error: error)
                    continuation.resume(throwing: AppError.transcriptionServiceFailure(
                        statusCode: nil,
                        reason: error.localizedDescription
                    ))
                    return
                }

                guard let result = result else {
                    continuation.resume(throwing: AppError.transcriptionServiceFailure(
                        statusCode: nil,
                        reason: "No transcription result"
                    ))
                    return
                }

                if result.isFinal {
                    let transcription = result.bestTranscription

                    AppLogger.transcription.info("Apple Speech transcription completed: \(transcription.formattedString.count) characters")

                    let serviceResult = TranscriptionServiceResult(
                        text: transcription.formattedString,
                        confidence: Double(transcription.segments.first?.confidence ?? 0),
                        language: recognizer.locale.languageCode,
                        duration: result.speechRecognitionMetadata?.speechDuration
                    )

                    continuation.resume(returning: serviceResult)
                }
            }
        }
    }

    public func cancelTranscription(for fileURL: URL) async {
        // SFSpeechRecognizer tasks are cancelled via task handle
        AppLogger.transcription.info("Cancellation requested for: \(fileURL.lastPathComponent)")
    }

    // MARK: - Private Helpers

    /// Requests speech recognition authorization.
    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

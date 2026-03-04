//
//  LocalWhisperService.swift
//  TwinMind
//
//  Purpose: Stub implementation for local Whisper GGML model.
//  Design decision: Protocol conformance stub that throws "not implemented".
//  Real GGML binary integration requires ~100MB model file bundled or downloaded.
//

import Foundation

/// Local Whisper service stub for on-device transcription.
///
/// This is a protocol conformance stub. A real implementation would integrate
/// the Whisper GGML model for fully offline transcription. Due to model size
/// (~100-400MB), this is left as a future enhancement.
public struct LocalWhisperService: TranscriptionServiceProtocol {

    // MARK: - Properties

    /// Encryption service for decrypting audio files.
    private let encryptionService: any EncryptionServiceProtocol

    // MARK: - Initialization

    /// Creates a new local Whisper service stub.
    ///
    /// - Parameter encryptionService: Encryption service for audio files.
    public init(encryptionService: any EncryptionServiceProtocol) {
        self.encryptionService = encryptionService
    }

    // MARK: - TranscriptionServiceProtocol

    public var serviceIdentifier: String {
        "local-whisper"
    }

    public var displayName: String {
        "Local Whisper"
    }

    public var requiresNetwork: Bool {
        false
    }

    public func isAvailable() async -> Bool {
        // Stub: Local Whisper model not bundled
        AppLogger.transcription.debug("Local Whisper not available: model not bundled")
        return false
    }

    public func transcribe(
        fileURL: URL,
        language: String?,
        decrypt: Bool
    ) async throws -> TranscriptionServiceResult {
        AppLogger.transcription.warning("Local Whisper transcription requested but not implemented")

        // Stub: Throw not implemented error
        throw AppError.transcriptionServiceFailure(
            statusCode: nil,
            reason: "Local Whisper not implemented. GGML model binary not bundled."
        )

        // STUB: Real implementation would:
        // 1. Decrypt audio file if needed
        // 2. Load GGML model from bundle or cache
        // 3. Convert audio to required format (16kHz PCM)
        // 4. Run inference on the model
        // 5. Return transcribed text with confidence scores
        //
        // Example pseudo-code:
        // let model = try loadGGMLModel()
        // let pcmData = try convertToPCM(audioFileURL)
        // let result = try model.transcribe(pcmData, language: language)
        // return TranscriptionServiceResult(text: result.text, ...)
    }

    public func cancelTranscription(for fileURL: URL) async {
        AppLogger.transcription.info("Local Whisper cancellation requested")
    }
}

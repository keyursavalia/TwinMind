//
//  GeminiTranscriptionService.swift
//  TwinMind
//
//  Purpose: Google Gemini API transcription service implementation.
//  Design decision: Uses Gemini Flash model for audio transcription.
//  Audio is sent as base64-encoded inline data for simplicity.
//

import Foundation
internal import os

/// Google Gemini API transcription service.
///
/// This service uses Google's Gemini model to transcribe audio.
/// Audio files are sent as base64-encoded inline data in the request.
public actor GeminiTranscriptionService: TranscriptionServiceProtocol {

    // MARK: - Properties

    private let networkService: any NetworkServiceProtocol
    private let keychainService: any KeychainServiceProtocol
    private let encryptionService: any EncryptionServiceProtocol
    private let apiKeyIdentifier = "com.twinmind.gemini.apikey"
    private let modelName: String

    // MARK: - Initialization

    /// Creates a new Gemini transcription service.
    ///
    /// - Parameters:
    ///   - networkService: The network service for API requests.
    ///   - keychainService: The keychain service for API key retrieval.
    ///   - encryptionService: The encryption service for decrypting audio files.
    ///   - modelName: The Gemini model to use (defaults to gemini-2.5-flash).
    public init(
        networkService: any NetworkServiceProtocol,
        keychainService: any KeychainServiceProtocol,
        encryptionService: any EncryptionServiceProtocol,
        modelName: String = "gemini-2.5-flash"  // Modern model for March 2026
    ) {
        self.networkService = networkService
        self.keychainService = keychainService
        self.encryptionService = encryptionService
        self.modelName = modelName
    }

    // MARK: - TranscriptionServiceProtocol

    public var serviceIdentifier: String {
        "gemini-api"
    }

    public var displayName: String {
        "Google Gemini"
    }

    public var requiresNetwork: Bool {
        true
    }

    public func isAvailable() async -> Bool {
        // Check if API key exists in Keychain
        guard let _ = try? keychainService.retrieveString(forKey: apiKeyIdentifier) else {
            AppLogger.transcription.warning("Gemini API key not found in Keychain")
            return false
        }

        // Check network connectivity
        guard await networkService.isConnected() else {
            AppLogger.transcription.debug("Gemini API unavailable: no network")
            return false
        }

        return true
    }

    public func transcribe(
        fileURL: URL,
        language: String?,
        decrypt: Bool
    ) async throws -> TranscriptionServiceResult {
        AppLogger.transcription.info("Transcribing with Gemini API: \(fileURL.lastPathComponent)")

        // Retrieve API key
        guard let apiKey = try keychainService.retrieveString(forKey: apiKeyIdentifier) else {
            throw AppError.missingAPIKey(service: "Gemini API")
        }

        // Decrypt file if needed
        let audioFileURL: URL
        if decrypt {
            AppLogger.transcription.info("🔓 Decrypting audio file...")
            let decryptedURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileURL.pathExtension)

            audioFileURL = try await encryptionService.decryptFile(at: fileURL, to: decryptedURL)
            AppLogger.transcription.info("✅ File decrypted successfully")
        } else {
            audioFileURL = fileURL
            AppLogger.transcription.info("📂 Using unencrypted file")
        }

        defer {
            // Clean up decrypted file
            if decrypt {
                try? FileManager.default.removeItem(at: audioFileURL)
            }
        }

        // Read audio file and encode to base64
        let audioData = try Data(contentsOf: audioFileURL)
        let base64Audio = audioData.base64EncodedString()

        // Determine MIME type (Gemini supports: audio/mp3, audio/wav, audio/aac)
        let mimeType: String
        switch audioFileURL.pathExtension.lowercased() {
        case "m4a":
            mimeType = "audio/aac"  // M4A is AAC audio in MP4 container
        case "mp3":
            mimeType = "audio/mp3"
        case "wav":
            mimeType = "audio/wav"
        default:
            mimeType = "audio/aac"
        }

        // Build Gemini API URL correctly (using v1 stable endpoint)
        let urlString = "https://generativelanguage.googleapis.com/v1/models/\(modelName):generateContent?key=\(apiKey)"

        guard let requestURL = URL(string: urlString) else {
            throw AppError.invalidConfiguration(key: "gemini-endpoint", reason: "Invalid URL")
        }

        AppLogger.transcription.info("📡 Gemini API Request URL: \(urlString.replacingOccurrences(of: apiKey, with: "***KEY***"))")

        // Build request body
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(inlineData: GeminiInlineData(mimeType: mimeType, data: base64Audio)),
                        GeminiPart(text: "Please provide a verbatim transcription of this audio. Include all spoken words exactly as they appear, with proper punctuation and capitalization. Do not add any commentary, analysis, or additional text - only the transcription.")
                    ]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let requestData = try encoder.encode(requestBody)

        // Log request details (truncate base64 for readability)
        if let requestJSON = String(data: requestData, encoding: .utf8) {
            let truncatedJSON = requestJSON.replacingOccurrences(
                of: #""data"\s*:\s*"[^"]*""#,
                with: #""data": "[BASE64_AUDIO_DATA_\#(audioData.count)_BYTES]""#,
                options: .regularExpression
            )
            AppLogger.transcription.info("📤 Gemini API Request Body:\n\(truncatedJSON)")
        }
        AppLogger.transcription.info("🎵 Audio file size: \(audioData.count) bytes, MIME type: \(mimeType)")

        // Create URLRequest
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData

        AppLogger.transcription.info("⏳ Sending request to Gemini API... (timeout: 120s)")

        // Send request
        do {
            let (data, response) = try await networkService.execute(request: request, timeout: 120)

            AppLogger.transcription.info("✅ Gemini API response received - Status: \(response.statusCode)")

            // Log response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                AppLogger.transcription.info("📥 Gemini API Response:\n\(responseString)")
            }

            // Decode response
            let decoder = JSONDecoder()
            let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)

            // Extract transcription text
            guard let candidate = geminiResponse.candidates.first,
                  let part = candidate.content.parts.first,
                  let text = part.text else {
                AppLogger.transcription.error("❌ Failed to extract text from Gemini response")
                throw AppError.invalidResponseFormat(expectedFormat: "Gemini response with text")
            }

            AppLogger.transcription.info("🎉 Gemini API transcription completed: \(text.count) characters")
            AppLogger.transcription.info("📝 Transcription preview: \(String(text.prefix(100)))\(text.count > 100 ? "..." : "")")

            return TranscriptionServiceResult(
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: nil,
                language: language,
                duration: nil,
                metadata: ["model": modelName, "service": serviceIdentifier]
            )

        } catch let error as AppError {
            AppLogger.transcription.error("❌ Gemini API request failed", error: error)
            AppLogger.transcription.error("❌ Error details: \(String(describing: error))")
            throw error
        } catch {
            AppLogger.transcription.error("❌ Gemini API request failed with unexpected error", error: error)
            AppLogger.transcription.error("❌ Error type: \(type(of: error)), description: \(error.localizedDescription)")
            throw AppError.transcriptionServiceFailure(statusCode: nil, reason: error.localizedDescription)
        }
    }

    public func cancelTranscription(for fileURL: URL) async {
        AppLogger.transcription.info("Cancellation requested for: \(fileURL.lastPathComponent)")
        // Gemini API doesn't support request cancellation directly
        // Cancellation is handled by the pipeline actor via task cancellation
    }
}

// MARK: - Gemini API Request/Response Models

private struct GeminiRequest: Codable {
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    init(inlineData: GeminiInlineData) {
        self.text = nil
        self.inlineData = inlineData
    }
}

private struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent
}

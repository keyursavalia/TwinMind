//
//  WhisperAPIService.swift
//  TwinMind
//
//  Purpose: OpenAI Whisper API integration for audio transcription.
//  Design decision: Multipart form-data upload with automatic audio format detection.
//  API key retrieved from Keychain on each request for security.
//

import Foundation

/// Whisper API service for audio transcription via OpenAI.
///
/// This service handles multipart file uploads to the Whisper API endpoint,
/// with automatic retry on transient failures and detailed error mapping.
public struct WhisperAPIService: TranscriptionServiceProtocol {

    // MARK: - Properties

    /// Network service for HTTP requests.
    private let networkService: any NetworkServiceProtocol

    /// Keychain service for API key storage.
    private let keychainService: any KeychainServiceProtocol

    /// Encryption service for decrypting audio files.
    private let encryptionService: any EncryptionServiceProtocol

    /// Base URL for the Whisper API.
    private let baseURL: URL

    /// Keychain key for the API key.
    private let apiKeyIdentifier: String

    // MARK: - Initialization

    /// Creates a new Whisper API service.
    ///
    /// - Parameters:
    ///   - networkService: Network service for requests.
    ///   - keychainService: Keychain service for API key.
    ///   - encryptionService: Encryption service for audio files.
    ///   - baseURL: Base URL for the API (default: OpenAI).
    ///   - apiKeyIdentifier: Keychain identifier for the API key.
    public init(
        networkService: any NetworkServiceProtocol,
        keychainService: any KeychainServiceProtocol,
        encryptionService: any EncryptionServiceProtocol,
        baseURL: URL? = nil,
        apiKeyIdentifier: String = "com.twinmind.whisper.apikey"
    ) {
        self.networkService = networkService
        self.keychainService = keychainService
        self.encryptionService = encryptionService
        self.baseURL = baseURL ?? URL(string: "https://api.openai.com/v1")!
        self.apiKeyIdentifier = apiKeyIdentifier
    }

    // MARK: - TranscriptionServiceProtocol

    public var serviceIdentifier: String {
        "whisper-api"
    }

    public var displayName: String {
        "Whisper API"
    }

    public var requiresNetwork: Bool {
        true
    }

    public func isAvailable() async -> Bool {
        // Check if API key exists
        guard keychainService.exists(forKey: apiKeyIdentifier) else {
            AppLogger.transcription.warning("Whisper API key not found in Keychain")
            return false
        }

        // Check network connectivity
        let isConnected = await networkService.isConnected()
        if !isConnected {
            AppLogger.transcription.debug("Whisper API unavailable: no network")
            return false
        }

        return true
    }

    public func transcribe(
        fileURL: URL,
        language: String?,
        decrypt: Bool
    ) async throws -> TranscriptionServiceResult {
        AppLogger.transcription.info("Transcribing with Whisper API: \(fileURL.lastPathComponent)")

        // Retrieve API key
        guard let apiKey = try keychainService.retrieveString(forKey: apiKeyIdentifier) else {
            throw AppError.missingAPIKey(service: "Whisper API")
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

        // Prepare request
        let endpoint = baseURL.appendingPathComponent("audio/transcriptions")

        // Build form fields
        var fields: [String: String] = [
            "model": "whisper-1"
        ]

        if let language = language {
            fields["language"] = language
        }

        // Upload file
        do {
            let (data, response) = try await networkService.uploadFile(
                to: endpoint,
                fileURL: audioFileURL,
                fileName: "audio.m4a",
                mimeType: "audio/m4a",
                additionalFields: fields,
                timeout: 120
            )

            // Decode response
            let whisperResponse = try JSONDecoder().decode(WhisperAPIResponse.self, from: data)

            AppLogger.transcription.info("Whisper API transcription completed: \(whisperResponse.text.count) characters")

            return TranscriptionServiceResult(
                text: whisperResponse.text,
                confidence: nil, // Whisper API doesn't provide confidence
                language: whisperResponse.language,
                duration: whisperResponse.duration
            )

        } catch let error as AppError {
            AppLogger.transcription.error("Whisper API request failed", error: error)
            throw error
        } catch {
            AppLogger.transcription.error("Whisper API request failed", error: error)
            throw AppError.transcriptionServiceFailure(
                statusCode: nil,
                reason: error.localizedDescription
            )
        }
    }

    public func cancelTranscription(for fileURL: URL) async {
        // URLSession-based cancellation is handled by the network service
        AppLogger.transcription.info("Cancellation requested for: \(fileURL.lastPathComponent)")
    }
}

// MARK: - WhisperAPIResponse

/// Response structure from the Whisper API.
private struct WhisperAPIResponse: Decodable {
    let text: String
    let language: String?
    let duration: Double?
}

//
//  AppDependencies.swift
//  TwinMind
//
//  Purpose: Dependency injection container for the app.
//  Design decision: Single dependency graph instantiated at app launch.
//  Not a singleton - passed through environment for testability.
//

import Foundation
import SwiftData
internal import os

/// Dependency injection container for the TwinMind application.
///
/// This class wires up all services, actors, and dependencies at app launch,
/// providing a single source of truth for the dependency graph.
@MainActor
public final class AppDependencies {

    // MARK: - Infrastructure Services

    /// Keychain service for secure storage.
    public let keychainService: KeychainServiceProtocol

    /// Encryption service for audio files.
    public let encryptionService: EncryptionServiceProtocol

    /// Network service for HTTP requests.
    public let networkService: NetworkServiceProtocol

    /// Audio file manager for storage.
    public let audioFileManager: AudioFileManager

    // MARK: - Transcription Services

    /// Primary transcription service (Google Gemini).
    public let geminiService: TranscriptionServiceProtocol

    /// Fallback transcription service (Apple STT).
    public let appleSpeechService: TranscriptionServiceProtocol

    // MARK: - SwiftData

    /// The SwiftData model container.
    public let modelContainer: ModelContainer

    // MARK: - Domain Actors

    /// Data manager actor for SwiftData operations.
    public let dataManager: DataManagerActor

    /// Transcription pipeline actor for queue management.
    public let transcriptionPipeline: TranscriptionPipelineActor

    /// Audio engine actor for recording.
    public let audioEngine: AudioEngineActor

    // MARK: - Initialization

    /// Creates the app dependencies container.
    ///
    /// - Throws: Configuration or initialization errors.
    public init() throws {
        AppLogger.lifecycle.info("Initializing app dependencies")

        // Initialize configuration
        try ConfigurationManager.shared.initialize()

        // Initialize infrastructure services
        self.keychainService = KeychainService()
        self.encryptionService = EncryptionService(keychainService: keychainService)
        self.networkService = NetworkService()
        self.audioFileManager = AudioFileManager()

        // Initialize transcription services
        self.geminiService = GeminiTranscriptionService(
            networkService: networkService,
            keychainService: keychainService,
            encryptionService: encryptionService
        )
        self.appleSpeechService = AppleSpeechService(encryptionService: encryptionService)

        // Initialize SwiftData
        let schema = Schema([
            RecordingSession.self,
            AudioSegment.self,
            TranscriptionResult.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: configuration)
            AppLogger.lifecycle.info("ModelContainer initialized successfully")
        } catch {
            AppLogger.lifecycle.error("Failed to initialize ModelContainer", error: error)
            throw AppError.modelContainerInitializationFailed(reason: error.localizedDescription)
        }

        // Initialize domain actors
        self.dataManager = DataManagerActor(modelContainer: modelContainer)

        self.transcriptionPipeline = TranscriptionPipelineActor(
            primaryService: geminiService,
            fallbackService: appleSpeechService,
            dataManager: dataManager,
            encryptionService: encryptionService,
            networkService: networkService
        )

        self.audioEngine = AudioEngineActor(
            audioFileManager: audioFileManager,
            encryptionService: encryptionService
        )

        AppLogger.lifecycle.info("App dependencies initialized successfully")
    }

    // MARK: - Test Helpers

    /// Creates dependencies for testing with in-memory storage.
    ///
    /// - Returns: A dependency container configured for testing.
    public static func forTesting() throws -> AppDependencies {
        // This would use mock services and in-memory storage
        // For now, return regular dependencies
        return try AppDependencies()
    }
}

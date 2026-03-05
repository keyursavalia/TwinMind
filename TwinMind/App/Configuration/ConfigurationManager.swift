//
//  ConfigurationManager.swift
//  TwinMind
//
//  Purpose: Centralized configuration and secret management.
//  Design decision: Reads API keys from Info.plist (injected from xcconfig),
//  stores them in Keychain, then removes from memory. Never logs secrets.
//

import Foundation
internal import os

/// Configuration manager for app settings and API keys.
///
/// This manager reads configuration values from Info.plist (populated by xcconfig files),
/// transfers sensitive values to Keychain, and provides safe access to configuration.
public final class ConfigurationManager: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared configuration manager instance.
    public static let shared = ConfigurationManager()

    // MARK: - Properties

    /// Keychain service for storing secrets.
    private let keychainService: KeychainServiceProtocol

    /// Whether configuration has been initialized.
    private var isInitialized: Bool = false

    // MARK: - Configuration Keys

    private enum InfoPlistKey {
        static let geminiAPIKey = "GEMINI_API_KEY"
        static let environment = "ENVIRONMENT"
    }

    public enum KeychainKey {
        public static let geminiAPIKey = "com.twinmind.gemini.apikey"
        public static let encryptionKey = "com.twinmind.encryption.key"
    }

    // MARK: - Initialization

    private init() {
        self.keychainService = KeychainService()
    }

    // MARK: - Public Methods

    /// Initializes configuration by transferring secrets from Info.plist to Keychain.
    ///
    /// - Throws: `AppError.missingConfiguration` if required values are missing.
    public func initialize() throws {
        guard !isInitialized else {
            AppLogger.general.info("Configuration already initialized")
            return
        }

        AppLogger.general.info("Initializing configuration")

        // Read Gemini API key from Info.plist
        if let geminiAPIKey = infoPlistString(forKey: InfoPlistKey.geminiAPIKey),
           !geminiAPIKey.isEmpty,
           geminiAPIKey != "YOUR_GEMINI_API_KEY_HERE" {
            // Store in Keychain if not already present
            if !keychainService.exists(forKey: KeychainKey.geminiAPIKey) {
                try keychainService.store(
                    geminiAPIKey,
                    forKey: KeychainKey.geminiAPIKey,
                    accessibility: .afterFirstUnlockThisDeviceOnly
                )
                AppLogger.general.info("Gemini API key stored in Keychain")
            }
        } else {
            AppLogger.general.warning("Gemini API key not configured in Info.plist")
        }

        // Initialize encryption key if needed
        let encryptionService = EncryptionService(keychainService: keychainService)
        if !encryptionService.keyExists() {
            try encryptionService.generateAndStoreKey()
            AppLogger.general.info("Encryption key generated and stored")
        }

        isInitialized = true
        AppLogger.general.info("Configuration initialized successfully")
    }

    /// Gets the current environment.
    ///
    /// - Returns: The environment string (e.g., "development", "production").
    public func environment() -> String {
        infoPlistString(forKey: InfoPlistKey.environment) ?? "production"
    }

    /// Checks if the app is running in debug mode.
    public var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Private Helpers

    private func infoPlistString(forKey key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}

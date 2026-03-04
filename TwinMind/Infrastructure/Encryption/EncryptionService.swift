//
//  EncryptionService.swift
//  TwinMind
//
//  Purpose: Concrete implementation of EncryptionServiceProtocol using CryptoKit.
//  Design decision: AES-256-GCM provides authenticated encryption, ensuring both
//  confidentiality and integrity. The encryption key is stored in Keychain.
//
//  Created by Claude Code on 2026-03-04.
//

import Foundation
import CryptoKit

/// Concrete implementation of file encryption operations using AES-256-GCM.
///
/// This service handles encryption and decryption of audio files at rest,
/// with the encryption key securely stored in the Keychain.
public struct EncryptionService: EncryptionServiceProtocol {

    // MARK: - Properties

    /// The Keychain service for key storage.
    private let keychainService: KeychainServiceProtocol

    /// The Keychain key identifier for the encryption key.
    private let encryptionKeyIdentifier: String

    // MARK: - Initialization

    /// Creates a new encryption service instance.
    ///
    /// - Parameters:
    ///   - keychainService: The Keychain service to use for key storage.
    ///   - keyIdentifier: The identifier for the encryption key in Keychain.
    public init(
        keychainService: KeychainServiceProtocol,
        keyIdentifier: String = "com.twinmind.encryption.key"
    ) {
        self.keychainService = keychainService
        self.encryptionKeyIdentifier = keyIdentifier
    }

    // MARK: - File Encryption

    public func encryptFile(at fileURL: URL) async throws -> URL {
        // Read file data
        let data = try Data(contentsOf: fileURL)

        // Encrypt data
        let encryptedData = try encrypt(data: data)

        // Write encrypted data back to the same location
        try encryptedData.write(to: fileURL, options: .atomic)

        return fileURL
    }

    public func encryptFile(at sourceURL: URL, to destinationURL: URL) async throws -> URL {
        // Read file data
        let data = try Data(contentsOf: sourceURL)

        // Encrypt data
        let encryptedData = try encrypt(data: data)

        // Write encrypted data to destination
        try encryptedData.write(to: destinationURL, options: .atomic)

        return destinationURL
    }

    // MARK: - File Decryption

    public func decryptFile(at fileURL: URL) async throws -> URL {
        // Read encrypted file data
        let encryptedData = try Data(contentsOf: fileURL)

        // Decrypt data
        let decryptedData = try decrypt(data: encryptedData)

        // Write decrypted data back to the same location
        try decryptedData.write(to: fileURL, options: .atomic)

        return fileURL
    }

    public func decryptFile(at sourceURL: URL, to destinationURL: URL) async throws -> URL {
        // Read encrypted file data
        let encryptedData = try Data(contentsOf: sourceURL)

        // Decrypt data
        let decryptedData = try decrypt(data: encryptedData)

        // Write decrypted data to destination
        try decryptedData.write(to: destinationURL, options: .atomic)

        return destinationURL
    }

    // MARK: - Data Encryption

    public func encrypt(data: Data) throws -> Data {
        // Retrieve encryption key
        let key = try getSymmetricKey()

        do {
            // Encrypt using AES-256-GCM
            let sealedBox = try AES.GCM.seal(data, using: key)

            // Return combined data (nonce + ciphertext + tag)
            guard let combined = sealedBox.combined else {
                throw AppError.encryptionOperationFailed(
                    operation: "encrypt",
                    reason: "Failed to create combined representation"
                )
            }

            return combined

        } catch {
            throw AppError.encryptionOperationFailed(
                operation: "encrypt",
                reason: error.localizedDescription
            )
        }
    }

    public func decrypt(data encryptedData: Data) throws -> Data {
        // Retrieve encryption key
        let key = try getSymmetricKey()

        do {
            // Create sealed box from combined data
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)

            // Decrypt using AES-256-GCM
            let decryptedData = try AES.GCM.open(sealedBox, using: key)

            return decryptedData

        } catch {
            throw AppError.encryptionOperationFailed(
                operation: "decrypt",
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Key Management

    public func generateAndStoreKey() throws {
        // Generate a new 256-bit symmetric key
        let key = SymmetricKey(size: .bits256)

        // Convert to Data
        let keyData = key.withUnsafeBytes { Data($0) }

        // Store in Keychain with highest security level
        try keychainService.store(
            keyData,
            forKey: encryptionKeyIdentifier,
            accessibility: .afterFirstUnlockThisDeviceOnly
        )
    }

    public func retrieveKey() throws -> Data {
        guard let keyData = try keychainService.retrieveData(forKey: encryptionKeyIdentifier) else {
            throw AppError.encryptionKeyNotFound
        }

        // Validate key size (must be 256 bits = 32 bytes)
        guard keyData.count == 32 else {
            throw AppError.invalidEncryptionKey
        }

        return keyData
    }

    public func keyExists() -> Bool {
        return keychainService.exists(forKey: encryptionKeyIdentifier)
    }

    public func deleteKey() throws {
        try keychainService.delete(forKey: encryptionKeyIdentifier)
    }

    // MARK: - Private Helpers

    /// Retrieves the encryption key as a SymmetricKey, generating one if needed.
    private func getSymmetricKey() throws -> SymmetricKey {
        // Generate key if it doesn't exist
        if !keyExists() {
            try generateAndStoreKey()
        }

        // Retrieve key data
        let keyData = try retrieveKey()

        // Create SymmetricKey from data
        return SymmetricKey(data: keyData)
    }
}

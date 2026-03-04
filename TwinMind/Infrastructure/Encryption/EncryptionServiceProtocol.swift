//
//  EncryptionServiceProtocol.swift
//  TwinMind
//
//  Purpose: Protocol defining the contract for file encryption operations.
//  Design decision: AES-256-GCM encryption at rest for all audio files,
//  with keys stored in Keychain for maximum security.
//

import Foundation

/// Protocol defining the interface for file encryption and decryption.
///
/// Conforming types handle AES-256-GCM encryption of audio files at rest,
/// ensuring sensitive audio data is never stored in plaintext.
public protocol EncryptionServiceProtocol: Sendable {

    // MARK: - File Encryption

    /// Encrypts a file in place using AES-256-GCM.
    ///
    /// The original file is replaced with the encrypted version.
    ///
    /// - Parameter fileURL: URL to the file to encrypt.
    /// - Returns: URL to the encrypted file (same as input).
    /// - Throws: `AppError.encryptionOperationFailed` if encryption fails.
    func encryptFile(at fileURL: URL) async throws -> URL

    /// Encrypts a file and saves the result to a new location.
    ///
    /// The original file is preserved.
    ///
    /// - Parameters:
    ///   - sourceURL: URL to the file to encrypt.
    ///   - destinationURL: URL where the encrypted file will be saved.
    /// - Returns: URL to the encrypted file (same as destinationURL).
    /// - Throws: `AppError.encryptionOperationFailed` if encryption fails.
    func encryptFile(at sourceURL: URL, to destinationURL: URL) async throws -> URL

    // MARK: - File Decryption

    /// Decrypts a file in place using AES-256-GCM.
    ///
    /// The encrypted file is replaced with the decrypted version.
    ///
    /// - Parameter fileURL: URL to the encrypted file.
    /// - Returns: URL to the decrypted file (same as input).
    /// - Throws: `AppError.encryptionOperationFailed` if decryption fails.
    func decryptFile(at fileURL: URL) async throws -> URL

    /// Decrypts a file and saves the result to a new location.
    ///
    /// The encrypted file is preserved.
    ///
    /// - Parameters:
    ///   - sourceURL: URL to the encrypted file.
    ///   - destinationURL: URL where the decrypted file will be saved.
    /// - Returns: URL to the decrypted file (same as destinationURL).
    /// - Throws: `AppError.encryptionOperationFailed` if decryption fails.
    func decryptFile(at sourceURL: URL, to destinationURL: URL) async throws -> URL

    // MARK: - Data Encryption

    /// Encrypts raw data using AES-256-GCM.
    ///
    /// - Parameter data: The data to encrypt.
    /// - Returns: Encrypted data.
    /// - Throws: `AppError.encryptionOperationFailed` if encryption fails.
    func encrypt(data: Data) throws -> Data

    /// Decrypts encrypted data using AES-256-GCM.
    ///
    /// - Parameter encryptedData: The encrypted data.
    /// - Returns: Decrypted data.
    /// - Throws: `AppError.encryptionOperationFailed` if decryption fails.
    func decrypt(data encryptedData: Data) throws -> Data

    // MARK: - Key Management

    /// Generates a new encryption key and stores it in the Keychain.
    ///
    /// - Throws: `AppError.encryptionOperationFailed` if key generation fails.
    func generateAndStoreKey() throws

    /// Retrieves the current encryption key from the Keychain.
    ///
    /// - Returns: The encryption key data.
    /// - Throws: `AppError.encryptionKeyNotFound` if key is not found.
    func retrieveKey() throws -> Data

    /// Checks whether an encryption key exists in the Keychain.
    ///
    /// - Returns: `true` if a key exists, `false` otherwise.
    func keyExists() -> Bool

    /// Deletes the encryption key from the Keychain.
    ///
    /// - Throws: `AppError.keychainOperationFailed` if deletion fails.
    func deleteKey() throws
}

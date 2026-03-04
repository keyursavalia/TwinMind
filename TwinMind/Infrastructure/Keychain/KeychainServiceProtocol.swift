//
//  KeychainServiceProtocol.swift
//  TwinMind
//
//  Purpose: Protocol defining the contract for Keychain operations.
//  Design decision: Abstract Keychain API behind a protocol for testability
//  and to enforce consistent access patterns across the app.
//

import Foundation

/// Protocol defining the interface for Keychain storage operations.
///
/// Conforming types handle secure storage and retrieval of sensitive data
/// such as API keys, encryption keys, and authentication tokens.
public protocol KeychainServiceProtocol: Sendable {

    // MARK: - Storage Operations

    /// Stores a string value in the Keychain.
    ///
    /// - Parameters:
    ///   - value: The string to store.
    ///   - key: The identifier for the stored value.
    ///   - accessibility: Keychain accessibility level.
    /// - Throws: `AppError.keychainOperationFailed` if storage fails.
    func store(
        _ value: String,
        forKey key: String,
        accessibility: KeychainAccessibility
    ) throws

    /// Stores binary data in the Keychain.
    ///
    /// - Parameters:
    ///   - data: The data to store.
    ///   - key: The identifier for the stored data.
    ///   - accessibility: Keychain accessibility level.
    /// - Throws: `AppError.keychainOperationFailed` if storage fails.
    func store(
        _ data: Data,
        forKey key: String,
        accessibility: KeychainAccessibility
    ) throws

    // MARK: - Retrieval Operations

    /// Retrieves a string value from the Keychain.
    ///
    /// - Parameter key: The identifier for the value.
    /// - Returns: The stored string, or `nil` if not found.
    /// - Throws: `AppError.keychainOperationFailed` if retrieval fails.
    func retrieveString(forKey key: String) throws -> String?

    /// Retrieves binary data from the Keychain.
    ///
    /// - Parameter key: The identifier for the data.
    /// - Returns: The stored data, or `nil` if not found.
    /// - Throws: `AppError.keychainOperationFailed` if retrieval fails.
    func retrieveData(forKey key: String) throws -> Data?

    // MARK: - Deletion Operations

    /// Deletes a value from the Keychain.
    ///
    /// - Parameter key: The identifier for the value to delete.
    /// - Throws: `AppError.keychainOperationFailed` if deletion fails.
    func delete(forKey key: String) throws

    /// Deletes all values stored by this app from the Keychain.
    ///
    /// - Throws: `AppError.keychainOperationFailed` if deletion fails.
    func deleteAll() throws

    // MARK: - Query Operations

    /// Checks whether a value exists in the Keychain.
    ///
    /// - Parameter key: The identifier to check.
    /// - Returns: `true` if the key exists, `false` otherwise.
    func exists(forKey key: String) -> Bool
}

// MARK: - KeychainAccessibility

/// Keychain accessibility levels.
///
/// Maps to `kSecAttrAccessible` values for controlling when stored items are accessible.
public enum KeychainAccessibility: String, Sendable {

    /// Data is accessible after the first unlock (recommended for background tasks).
    case afterFirstUnlockThisDeviceOnly

    /// Data is accessible only when the device is unlocked (most secure).
    case whenUnlockedThisDeviceOnly

    /// Data is accessible after the first unlock, syncs via iCloud Keychain.
    case afterFirstUnlock

    /// Data is accessible only when unlocked, syncs via iCloud Keychain.
    case whenUnlocked

    /// Data is always accessible (least secure, avoid if possible).
    case always

    /// Data is always accessible, this device only (least secure, avoid if possible).
    case alwaysThisDeviceOnly
}

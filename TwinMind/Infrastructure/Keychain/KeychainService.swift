//
//  KeychainService.swift
//  TwinMind
//
//  Purpose: Concrete implementation of KeychainServiceProtocol using Security framework.
//  Design decision: All Keychain queries use kSecAttrService to scope items to this app,
//  preventing conflicts with other apps and enabling easy cleanup.
//

import Foundation
import Security

/// Concrete implementation of Keychain storage operations.
///
/// This service wraps the Security framework's Keychain API with a type-safe,
/// error-handling interface. All stored items are scoped to the app's bundle identifier.
public struct KeychainService: KeychainServiceProtocol {

    // MARK: - Properties

    /// The service identifier used for all Keychain items (typically bundle ID).
    private let serviceIdentifier: String

    // MARK: - Initialization

    /// Creates a new Keychain service instance.
    ///
    /// - Parameter serviceIdentifier: The service identifier for Keychain items.
    ///   Defaults to the app's bundle identifier.
    public init(serviceIdentifier: String? = nil) {
        self.serviceIdentifier = serviceIdentifier ?? Bundle.main.bundleIdentifier ?? "com.twinmind.app"
    }

    // MARK: - Storage Operations

    public func store(
        _ value: String,
        forKey key: String,
        accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly
    ) throws {
        guard let data = value.data(using: .utf8) else {
            throw AppError.keychainOperationFailed(operation: "store", status: errSecParam)
        }
        try store(data, forKey: key, accessibility: accessibility)
    }

    public func store(
        _ data: Data,
        forKey key: String,
        accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly
    ) throws {
        // Delete existing item if present
        _ = try? delete(forKey: key)

        // Build query dictionary
        var query = baseQuery(forKey: key)
        query[kSecValueData] = data
        query[kSecAttrAccessible] = accessibilityAttribute(for: accessibility)

        // Add to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw AppError.keychainOperationFailed(operation: "store", status: status)
        }
    }

    // MARK: - Retrieval Operations

    public func retrieveString(forKey key: String) throws -> String? {
        guard let data = try retrieveData(forKey: key) else {
            return nil
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw AppError.keychainOperationFailed(operation: "retrieveString", status: errSecDecode)
        }

        return string
    }

    public func retrieveData(forKey key: String) throws -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw AppError.keychainOperationFailed(operation: "retrieveData", status: errSecDecode)
            }
            return data

        case errSecItemNotFound:
            return nil

        default:
            throw AppError.keychainOperationFailed(operation: "retrieveData", status: status)
        }
    }

    // MARK: - Deletion Operations

    public func delete(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is not an error for deletion
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.keychainOperationFailed(operation: "delete", status: status)
        }
    }

    public func deleteAll() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceIdentifier
        ]

        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is not an error (nothing to delete)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.keychainOperationFailed(operation: "deleteAll", status: status)
        }
    }

    // MARK: - Query Operations

    public func exists(forKey key: String) -> Bool {
        var query = baseQuery(forKey: key)
        query[kSecReturnData] = false

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Private Helpers

    /// Creates a base query dictionary for a given key.
    private func baseQuery(forKey key: String) -> [CFString: Any] {
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceIdentifier,
            kSecAttrAccount: key
        ]
    }

    /// Maps KeychainAccessibility to kSecAttrAccessible values.
    private func accessibilityAttribute(for accessibility: KeychainAccessibility) -> CFString {
        switch accessibility {
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case .always:
            return kSecAttrAccessibleAlways
        case .alwaysThisDeviceOnly:
            return kSecAttrAccessibleAlwaysThisDeviceOnly
        }
    }
}

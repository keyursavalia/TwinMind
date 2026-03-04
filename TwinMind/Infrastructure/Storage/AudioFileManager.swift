//
//  AudioFileManager.swift
//  TwinMind
//
//  Purpose: Utility for managing audio file storage locations and cleanup.
//  Design decision: Centralized file path management ensures consistent storage
//  structure and simplifies cleanup operations.
//

import Foundation

/// Utility for managing audio file storage and organization.
///
/// This service handles file path generation, directory creation,
/// and cleanup operations for audio segments and merged recordings.
public struct AudioFileManager: Sendable {

    // MARK: - Properties

    /// The base directory for all audio storage.
    public let baseDirectory: URL

    /// The file manager instance.
    private let fileManager: FileManager

    // MARK: - Initialization

    /// Creates a new audio file manager.
    ///
    /// - Parameter baseDirectory: The base directory for audio storage.
    ///   Defaults to the app's documents directory under "Audio".
    public init(baseDirectory: URL? = nil) {
        self.fileManager = FileManager.default

        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            self.baseDirectory = documentsURL?.appendingPathComponent("Audio", isDirectory: true)
                ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Audio", isDirectory: true)
        }

        // Create base directory if needed
        try? createDirectoryIfNeeded(at: self.baseDirectory)
    }

    // MARK: - Directory Management

    /// Creates the base audio directory if it doesn't exist.
    public func createBaseDirectoryIfNeeded() throws {
        try createDirectoryIfNeeded(at: baseDirectory)
    }

    /// Creates a directory for a specific session.
    ///
    /// - Parameter sessionId: The session UUID.
    /// - Returns: URL to the session directory.
    /// - Throws: `AppError.dataOperationFailed` if directory creation fails.
    public func createSessionDirectory(sessionId: UUID) throws -> URL {
        let sessionDir = baseDirectory.appendingPathComponent(sessionId.uuidString, isDirectory: true)
        try createDirectoryIfNeeded(at: sessionDir)
        return sessionDir
    }

    // MARK: - File Path Generation

    /// Generates a file path for an audio segment.
    ///
    /// - Parameters:
    ///   - sessionId: The parent session UUID.
    ///   - segmentIndex: The segment index.
    ///   - fileExtension: File extension (default: "m4a").
    /// - Returns: URL to the segment file.
    public func segmentFilePath(
        sessionId: UUID,
        segmentIndex: Int,
        fileExtension: String = "m4a"
    ) -> URL {
        let sessionDir = baseDirectory.appendingPathComponent(sessionId.uuidString, isDirectory: true)
        let fileName = String(format: "segment_%04d.%@", segmentIndex, fileExtension)
        return sessionDir.appendingPathComponent(fileName)
    }

    /// Generates a file path for a merged session audio file.
    ///
    /// - Parameters:
    ///   - sessionId: The session UUID.
    ///   - fileExtension: File extension (default: "m4a").
    /// - Returns: URL to the merged file.
    public func mergedFilePath(
        sessionId: UUID,
        fileExtension: String = "m4a"
    ) -> URL {
        let sessionDir = baseDirectory.appendingPathComponent(sessionId.uuidString, isDirectory: true)
        return sessionDir.appendingPathComponent("merged.\(fileExtension)")
    }

    /// Generates a temporary file path for processing.
    ///
    /// - Parameter fileExtension: File extension (default: "m4a").
    /// - Returns: URL to a temporary file.
    public func temporaryFilePath(fileExtension: String = "m4a") -> URL {
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    }

    // MARK: - File Operations

    /// Deletes a file at the given URL.
    ///
    /// - Parameter fileURL: URL to the file to delete.
    /// - Throws: `AppError.fileDeletionFailed` if deletion fails.
    public func deleteFile(at fileURL: URL) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return // File doesn't exist, no error
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw AppError.fileDeletionFailed(
                path: fileURL.path,
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes all files for a session.
    ///
    /// - Parameter sessionId: The session UUID.
    /// - Throws: `AppError.fileDeletionFailed` if deletion fails.
    public func deleteSessionFiles(sessionId: UUID) throws {
        let sessionDir = baseDirectory.appendingPathComponent(sessionId.uuidString, isDirectory: true)

        guard fileManager.fileExists(atPath: sessionDir.path) else {
            return // Directory doesn't exist, no error
        }

        do {
            try fileManager.removeItem(at: sessionDir)
        } catch {
            throw AppError.fileDeletionFailed(
                path: sessionDir.path,
                reason: error.localizedDescription
            )
        }
    }

    /// Checks if a file exists at the given URL.
    ///
    /// - Parameter fileURL: URL to check.
    /// - Returns: `true` if the file exists, `false` otherwise.
    public func fileExists(at fileURL: URL) -> Bool {
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Gets the size of a file in bytes.
    ///
    /// - Parameter fileURL: URL to the file.
    /// - Returns: File size in bytes, or `nil` if the file doesn't exist.
    public func fileSize(at fileURL: URL) -> Int64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }

    /// Calculates total storage used by all audio files.
    ///
    /// - Returns: Total size in bytes.
    public func totalStorageUsed() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    /// Gets available storage space on the device.
    ///
    /// - Returns: Available space in bytes.
    /// - Throws: `AppError.dataOperationFailed` if query fails.
    public func availableStorageSpace() throws -> Int64 {
        let systemAttributes = try fileManager.attributesOfFileSystem(forPath: baseDirectory.path)

        guard let freeSpace = systemAttributes[.systemFreeSize] as? Int64 else {
            throw AppError.dataOperationFailed(
                operation: "availableStorageSpace",
                reason: "Unable to determine free space"
            )
        }

        return freeSpace
    }

    /// Checks if there's enough storage space for a given size.
    ///
    /// - Parameter requiredBytes: Required space in bytes.
    /// - Returns: `true` if sufficient space is available.
    /// - Throws: `AppError.insufficientStorage` if not enough space.
    public func checkStorageAvailability(requiredBytes: Int64) throws {
        let availableBytes = try availableStorageSpace()

        guard availableBytes >= requiredBytes else {
            throw AppError.insufficientStorage(
                requiredBytes: requiredBytes,
                availableBytes: availableBytes
            )
        }
    }

    // MARK: - Private Helpers

    /// Creates a directory if it doesn't already exist.
    private func createDirectoryIfNeeded(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else {
            return
        }

        do {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw AppError.dataOperationFailed(
                operation: "createDirectory",
                reason: error.localizedDescription
            )
        }
    }
}

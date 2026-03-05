//
//  NetworkServiceProtocol.swift
//  TwinMind
//
//  Purpose: Protocol defining the contract for HTTP network operations.
//  Design decision: Wraps URLSession behind a protocol for testability,
//  centralized error handling, and request/response logging.
//

import Foundation

/// Protocol defining the interface for HTTP network operations.
///
/// Conforming types handle all network requests, response parsing,
/// and error mapping to typed `AppError` cases.
public protocol NetworkServiceProtocol: Sendable {

    // MARK: - Request Execution

    /// Executes an HTTP request.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to execute.
    ///   - timeout: Request timeout in seconds (default: 30).
    /// - Returns: The response data and HTTP response.
    /// - Throws: `AppError.networkRequestFailed` or `AppError.networkTimeout` on failure.
    func execute(request: URLRequest, timeout: TimeInterval) async throws -> (Data, HTTPURLResponse)

    /// Executes an HTTP request and decodes the JSON response.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to execute.
    ///   - type: The Decodable type to decode the response into.
    ///   - timeout: Request timeout in seconds (default: 30).
    /// - Returns: The decoded response object.
    /// - Throws: `AppError.networkRequestFailed` or `AppError.invalidResponseFormat` on failure.
    func execute<T: Decodable>(
        request: URLRequest,
        decodingTo type: T.Type,
        timeout: TimeInterval
    ) async throws -> T

    /// Uploads a file via multipart/form-data.
    ///
    /// - Parameters:
    ///   - url: The endpoint URL.
    ///   - fileURL: URL to the file to upload.
    ///   - fileName: Name for the file field.
    ///   - mimeType: MIME type of the file.
    ///   - additionalFields: Additional form fields to include.
    ///   - headers: Additional HTTP headers (e.g., Authorization).
    ///   - timeout: Request timeout in seconds (default: 60).
    /// - Returns: The response data and HTTP response.
    /// - Throws: `AppError.networkRequestFailed` on failure.
    func uploadFile(
        to url: URL,
        fileURL: URL,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String],
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> (Data, HTTPURLResponse)

    // MARK: - Connectivity

    /// Checks whether an internet connection is available.
    ///
    /// - Returns: `true` if connected, `false` otherwise.
    func isConnected() async -> Bool

    /// Starts monitoring network connectivity.
    ///
    /// - Returns: An async stream of connectivity status changes.
    func startMonitoring() -> AsyncStream<Bool>

    /// Stops monitoring network connectivity.
    func stopMonitoring()
}

// MARK: - Default Parameters

extension NetworkServiceProtocol {

    /// Executes an HTTP request with default timeout (30 seconds).
    public func execute(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await execute(request: request, timeout: 30)
    }

    /// Executes and decodes with default timeout (30 seconds).
    public func execute<T: Decodable>(
        request: URLRequest,
        decodingTo type: T.Type
    ) async throws -> T {
        try await execute(request: request, decodingTo: type, timeout: 30)
    }

    /// Uploads file with default timeout (60 seconds) and headers.
    public func uploadFile(
        to url: URL,
        fileURL: URL,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String] = [:],
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        try await uploadFile(
            to: url,
            fileURL: fileURL,
            fileName: fileName,
            mimeType: mimeType,
            additionalFields: additionalFields,
            headers: headers,
            timeout: 60
        )
    }
}

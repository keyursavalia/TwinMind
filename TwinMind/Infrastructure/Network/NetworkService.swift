//
//  NetworkService.swift
//  TwinMind
//
//  Purpose: Concrete implementation of NetworkServiceProtocol using URLSession.
//  Design decision: Wraps URLSession with typed error handling, connectivity monitoring,
//  and standardized request/response patterns for testability.
//

import Foundation
import Network

/// Concrete implementation of HTTP network operations using URLSession.
///
/// This service handles all network requests with automatic error mapping,
/// connectivity monitoring, and multipart file uploads.
public final class NetworkService: NetworkServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    /// The underlying URLSession instance.
    private let session: URLSession

    /// Network path monitor for connectivity checking.
    private let pathMonitor: NWPathMonitor

    /// Queue for path monitoring.
    private let monitorQueue: DispatchQueue

    /// Current connectivity status.
    private var isCurrentlyConnected: Bool

    /// Continuation for connectivity stream.
    private var connectivityContinuation: AsyncStream<Bool>.Continuation?

    // MARK: - Initialization

    /// Creates a new network service instance.
    ///
    /// - Parameter session: The URLSession to use (defaults to .shared).
    public init(session: URLSession = .shared) {
        self.session = session
        self.pathMonitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(label: "com.twinmind.network.monitor")
        self.isCurrentlyConnected = false
    }

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Request Execution

    public func execute(request: URLRequest, timeout: TimeInterval = 30) async throws -> (Data, HTTPURLResponse) {
        // Create request with timeout
        var timeoutRequest = request
        timeoutRequest.timeoutInterval = timeout

        do {
            let (data, response) = try await session.data(for: timeoutRequest)

            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkRequestFailed(
                    statusCode: nil,
                    reason: "Invalid response type"
                )
            }

            // Check for HTTP errors
            guard (200...299).contains(httpResponse.statusCode) else {
                throw AppError.networkRequestFailed(
                    statusCode: httpResponse.statusCode,
                    reason: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                )
            }

            return (data, httpResponse)

        } catch let error as AppError {
            throw error
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw AppError.networkRequestFailed(statusCode: nil, reason: error.localizedDescription)
        }
    }

    public func execute<T: Decodable>(
        request: URLRequest,
        decodingTo type: T.Type,
        timeout: TimeInterval = 30
    ) async throws -> T {
        let (data, _) = try await execute(request: request, timeout: timeout)

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            throw AppError.invalidResponseFormat(
                expectedFormat: "JSON decodable to \(String(describing: type))"
            )
        }
    }

    public func uploadFile(
        to url: URL,
        fileURL: URL,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String] = [:],
        timeout: TimeInterval = 60
    ) async throws -> (Data, HTTPURLResponse) {
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        // Add additional fields
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        // Add file data
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")

        let fileData = try Data(contentsOf: fileURL)
        body.append(fileData)
        body.append("\r\n")

        // Close boundary
        body.append("--\(boundary)--\r\n")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = body
        request.timeoutInterval = timeout

        return try await execute(request: request, timeout: timeout)
    }

    // MARK: - Connectivity

    public func isConnected() async -> Bool {
        return isCurrentlyConnected
    }

    public func startMonitoring() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            self.connectivityContinuation = continuation

            pathMonitor.pathUpdateHandler = { [weak self] path in
                let isConnected = path.status == .satisfied
                self?.isCurrentlyConnected = isConnected
                continuation.yield(isConnected)
            }

            pathMonitor.start(queue: monitorQueue)

            continuation.onTermination = { [weak self] _ in
                self?.pathMonitor.cancel()
            }
        }
    }

    public func stopMonitoring() {
        connectivityContinuation?.finish()
        connectivityContinuation = nil
        pathMonitor.cancel()
    }

    // MARK: - Private Helpers

    /// Maps URLError to typed AppError.
    private func mapURLError(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection

        case .timedOut:
            return .networkTimeout

        case .badServerResponse, .cannotDecodeContentData, .cannotDecodeRawData:
            return .invalidResponseFormat(expectedFormat: "Valid HTTP response")

        default:
            return .networkRequestFailed(
                statusCode: nil,
                reason: error.localizedDescription
            )
        }
    }
}

// MARK: - Data Extension

private extension Data {

    /// Appends a string to the data using UTF-8 encoding.
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

//
//  SessionDetailViewModel.swift
//  TwinMind
//
//  Purpose: ViewModel for the session detail screen.
//  Design decision: Fetches segments and transcriptions for a single session,
//  provides full transcription text and segment-by-segment view.
//

import Foundation
import Observation
internal import os

/// ViewModel managing the session detail screen state and interactions.
///
/// This view model coordinates fetching audio segments and their transcriptions
/// for a specific recording session.
@MainActor
@Observable
public final class SessionDetailViewModel {

    // MARK: - Published State

    /// The recording session being displayed.
    public let session: RecordingSession

    /// Audio segments with their transcriptions.
    public var segments: [AudioSegment] = []

    /// Whether data is currently being loaded.
    public var isLoading: Bool = false

    /// Current error to display.
    public var currentError: AppError?

    /// Whether to show the error banner.
    public var showErrorBanner: Bool = false

    // MARK: - Dependencies

    public let dataManager: any DataManagerProtocol

    // MARK: - Initialization

    /// Creates a new session detail view model.
    ///
    /// - Parameters:
    ///   - session: The recording session to display.
    ///   - dataManager: The data manager actor.
    public init(session: RecordingSession, dataManager: any DataManagerProtocol) {
        self.session = session
        self.dataManager = dataManager
    }

    // MARK: - Public Methods

    /// Loads segments for the current session.
    public func loadSegments() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                // Fetch all segments for this session, ordered by index
                segments = try await dataManager.fetchSegments(
                    sessionId: session.id,
                    sortDescriptors: [SortDescriptor(\.index, order: .forward)]
                )

                AppLogger.ui.info("Loaded \(self.segments.count) segments for session: \(self.session.id)")

            } catch {
                handleError(error)
            }
        }
    }

    /// Dismisses the current error banner.
    public func dismissError() {
        showErrorBanner = false
        currentError = nil
    }

    // MARK: - Computed Properties

    /// Full transcription text combining all segment transcriptions.
    public var fullTranscription: String {
        let transcribedSegments = segments.filter { $0.transcription != nil }

        guard !transcribedSegments.isEmpty else {
            return "No transcription available yet."
        }

        return transcribedSegments
            .compactMap { $0.transcription?.text }
            .joined(separator: " ")
    }

    /// Whether any segments have transcriptions.
    public var hasTranscriptions: Bool {
        segments.contains { $0.transcription != nil }
    }

    // MARK: - Private Helpers

    private func handleError(_ error: Error) {
        let appError = error as? AppError ?? .unknown(message: error.localizedDescription)
        currentError = appError
        showErrorBanner = true

        AppLogger.ui.error("Session detail error", error: appError)
    }
}

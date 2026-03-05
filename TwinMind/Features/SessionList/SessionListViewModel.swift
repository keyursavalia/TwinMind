//
//  SessionListViewModel.swift
//  TwinMind
//
//  Purpose: ViewModel for the session list screen.
//  Design decision: Fetches sessions from SwiftData and provides
//  filtering, sorting, and deletion capabilities.
//

import Foundation
import Observation
internal import os

/// ViewModel managing the session list screen state and interactions.
///
/// This view model coordinates between the UI and DataManagerActor,
/// handling session fetching, filtering, and deletion.
@MainActor
@Observable
public final class SessionListViewModel {

    // MARK: - Published State

    /// All recording sessions.
    public var sessions: [RecordingSession] = []

    /// Whether data is currently being loaded.
    public var isLoading: Bool = false

    /// Current error to display.
    public var currentError: AppError?

    /// Whether to show the error banner.
    public var showErrorBanner: Bool = false

    /// Search query for filtering sessions.
    public var searchQuery: String = ""

    /// Selected sort option.
    public var sortOption: SortOption = .dateDescending

    // MARK: - Dependencies

    public let dataManager: any DataManagerProtocol

    // MARK: - Initialization

    /// Creates a new session list view model.
    ///
    /// - Parameter dataManager: The data manager actor.
    public init(dataManager: any DataManagerProtocol) {
        self.dataManager = dataManager
    }

    // MARK: - Public Methods

    /// Loads sessions from the database.
    public func loadSessions() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                let sortDescriptors = sortOption.descriptors
                let allSessions = try await dataManager.fetchSessions(
                    predicate: nil,
                    sortDescriptors: sortDescriptors,
                    limit: 1000,
                    offset: 0
                )

                // Apply search filter if needed
                if searchQuery.isEmpty {
                    sessions = allSessions
                } else {
                    sessions = allSessions.filter { session in
                        session.name.localizedCaseInsensitiveContains(searchQuery)
                    }
                }

                AppLogger.ui.info("Loaded \(self.sessions.count) sessions")

            } catch {
                handleError(error)
            }
        }
    }

    /// Deletes a session.
    ///
    /// - Parameter session: The session to delete.
    public func deleteSession(_ session: RecordingSession) {
        Task {
            do {
                try await dataManager.deleteSession(id: session.id)
                await loadSessions() // Refresh list

                AppLogger.ui.info("Deleted session: \(session.id)")

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

    // MARK: - Private Helpers

    private func handleError(_ error: Error) {
        let appError = error as? AppError ?? .unknown(message: error.localizedDescription)
        currentError = appError
        showErrorBanner = true

        AppLogger.ui.error("Session list error", error: appError)
    }
}

// MARK: - SortOption

extension SessionListViewModel {

    /// Sort options for session list.
    public enum SortOption: String, CaseIterable, Identifiable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case nameAscending = "Name A-Z"
        case durationDescending = "Longest First"

        public var id: String { rawValue }

        var descriptors: [SortDescriptor<RecordingSession>] {
            switch self {
            case .dateDescending:
                return [SortDescriptor(\.startedAt, order: .reverse)]
            case .dateAscending:
                return [SortDescriptor(\.startedAt, order: .forward)]
            case .nameAscending:
                return [SortDescriptor(\.name, order: .forward)]
            case .durationDescending:
                return [SortDescriptor(\.durationSeconds, order: .reverse)]
            }
        }
    }
}

//
//  SessionListView.swift
//  TwinMind
//
//  Purpose: Main session list screen showing all recordings.
//  Design decision: List view with search, sorting, and swipe-to-delete.
//  Tapping a session navigates to the detail view.
//

import SwiftUI

/// Session list view showing all recordings.
///
/// This view provides browsing, searching, and managing recording sessions.
public struct SessionListView: View {

    // MARK: - Properties

    @State private var viewModel: SessionListViewModel

    // MARK: - Initialization

    public init(viewModel: SessionListViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.sessions.isEmpty {
                    LoadingStateView.fullScreen(message: "Loading sessions...")
                } else if viewModel.sessions.isEmpty {
                    EmptyStateView.noSessions {
                        // Navigate to recording tab would go here
                    }
                } else {
                    sessionList
                }
            }
            .navigationTitle("Sessions")
            .searchable(text: $viewModel.searchQuery, prompt: "Search sessions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
            .overlay(alignment: .top) {
                if viewModel.showErrorBanner, let error = viewModel.currentError {
                    ErrorBannerView(
                        error: error,
                        onRetry: { viewModel.loadSessions() },
                        onDismiss: viewModel.dismissError
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: viewModel.showErrorBanner)
            .task {
                viewModel.loadSessions()
            }
            .onChange(of: viewModel.searchQuery) {
                viewModel.loadSessions()
            }
            .onChange(of: viewModel.sortOption) {
                viewModel.loadSessions()
            }
        }
    }

    // MARK: - Subviews

    private var sessionList: some View {
        List {
            ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { date in
                Section(date) {
                    ForEach(groupedSessions[date] ?? [], id: \.id) { session in
                        NavigationLink {
                            SessionDetailView(
                                viewModel: SessionDetailViewModel(
                                    session: session,
                                    dataManager: viewModel.dataManager
                                )
                            )
                        } label: {
                            SessionRowView(session: session)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteSession(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadSessions()
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $viewModel.sortOption) {
                ForEach(SessionListViewModel.SortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Helpers

    private var groupedSessions: [String: [RecordingSession]] {
        Dictionary(grouping: viewModel.sessions) { session in
            session.groupingDateString
        }
    }
}

// MARK: - SessionRowView

/// Row view for a single session in the list.
private struct SessionRowView: View {
    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Session name
            Text(session.name)
                .font(.headline)

            // Metadata
            HStack(spacing: 12) {
                // Duration
                Label(session.formattedDuration, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // State
                Label(session.state.displayString, systemImage: session.state.iconName)
                    .font(.caption)
                    .foregroundStyle(stateColor)

                Spacer()

                // Transcription progress
                if session.segmentCount > 0 {
                    transcriptionProgressView
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var transcriptionProgressView: some View {
        HStack(spacing: 4) {
            if session.transcriptionProgress >= 1.0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else if session.transcriptionProgress > 0 {
                ProgressView(value: session.transcriptionProgress)
                    .frame(width: 40)
                    .tint(.blue)
            } else {
                Image(systemName: "clock")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            Text("\(session.transcribedSegmentCount)/\(session.segmentCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stateColor: Color {
        switch session.state {
        case .active, .paused:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
}


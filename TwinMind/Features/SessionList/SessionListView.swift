//
//  SessionListView.swift
//  TwinMind
//
//  Purpose: Main session list view displaying all recording sessions.
//  Design decision: List-based UI with date grouping and search capabilities.
//  Uses @Bindable for iOS 17+ ViewModel binding.
//

import SwiftUI
import SwiftData

/// Main view displaying all recording sessions grouped by date.
///
/// This view provides the primary navigation hub for the app, showing
/// all sessions with their state, progress, and metadata. Users can
/// search, sort, and navigate to session details or start a new recording.
public struct SessionListView: View {

    // MARK: - Properties

    @Bindable var viewModel: SessionListViewModel
    let dependencies: AppDependencies
    @State private var showingRecordingView = false
    @State private var showingSortOptions = false

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main content
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // Session list
                    if viewModel.isLoading && viewModel.sessions.isEmpty {
                        loadingView
                    } else if viewModel.sessions.isEmpty {
                        emptyStateView
                    } else {
                        sessionsList
                    }
                }

                // Floating action button
                floatingActionButton
                    .padding(.bottom, 32)
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    sortButton
                }
            }
            .task {
                viewModel.loadSessions()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
            .sheet(isPresented: $showingRecordingView, onDismiss: {
                // Reload sessions when recording view is dismissed
                viewModel.loadSessions()
            }) {
                RecordingView(viewModel: createRecordingViewModel())
            }
            .confirmationDialog("Sort By", isPresented: $showingSortOptions) {
                ForEach(SessionListViewModel.SortOption.allCases) { option in
                    Button(option.rawValue) {
                        viewModel.sortOption = option
                        viewModel.loadSessions()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search sessions", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.loadSessions()
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var sessionsList: some View {
        List {
            ForEach(groupedSessions.keys.sorted(by: sortDates), id: \.self) { dateKey in
                Section {
                    ForEach(groupedSessions[dateKey] ?? []) { session in
                        NavigationLink {
                            SessionDetailView(
                                viewModel: createSessionDetailViewModel(for: session)
                            )
                        } label: {
                            SessionRowView(session: session)
                        }
                    }
                    .onDelete { indexSet in
                        deleteItems(at: indexSet, in: dateKey)
                    }
                } header: {
                    Text(dateKey)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.loadSessions()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading sessions...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Sessions Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the + button to start your first recording")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sortButton: some View {
        Button {
            showingSortOptions = true
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
        }
    }

    private var floatingActionButton: some View {
        Button {
            showingRecordingView = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Computed Properties

    /// Groups sessions by their date string (Today, Yesterday, etc.)
    private var groupedSessions: [String: [RecordingSession]] {
        Dictionary(grouping: viewModel.sessions) { session in
            session.groupingDateString
        }
    }

    /// Sort function for date group keys
    private func sortDates(_ date1: String, _ date2: String) -> Bool {
        // "Today" comes first, then "Yesterday", then chronological
        if date1 == "Today" { return true }
        if date2 == "Today" { return false }
        if date1 == "Yesterday" { return true }
        if date2 == "Yesterday" { return false }
        return date1 > date2
    }

    // MARK: - Helper Methods

    private func deleteItems(at offsets: IndexSet, in dateKey: String) {
        guard let sessions = groupedSessions[dateKey] else { return }

        for index in offsets {
            let session = sessions[index]
            viewModel.deleteSession(session)
        }
    }

    private func createRecordingViewModel() -> RecordingViewModel {
        RecordingViewModel(
            audioEngine: dependencies.audioEngine,
            transcriptionPipeline: dependencies.transcriptionPipeline,
            dataManager: dependencies.dataManager
        )
    }

    private func createSessionDetailViewModel(for session: RecordingSession) -> SessionDetailViewModel {
        SessionDetailViewModel(
            session: session,
            dataManager: dependencies.dataManager
        )
    }
}

// MARK: - SessionRowView

/// Individual session row component for the list.
private struct SessionRowView: View {
    let session: RecordingSession

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Status icon
                statusIcon

                // Session info
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(session.startedAt.formattedTime)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Duration
                Text(session.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(durationColor)
                    .monospacedDigit()
            }
            .padding(.vertical, 12)

            // Progress bar
            if session.segmentCount > 0 {
                ProgressView(value: session.transcriptionProgress)
                    .tint(progressColor)
                    .padding(.bottom, 12)
            }
        }
    }

    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.system(size: 28))
            .foregroundStyle(statusColor)
    }

    private var statusIconName: String {
        switch session.state {
        case .active:
            return "record.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "stop.circle.fill"
        }
    }

    private var statusColor: Color {
        switch session.state {
        case .active:
            return .red
        case .paused:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }

    private var durationColor: Color {
        session.state == .active ? .red : .secondary
    }

    private var progressColor: Color {
        session.transcriptionProgress >= 1.0 ? .green : .accentColor
    }
}

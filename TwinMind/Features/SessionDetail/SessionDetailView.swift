//
//  SessionDetailView.swift
//  TwinMind
//
//  Purpose: Session detail view displaying metadata, segments, and transcriptions.
//  Design decision: Tabbed interface switching between full text and segment views.
//  Auto-refreshes while transcriptions are in progress.
//

import SwiftUI
import SwiftData

/// Detail view for a single recording session.
///
/// This view displays session metadata, transcription progress, and provides
/// two viewing modes: full transcription text or segment-by-segment breakdown.
/// The view auto-refreshes while transcriptions are processing.
public struct SessionDetailView: View {

    // MARK: - Properties

    @Bindable var viewModel: SessionDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ViewTab = .segments
    @State private var showingShareSheet = false

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with metadata
                sessionHeader
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                Divider()

                // Tab selector
                tabSelector
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .fullText:
                        fullTextView
                    case .segments:
                        segmentsView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                shareButton
            }
        }
        .task {
            viewModel.loadSegments()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    // MARK: - Subviews

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and date
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.session.name)
                    .font(.title)
                    .fontWeight(.bold)

                Text(viewModel.session.formattedStartDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Metadata row
            HStack(spacing: 24) {
                metadataItem(
                    label: "Duration",
                    value: viewModel.session.formattedDuration
                )

                Divider()
                    .frame(height: 40)

                metadataItem(
                    label: "Total Segments",
                    value: "\(viewModel.session.segmentCount)"
                )

                Divider()
                    .frame(height: 40)

                metadataItem(
                    label: "Transcribed",
                    value: transcriptionProgressText
                )
            }
        }
        .padding(.top, 8)
    }

    private func metadataItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 4) {
            tabButton(tab: .fullText)
            tabButton(tab: .segments)
        }
        .padding(2)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tabButton(tab: ViewTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    selectedTab == tab ?
                    Color(.systemBackground) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var fullTextView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoading && viewModel.segments.isEmpty {
                ProgressView("Loading transcription...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if !viewModel.hasTranscriptions {
                emptyTranscriptionView
            } else {
                Text(viewModel.fullTranscription)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var segmentsView: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.segments.isEmpty {
                ProgressView("Loading segments...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if viewModel.segments.isEmpty {
                emptySegmentsView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.segments.enumerated()), id: \.element.id) { index, segment in
                        SegmentRowView(segment: segment)

                        if index < viewModel.segments.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
    }

    private var emptyTranscriptionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Transcription Available")
                .font(.headline)

            Text("Transcriptions are being processed. Check back in a few moments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var emptySegmentsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Segments Found")
                .font(.headline)

            Text("This session has no audio segments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var shareButton: some View {
        Button {
            showingShareSheet = true
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.body)
        }
    }

    // MARK: - Computed Properties

    private var transcriptionProgressText: String {
        let percentage = Int(viewModel.session.transcriptionProgress * 100)
        return "\(percentage)%"
    }

    // MARK: - Enums

    enum ViewTab: String, CaseIterable {
        case fullText = "Full Text"
        case segments = "Segments"
    }
}

// MARK: - SegmentRowView

/// Individual segment row component showing segment metadata and status.
private struct SegmentRowView: View {
    let segment: AudioSegment

    var body: some View {
        HStack(spacing: 16) {
            // Segment info
            VStack(alignment: .leading, spacing: 4) {
                Text("Segment \(segment.index + 1)")
                    .font(.body)
                    .fontWeight(.semibold)

                Text(segment.formattedTimeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            statusBadge
        }
        .padding(16)
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusBackgroundColor)
            .foregroundStyle(statusForegroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(statusBorderColor, lineWidth: 1)
            )
    }

    private var statusText: String {
        switch segment.transcriptionState {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing"
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        case .retrying:
            return "Retrying"
        }
    }

    private var statusBackgroundColor: Color {
        switch segment.transcriptionState {
        case .pending:
            return Color(.systemGray6)
        case .processing, .retrying:
            return Color.accentColor.opacity(0.1)
        case .completed:
            return Color.green.opacity(0.1)
        case .failed:
            return Color.red.opacity(0.1)
        }
    }

    private var statusForegroundColor: Color {
        switch segment.transcriptionState {
        case .pending:
            return .secondary
        case .processing, .retrying:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private var statusBorderColor: Color {
        switch segment.transcriptionState {
        case .pending:
            return Color(.systemGray4)
        case .processing, .retrying:
            return Color.accentColor.opacity(0.3)
        case .completed:
            return Color.green.opacity(0.3)
        case .failed:
            return Color.red.opacity(0.3)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionDetailView(
            viewModel: SessionDetailViewModel(
                session: RecordingSession(
                    name: "Project Alpha Meeting",
                    qualityPreset: "high"
                ),
                dataManager: DataManagerActor(
                    modelContainer: try! ModelContainer(
                        for: RecordingSession.self,
                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                    )
                )
            )
        )
    }
}

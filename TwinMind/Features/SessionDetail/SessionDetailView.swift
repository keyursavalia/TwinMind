//
//  SessionDetailView.swift
//  TwinMind
//
//  Purpose: Detail view showing full transcription for a recording session.
//  Design decision: Displays session metadata, full transcription text,
//  and segment-by-segment breakdown with timestamps.
//

import SwiftUI

/// Session detail view showing transcription and metadata.
///
/// This view displays comprehensive information about a recording session,
/// including its full transcription and individual segment details.
public struct SessionDetailView: View {

    // MARK: - Properties

    @State private var viewModel: SessionDetailViewModel

    // MARK: - Initialization

    public init(viewModel: SessionDetailViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.segments.isEmpty {
                LoadingStateView.fullScreen(message: "Loading transcription...")
            } else {
                contentView
            }
        }
        .navigationTitle(viewModel.session.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if viewModel.showErrorBanner, let error = viewModel.currentError {
                ErrorBannerView(
                    error: error,
                    onRetry: { viewModel.loadSegments() },
                    onDismiss: viewModel.dismissError
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: viewModel.showErrorBanner)
        .task {
            viewModel.loadSegments()
        }
    }

    // MARK: - Subviews

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Session metadata
                sessionMetadataSection

                // Full transcription
                if viewModel.hasTranscriptions {
                    fullTranscriptionSection
                }

                // Segment breakdown
                if !viewModel.segments.isEmpty {
                    segmentBreakdownSection
                }
            }
            .padding()
        }
    }

    private var sessionMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Details")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                MetadataRow(
                    icon: "calendar",
                    label: "Date",
                    value: viewModel.session.formattedStartDate
                )

                MetadataRow(
                    icon: "clock",
                    label: "Duration",
                    value: viewModel.session.formattedDuration
                )

                MetadataRow(
                    icon: "waveform",
                    label: "Segments",
                    value: "\(viewModel.session.segmentCount)"
                )

                MetadataRow(
                    icon: "text.bubble",
                    label: "Transcriptions",
                    value: "\(viewModel.session.transcribedSegmentCount)/\(viewModel.session.segmentCount)"
                )

                MetadataRow(
                    icon: "flag",
                    label: "State",
                    value: viewModel.session.state.displayString
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private var fullTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Full Transcription")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(viewModel.fullTranscription)
                .font(.body)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }

    private var segmentBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Segments")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(Array(viewModel.segments.enumerated()), id: \.element.id) { index, segment in
                    SegmentRowView(
                        segmentNumber: index + 1,
                        segment: segment
                    )
                }
            }
        }
    }
}

// MARK: - MetadataRow

/// Metadata row showing icon, label, and value.
private struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - SegmentRowView

/// Row view for a single audio segment with its transcription.
private struct SegmentRowView: View {
    let segmentNumber: Int
    let segment: AudioSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Segment header
            HStack {
                Text("Segment \(segmentNumber)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Label(segment.formattedDuration, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Transcription or status
            if let transcription = segment.transcription {
                Text(transcription.text)
                    .font(.body)
                    .textSelection(.enabled)
            } else {
                switch segment.transcriptionState {
                case .pending:
                    HStack {
                        ProgressView()
                            .controlSize(.small)

                        Text("Transcription pending...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .processing(let attempt, _):
                    HStack {
                        ProgressView()
                            .controlSize(.small)

                        Text("Processing (attempt \(attempt))...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .retrying(let attempt, let retryAt):
                    HStack {
                        ProgressView()
                            .controlSize(.small)

                        Text("Retrying (attempt \(attempt))...")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                case .failed(let lastAttempt, _):
                    Label("Failed after \(lastAttempt) attempts", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)

                case .completed:
                    Text("No transcription text available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

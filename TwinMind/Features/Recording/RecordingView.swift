//
//  RecordingView.swift
//  TwinMind
//
//  Purpose: Active recording screen with controls and visualizations.
//  Design decision: Full-screen modal presentation with real-time audio
//  level visualization and large timer display using monospaced digits.
//

import SwiftUI
import SwiftData

/// Full-screen recording view with controls and audio visualization.
///
/// This view provides the primary recording interface, displaying elapsed time,
/// audio levels, recording controls, and quality settings. The timer uses
/// monospaced digits for stable visual updates.
public struct RecordingView: View {

    // MARK: - Properties

    @Bindable var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingQualityPicker = false

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .top) {
            // Main content
            if case .idle = viewModel.recordingState {
                // Pre-recording setup screen (no header)
                preRecordingSetup
            } else {
                // Active recording screen (with header)
                VStack(spacing: 0) {
                    activeRecordingHeader
                        .padding(.top, 12)
                        .padding(.horizontal, 16)

                    activeRecordingView
                }
            }

            // Error banner overlay
            if viewModel.showErrorBanner, let error = viewModel.currentError {
                errorBanner(error: error)
                    .padding(.top, 60)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Subviews

    private var preRecordingSetup: some View {
        VStack(spacing: 0) {
            // Top dismiss button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.body)
                        .foregroundStyle(.blue)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            // Microphone icon
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .padding(.bottom, 32)

            // Session name field
            VStack(spacing: 8) {
                Text("Session Name")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextField("Enter session name", text: $viewModel.sessionName)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)

            // Quality selector
            VStack(spacing: 16) {
                Text("Recording Quality")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    ForEach(RecordingQuality.allCases, id: \.self) { quality in
                        qualityButton(quality)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Start recording button
            Button {
                viewModel.startRecording()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.title3)

                    Text("Start Recording")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    private var activeRecordingView: some View {
        VStack(spacing: 0) {
            // Compact timer and audio level
            VStack(spacing: 16) {
                timerDisplay
                    .padding(.top, 16)

                audioLevelMeter

                // Segment progress
                HStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("\(viewModel.transcriptionSegments.count) / \(viewModel.totalSegmentCount) transcribed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 16)

            // Divider
            Divider()

            // Live transcription display - takes most of the space
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Live Transcription")
                        .font(.headline)

                    Spacer()

                    // Recording status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(isRecording ? 1.0 : 0.3)

                        Text(viewModel.recordingState.displayString.uppercased())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(statusTextColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if !viewModel.transcriptionSegments.isEmpty {
                    transcriptionList
                } else {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .padding(.top, 40)

                        Text("Recording audio...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Transcription will appear here")
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Controls at bottom
            Divider()
                .padding(.top, 8)

            controls
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
    }

    private var transcriptionList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.transcriptionSegments) { segment in
                        transcriptionSegmentRow(segment)
                            .id(segment.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.transcriptionSegments.count) { _, _ in
                // Auto-scroll to the latest segment
                if let lastSegment = viewModel.transcriptionSegments.last {
                    withAnimation {
                        proxy.scrollTo(lastSegment.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func transcriptionSegmentRow(_ segment: TranscriptionSegment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with segment number and confidence
            HStack(alignment: .center, spacing: 8) {
                Text("[\(segment.index + 1)]")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                if let confidence = segment.confidence {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(confidenceColor(confidence))

                        Text("\(Int(confidence * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(segment.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Transcription text
            Text(segment.text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func qualityButton(_ quality: RecordingQuality) -> some View {
        Button {
            viewModel.selectedQuality = quality
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quality.rawValue.capitalized)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(quality.detailDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.selectedQuality == quality {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                viewModel.selectedQuality == quality
                    ? Color.blue.opacity(0.1)
                    : Color(.secondarySystemBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        viewModel.selectedQuality == quality
                            ? Color.blue
                            : Color.clear,
                        lineWidth: 2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var activeRecordingHeader: some View {
        HStack {
            // Dismiss button
            Button {
                handleDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Session name and audio device
            VStack(spacing: 4) {
                Text(viewModel.sessionName.isEmpty ? "Recording" : viewModel.sessionName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: viewModel.audioRoute.inputIconName)
                        .font(.caption2)

                    Text(viewModel.audioRoute.inputDeviceName)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Stop button
            Button {
                handleStop()
            } label: {
                Text("Stop")
                    .font(.body)
                    .foregroundStyle(.red)
            }
        }
    }

    private var timerDisplay: some View {
        Text(formattedElapsedTime)
            .font(.system(size: 48, weight: .thin, design: .default))
            .monospacedDigit()
            .tracking(2)
            .foregroundStyle(timerColor)
    }

    private var audioLevelMeter: some View {
        HStack(spacing: 3) {
            ForEach(0..<13, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor(for: index))
                    .frame(width: 5, height: barHeight(for: index))
            }
        }
        .frame(height: 32)
        .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
    }

    private var controls: some View {
        HStack(spacing: 24) {
            Spacer()

            // Pause/Resume button
            Button {
                if case .recording = viewModel.recordingState {
                    viewModel.pauseRecording()
                } else if case .paused = viewModel.recordingState {
                    viewModel.resumeRecording()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: pauseResumeIcon)
                        .font(.title3)

                    Text(pauseResumeLabel)
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(minWidth: 140)
                .padding(.vertical, 14)
                .background(isRecording ? Color.orange : Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!canPauseOrResume)

            Spacer()
        }
    }


    private func errorBanner(error: AppError) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("Error")
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.dismissError()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Computed Properties

    private var formattedElapsedTime: String {
        let hours = Int(viewModel.elapsedTime) / 3600
        let minutes = (Int(viewModel.elapsedTime) % 3600) / 60
        let seconds = Int(viewModel.elapsedTime) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private var timerColor: Color {
        isRecording ? .red : .primary
    }

    private var isRecording: Bool {
        if case .recording = viewModel.recordingState {
            return true
        }
        return false
    }

    private var canPauseOrResume: Bool {
        viewModel.recordingState.canPause || viewModel.recordingState.canResume
    }

    private var pauseResumeIcon: String {
        if case .paused = viewModel.recordingState {
            return "play.fill"
        }
        return "pause.fill"
    }

    private var pauseResumeLabel: String {
        if case .paused = viewModel.recordingState {
            return "Resume"
        }
        return "Pause"
    }

    private var statusTextColor: Color {
        isRecording ? .red : .secondary
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }

    private func barColor(for index: Int) -> Color {
        let normalizedLevel = CGFloat(viewModel.audioLevel)
        let threshold = CGFloat(index) / 13.0

        if normalizedLevel > threshold {
            return Color.blue
        } else {
            return Color(.systemGray5)
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 32
        let increment = (maxHeight - baseHeight) / 12

        return baseHeight + (CGFloat(index) * increment)
    }

    // MARK: - Actions

    private func handleDismiss() {
        if viewModel.recordingState.canStop {
            // Show confirmation if recording is active
            // For now, just dismiss
            dismiss()
        } else {
            dismiss()
        }
    }

    private func handleStop() {
        viewModel.stopRecording()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    RecordingView(
        viewModel: RecordingViewModel(
            audioEngine: AudioEngineActor(
                audioFileManager: AudioFileManager(),
                encryptionService: EncryptionService(keychainService: KeychainService())
            ),
            transcriptionPipeline: TranscriptionPipelineActor(
                primaryService: GeminiTranscriptionService(
                    networkService: NetworkService(),
                    keychainService: KeychainService(),
                    encryptionService: EncryptionService(keychainService: KeychainService())
                ),
                fallbackService: AppleSpeechService(
                    encryptionService: EncryptionService(keychainService: KeychainService())
                ),
                dataManager: DataManagerActor(
                    modelContainer: try! ModelContainer(
                        for: RecordingSession.self,
                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                    )
                ),
                encryptionService: EncryptionService(keychainService: KeychainService()),
                networkService: NetworkService()
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

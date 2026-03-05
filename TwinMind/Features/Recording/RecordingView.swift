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
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                Spacer()

                // Timer and audio level meter
                VStack(spacing: 48) {
                    timerDisplay
                    audioLevelMeter
                }

                Spacer()

                // Controls
                controls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                // Recording status
                recordingStatus
                    .padding(.bottom, 24)
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
            // Start recording automatically when view appears
            if case .idle = viewModel.recordingState {
                viewModel.startRecording()
            }
        }
        .onDisappear {
            viewModel.stopObserving()
        }
        .confirmationDialog("Select Quality", isPresented: $showingQualityPicker) {
            ForEach(RecordingQuality.allCases, id: \.self) { quality in
                Button(quality.displayName) {
                    viewModel.selectedQuality = quality
                }
            }
        } message: {
            Text("Choose recording quality. Higher quality provides better transcription accuracy but uses more storage.")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            // Dismiss button
            Button {
                handleDismiss()
            } label: {
                Text("Dismiss")
                    .font(.body)
                    .foregroundStyle(.blue)
            }

            Spacer()

            // Session name and audio device
            VStack(spacing: 4) {
                TextField("Session Name", text: $viewModel.sessionName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)

                HStack(spacing: 4) {
                    Image(systemName: viewModel.audioRoute.inputIconName)
                        .font(.caption2)

                    Text(viewModel.audioRoute.inputDeviceName)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Invisible spacer for symmetry
            Color.clear
                .frame(width: 70)
        }
    }

    private var timerDisplay: some View {
        Text(formattedElapsedTime)
            .font(.system(size: 64, weight: .thin, design: .default))
            .monospacedDigit()
            .tracking(4)
            .foregroundStyle(timerColor)
    }

    private var audioLevelMeter: some View {
        HStack(spacing: 4) {
            ForEach(0..<13, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8)
                    .fill(barColor(for: index))
                    .frame(width: 6, height: barHeight(for: index))
            }
        }
        .frame(height: 48)
        .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
    }

    private var controls: some View {
        HStack(spacing: 32) {
            // Pause/Resume button
            Button {
                if case .recording = viewModel.recordingState {
                    viewModel.pauseRecording()
                } else if case .paused = viewModel.recordingState {
                    viewModel.resumeRecording()
                }
            } label: {
                Image(systemName: pauseResumeIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(.primary)
                    .frame(width: 64, height: 64)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .disabled(!canPauseOrResume)

            // Stop button
            Button {
                handleStop()
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red)
                    .frame(width: 32, height: 32)
                    .frame(width: 80, height: 80)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }

            // Quality button
            Button {
                showingQualityPicker = true
            } label: {
                VStack(spacing: 2) {
                    Text(qualityShortName)
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("Quality")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)
                .background(Color(.systemGray6))
                .clipShape(Circle())
            }
            .disabled(isRecording)
        }
    }

    private var recordingStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(isRecording ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(), value: isRecording)

            Text(viewModel.recordingState.displayString.uppercased())
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1.5)
                .foregroundStyle(statusTextColor)
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

    private var statusTextColor: Color {
        isRecording ? .red : .secondary
    }

    private var qualityShortName: String {
        switch viewModel.selectedQuality {
        case .high:
            return "High"
        case .medium:
            return "Med"
        case .low:
            return "Low"
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
        let baseHeight: CGFloat = 12
        let maxHeight: CGFloat = 48
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

//
//  RecordingView.swift
//  TwinMind
//
//  Purpose: Main recording screen with controls and waveform.
//  Design decision: Minimal UI with large recording button, real-time
//  audio level visualization, and session metadata display.
//

import SwiftUI

/// Main recording screen view.
///
/// This view provides recording controls, real-time audio level visualization,
/// session information, and error handling.
public struct RecordingView: View {

    // MARK: - Properties

    @State private var viewModel: RecordingViewModel

    // MARK: - Initialization

    public init(viewModel: RecordingViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 32) {
            // Header
            headerView

            Spacer()

            // Audio level visualization
            audioLevelView

            // Elapsed time
            timerView

            // Recording controls
            controlsView

            Spacer()

            // Session info
            sessionInfoView
        }
        .padding()
        .overlay(alignment: .top) {
            if viewModel.showErrorBanner, let error = viewModel.currentError {
                ErrorBannerView(
                    error: error,
                    onRetry: viewModel.retryAfterError,
                    onDismiss: viewModel.dismissError
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: viewModel.showErrorBanner)
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("TwinMind")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(viewModel.recordingState.displayString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var audioLevelView: some View {
        VStack(spacing: 16) {
            // Waveform visualization
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<40, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: 4, height: barHeight(for: index))
                        .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
                }
            }
            .frame(height: 100)

            // Audio route info
            if case .recording = viewModel.recordingState {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.audioRoute.inputIconName)
                        .foregroundStyle(.secondary)

                    Text(viewModel.audioRoute.inputDisplayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var timerView: some View {
        Text(viewModel.elapsedTime.formattedDuration)
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundStyle(.primary)
    }

    private var controlsView: some View {
        HStack(spacing: 32) {
            // Stop button
            if viewModel.recordingState.canStop {
                Button {
                    viewModel.stopRecording()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }

            // Main record/pause button
            Button {
                handleMainButtonTap()
            } label: {
                Image(systemName: mainButtonIcon)
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(mainButtonColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(mainButtonColor.opacity(0.3), lineWidth: 4)
                            .scaleEffect(1.2)
                    )
            }

            // Resume button (when paused)
            if viewModel.recordingState.canResume {
                Button {
                    viewModel.resumeRecording()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.green)
                        .clipShape(Circle())
                }
            }
        }
    }

    private var sessionInfoView: some View {
        VStack(spacing: 8) {
            if case .idle = viewModel.recordingState {
                // Session name input
                TextField("Session Name", text: $viewModel.sessionName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)

                // Quality picker
                Picker("Quality", selection: $viewModel.selectedQuality) {
                    ForEach(RecordingQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            } else if !viewModel.sessionName.isEmpty {
                Text(viewModel.sessionName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var mainButtonIcon: String {
        switch viewModel.recordingState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "pause.fill"
        case .paused:
            return "play.fill"
        default:
            return "mic.fill"
        }
    }

    private var mainButtonColor: Color {
        switch viewModel.recordingState {
        case .idle:
            return .blue
        case .recording:
            return .red
        case .paused:
            return .orange
        default:
            return .gray
        }
    }

    private func handleMainButtonTap() {
        switch viewModel.recordingState {
        case .idle:
            viewModel.startRecording()
        case .recording:
            viewModel.pauseRecording()
        case .paused:
            viewModel.resumeRecording()
        default:
            break
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 20
        let maxHeight: CGFloat = 100

        // Create wave pattern based on audio level
        let normalizedLevel = CGFloat(viewModel.audioLevel)
        let waveOffset = sin(Double(index) * 0.3) * 0.5 + 0.5

        return baseHeight + (maxHeight - baseHeight) * normalizedLevel * CGFloat(waveOffset)
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Int(Float(40) * viewModel.audioLevel)
        return index < threshold ? .blue : .gray.opacity(0.3)
    }
}

// MARK: - Preview

#Preview("Recording - Idle") {
    RecordingView(
        viewModel: RecordingViewModel(
            audioEngine: MockAudioEngine(),
            transcriptionPipeline: MockTranscriptionPipeline(),
            dataManager: MockDataManager()
        )
    )
}

// MARK: - Mock Implementations (for preview)

private actor MockAudioEngine: AudioEngineProtocol {
    var eventStream: AsyncStream<AudioEngineEvent> { AsyncStream { _ in } }
    var currentState: RecordingState { .idle }
    var currentRoute: AudioRouteInfo { .default }
    func startRecording(sessionId: UUID, quality: RecordingQuality) async throws {}
    func stopRecording() async throws {}
    func pauseRecording() async throws {}
    func resumeRecording() async throws {}
    func requestMicrophonePermission() async -> Bool { true }
    func checkMicrophonePermission() async -> Bool { true }
    func updateQuality(_ quality: RecordingQuality) async throws {}
    func reset() async {}
}

private actor MockTranscriptionPipeline: TranscriptionPipelineProtocol {
    var eventStream: AsyncStream<TranscriptionPipelineEvent> { AsyncStream { _ in } }
    var queuedJobCount: Int { 0 }
    var processingJobCount: Int { 0 }
    var activeServiceIdentifier: String { "gemini-api" }
    func submitJob(_ job: SegmentJob) async {}
    func cancelJob(segmentId: UUID) async {}
    func drainOfflineQueue() async {}
    func switchService(to serviceIdentifier: String) async {}
}

private actor MockDataManager: DataManagerProtocol {
    func createSession(id: UUID, name: String, quality: RecordingQuality) async throws -> RecordingSession {
        RecordingSession(id: id, name: name, qualityPreset: quality.rawValue)
    }
    func updateSession(_ session: RecordingSession) async throws {}
    func fetchSession(id: UUID) async throws -> RecordingSession? { nil }
    func fetchSessions(predicate: Predicate<RecordingSession>?, sortDescriptors: [SortDescriptor<RecordingSession>], limit: Int, offset: Int) async throws -> [RecordingSession] { [] }
    func deleteSession(id: UUID) async throws {}
    func createSegment(sessionId: UUID, index: Int, startOffset: Double, duration: Double, audioFilePath: String) async throws -> AudioSegment {
        AudioSegment(index: index, startOffset: startOffset, durationSeconds: duration, audioFilePath: audioFilePath)
    }
    func batchInsertSegments(_ segments: [AudioSegment], sessionId: UUID) async throws {}
    func updateSegmentTranscriptionState(segmentId: UUID, state: TranscriptionState) async throws {}
    func fetchSegments(sessionId: UUID, sortDescriptors: [SortDescriptor<AudioSegment>]) async throws -> [AudioSegment] { [] }
    func fetchPendingSegments() async throws -> [AudioSegment] { [] }
    func createTranscriptionResult(segmentId: UUID, text: String, confidence: Double?, language: String?, modelUsed: String) async throws -> TranscriptionResult {
        TranscriptionResult(text: text, modelUsed: modelUsed)
    }
    func fetchTranscriptionResult(segmentId: UUID) async throws -> TranscriptionResult? { nil }
    func deleteSessionsOlderThan(_ date: Date) async throws -> Int { 0 }
    func countSessions(predicate: Predicate<RecordingSession>?) async throws -> Int { 0 }
    func save() async throws {}
}

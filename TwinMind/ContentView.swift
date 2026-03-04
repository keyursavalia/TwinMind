//
//  ContentView.swift
//  TwinMind
//
//  Purpose: Main content view of the application.
//  Design decision: Simple tab view with Recording as the primary screen.
//  Future tabs can include session list and settings.
//

import SwiftUI

/// Main content view of the TwinMind application.
///
/// This view provides the primary navigation structure and
/// instantiates view models with injected dependencies.
struct ContentView: View {

    // MARK: - Properties

    let dependencies: AppDependencies

    // MARK: - Body

    var body: some View {
        TabView {
            // Recording tab
            RecordingView(
                viewModel: RecordingViewModel(
                    audioEngine: dependencies.audioEngine,
                    transcriptionPipeline: dependencies.transcriptionPipeline,
                    dataManager: dependencies.dataManager
                )
            )
            .tabItem {
                Label("Record", systemImage: "mic.fill")
            }

            // Sessions tab (placeholder)
            SessionsPlaceholderView()
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet")
                }

            // Settings tab (placeholder)
            SettingsPlaceholderView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Placeholder Views

/// Placeholder for sessions list view.
private struct SessionsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView.noSessions {
                // Navigate to recording tab
            }
            .navigationTitle("Sessions")
        }
    }
}

/// Placeholder for settings view.
private struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }

                Section("Recording") {
                    Text("Recording quality settings")
                    Text("Storage management")
                }

                Section("Transcription") {
                    Text("Service selection")
                    Text("Language settings")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

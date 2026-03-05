//
//  TwinMindApp.swift
//  TwinMind
//
//  Purpose: App entry point and dependency injection setup.
//  Design decision: Initializes AppDependencies on app launch and injects
//  via environment for clean, testable architecture.
//

import SwiftUI
import SwiftData
internal import os

@main
struct TwinMindApp: App {

    @State private var dependencies: AppDependencies?
    @State private var initializationError: Error?

    var body: some Scene {
        WindowGroup {
            Group {
                if let dependencies = dependencies {
                    RootPlaceholderView(dependencies: dependencies)
                } else if let error = initializationError {
                    ErrorView(error: error)
                } else {
                    ProgressView("Initializing...")
                        .padding()
                }
            }
            .task {
                await initializeDependencies()
            }
        }
    }

    // MARK: - Initialization

    @MainActor
    private func initializeDependencies() async {
        do {
            AppLogger.lifecycle.info("TwinMindApp launching")

            dependencies = try AppDependencies()

            AppLogger.lifecycle.info("TwinMindApp initialized successfully")

        } catch {
            AppLogger.lifecycle.error("Failed to initialize app", error: error)
            initializationError = error
        }
    }
}

// MARK: - ErrorView

/// View displayed when app initialization fails.
private struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Initialization Failed")
                .font(.title)
                .fontWeight(.bold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Quit") {
                exit(1)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }
}

// MARK: - RootPlaceholderView

/// Temporary root view used while rebuilding the TwinMind UI.
private struct RootPlaceholderView: View {
    let dependencies: AppDependencies

    var body: some View {
        VStack(spacing: 16) {
            Text("TwinMind backend is initialized.")
                .font(.headline)

            Text("Implement the new UI using existing ViewModels and domain actors.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

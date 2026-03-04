//
//  LoadingStateView.swift
//  TwinMind
//
//  Purpose: Reusable loading indicator with optional message.
//  Design decision: Consistent loading state presentation across all async
//  operations (data fetching, transcription processing, file operations).
//

import SwiftUI

/// A view displaying a loading indicator with an optional message.
///
/// This view provides consistent loading state presentation across the app,
/// with customizable message and progress indicator style.
public struct LoadingStateView: View {

    // MARK: - Properties

    /// Optional loading message.
    let message: String?

    /// Whether to show a tinted background.
    let showBackground: Bool

    // MARK: - Initialization

    /// Creates a loading state view.
    ///
    /// - Parameters:
    ///   - message: Optional message to display below the spinner.
    ///   - showBackground: Whether to show a tinted background (default: false).
    public init(
        message: String? = nil,
        showBackground: Bool = false
    ) {
        self.message = message
        self.showBackground = showBackground
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.accentColor)

            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(
            Group {
                if showBackground {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
            }
        )
    }
}

// MARK: - Full Screen Loading

extension LoadingStateView {

    /// A full-screen loading view with centered content.
    public static func fullScreen(message: String? = nil) -> some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            LoadingStateView(message: message, showBackground: true)
        }
    }
}

// MARK: - Preview

#Preview("Loading States") {
    VStack(spacing: 32) {
        LoadingStateView()

        LoadingStateView(message: "Loading sessions...")

        LoadingStateView(message: "Processing transcription...", showBackground: true)
    }
    .padding()
}

#Preview("Full Screen Loading") {
    LoadingStateView.fullScreen(message: "Saving recording...")
}

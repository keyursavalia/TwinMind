//
//  EmptyStateView.swift
//  TwinMind
//
//  Purpose: Reusable empty state component for lists and collections.
//  Design decision: Consistent empty state messaging with optional action
//  improves discoverability and guides users to first actions.
//

import SwiftUI

/// A view displaying an empty state with icon, title, message, and optional action.
///
/// This view provides consistent empty state presentation for lists, search results,
/// and other scenarios where no content is available.
public struct EmptyStateView: View {

    // MARK: - Properties

    /// SF Symbol icon name.
    let iconName: String

    /// Primary title.
    let title: String

    /// Optional descriptive message.
    let message: String?

    /// Optional action button title.
    let actionTitle: String?

    /// Optional action callback.
    let action: (() -> Void)?

    // MARK: - Initialization

    /// Creates an empty state view.
    ///
    /// - Parameters:
    ///   - iconName: SF Symbol icon name.
    ///   - title: Primary title text.
    ///   - message: Optional descriptive message.
    ///   - actionTitle: Optional action button title.
    ///   - action: Optional action callback.
    public init(
        iconName: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: iconName)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if let message = message {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Common Empty States

extension EmptyStateView {

    /// Empty state for no recording sessions.
    public static func noSessions(onStartRecording: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            iconName: "waveform.circle",
            title: "No Recordings Yet",
            message: "Start your first recording to see it here. Your audio will be transcribed automatically.",
            actionTitle: "Start Recording",
            action: onStartRecording
        )
    }

    /// Empty state for no search results.
    public static func noSearchResults(searchText: String) -> EmptyStateView {
        EmptyStateView(
            iconName: "magnifyingglass",
            title: "No Results",
            message: "No recordings found for \"\(searchText)\". Try a different search term."
        )
    }

    /// Empty state for no transcriptions.
    public static func noTranscriptions() -> EmptyStateView {
        EmptyStateView(
            iconName: "text.bubble",
            title: "No Transcriptions",
            message: "Transcriptions will appear here once your recording segments are processed."
        )
    }

    /// Empty state for network error.
    public static func networkError(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            iconName: "wifi.slash",
            title: "Connection Error",
            message: "Unable to load data. Please check your internet connection and try again.",
            actionTitle: "Retry",
            action: onRetry
        )
    }
}

// MARK: - Preview

#Preview("Empty States") {
    TabView {
        EmptyStateView.noSessions {
            print("Start recording tapped")
        }
        .tabItem { Label("No Sessions", systemImage: "1.circle") }

        EmptyStateView.noSearchResults(searchText: "test")
            .tabItem { Label("No Results", systemImage: "2.circle") }

        EmptyStateView.noTranscriptions()
            .tabItem { Label("No Transcriptions", systemImage: "3.circle") }

        EmptyStateView.networkError {
            print("Retry tapped")
        }
        .tabItem { Label("Network Error", systemImage: "4.circle") }
    }
}

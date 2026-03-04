//
//  ErrorBannerView.swift
//  TwinMind
//
//  Purpose: Reusable error banner component for displaying app errors.
//  Design decision: Consistent error presentation with dismiss action and
//  optional retry callback improves UX across all error scenarios.
//

import SwiftUI

/// A banner view for displaying error messages with optional retry action.
///
/// This view presents errors consistently across the app with a dismiss button
/// and an optional retry action for transient failures.
public struct ErrorBannerView: View {

    // MARK: - Properties

    /// The error to display.
    let error: AppError

    /// Optional retry action.
    let onRetry: (() -> Void)?

    /// Dismiss action.
    let onDismiss: () -> Void

    // MARK: - Initialization

    /// Creates an error banner view.
    ///
    /// - Parameters:
    ///   - error: The error to display.
    ///   - onRetry: Optional retry action.
    ///   - onDismiss: Dismiss action.
    public init(
        error: AppError,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack(spacing: 8) {
                if onRetry != nil {
                    Button {
                        onRetry?()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.white)
                    }
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview("Error Banner") {
    VStack(spacing: 16) {
        ErrorBannerView(
            error: .networkRequestFailed(statusCode: 500, reason: "Server error"),
            onRetry: {
                print("Retry tapped")
            },
            onDismiss: {
                print("Dismiss tapped")
            }
        )

        ErrorBannerView(
            error: .microphonePermissionDenied,
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
    .padding()
}

//
//  OfflineStatusBannerView.swift
//  TwinMind
//
//  Purpose: Banner component for displaying offline status and queued operations.
//  Design decision: Persistent banner during offline mode provides transparency
//  about pending transcriptions and auto-dismisses when connectivity returns.
//

import SwiftUI

/// A banner view for displaying offline connectivity status.
///
/// This view informs users when the app is offline and shows the number
/// of pending transcription jobs waiting for connectivity.
public struct OfflineStatusBannerView: View {

    // MARK: - Properties

    /// Number of pending transcription jobs.
    let pendingJobsCount: Int

    /// Optional dismiss action.
    let onDismiss: (() -> Void)?

    // MARK: - Initialization

    /// Creates an offline status banner view.
    ///
    /// - Parameters:
    ///   - pendingJobsCount: Number of pending jobs.
    ///   - onDismiss: Optional dismiss action.
    public init(
        pendingJobsCount: Int,
        onDismiss: (() -> Void)? = nil
    ) {
        self.pendingJobsCount = pendingJobsCount
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.white)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Offline")
                    .font(.headline)
                    .foregroundStyle(.white)

                if pendingJobsCount > 0 {
                    Text("\(pendingJobsCount) transcription\(pendingJobsCount == 1 ? "" : "s") pending")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text("No internet connection")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Spacer()

            if let onDismiss = onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.orange)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview("Offline Status Banner") {
    VStack(spacing: 16) {
        OfflineStatusBannerView(
            pendingJobsCount: 5,
            onDismiss: {
                print("Dismiss tapped")
            }
        )

        OfflineStatusBannerView(
            pendingJobsCount: 0
        )

        OfflineStatusBannerView(
            pendingJobsCount: 1,
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
    .padding()
}

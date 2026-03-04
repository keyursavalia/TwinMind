//
//  InterruptionReason.swift
//  TwinMind
//
//  Purpose: Classifies the cause of audio session interruptions.
//  Design decision: Mirrors AVAudioSession interruption types but adds
//  app-specific reasons like route changes and background transitions.
//

import Foundation

/// The reason why an audio recording was interrupted.
///
/// Interruptions can come from system events (phone calls, Siri),
/// hardware changes (route changes), or app lifecycle events.
public enum InterruptionReason: Sendable, Equatable, Codable {

    /// Phone call or FaceTime call began.
    case phoneCall

    /// Siri was activated.
    case siri

    /// Another app started playing audio with higher priority.
    case otherAppAudio

    /// Audio route changed (e.g., headphones disconnected).
    case routeChange

    /// App transitioned to background and lost audio session.
    case backgroundTransition

    /// Audio session was deactivated by the system.
    case sessionDeactivated

    /// Media services were reset by the system.
    case mediaServicesReset

    /// An unknown interruption occurred.
    case unknown
}

// MARK: - Display String

extension InterruptionReason {

    /// A user-facing display string for the interruption reason.
    public var displayString: String {
        switch self {
        case .phoneCall:
            return "Phone Call"
        case .siri:
            return "Siri"
        case .otherAppAudio:
            return "Other App Audio"
        case .routeChange:
            return "Audio Route Changed"
        case .backgroundTransition:
            return "App Backgrounded"
        case .sessionDeactivated:
            return "Session Deactivated"
        case .mediaServicesReset:
            return "Media Services Reset"
        case .unknown:
            return "Unknown Interruption"
        }
    }
}

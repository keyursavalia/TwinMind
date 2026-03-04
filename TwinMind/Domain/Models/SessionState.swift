//
//  SessionState.swift
//  TwinMind
//
//  Purpose: Represents the overall state of a recording session entity in SwiftData.
//  Design decision: Separate from RecordingState to distinguish between
//  the live engine state and the persisted session state.
//

import Foundation

/// The persisted state of a recording session.
///
/// This enum represents the lifecycle state of a session entity in SwiftData,
/// from active recording through completion or failure. Unlike `RecordingState`,
/// this type is optimized for persistence and querying.
public enum SessionState: String, Sendable, Equatable, Codable, Comparable {

    /// Session is currently recording or paused.
    case active

    /// Session is paused by user action.
    case paused

    /// Session recording has completed successfully.
    case completed

    /// Session recording failed and was terminated.
    case failed

    /// Session was cancelled by the user before completion.
    case cancelled

    /// Comparable conformance for sorting.
    /// Order: active < paused < completed < cancelled < failed
    public static func < (lhs: SessionState, rhs: SessionState) -> Bool {
        let order: [SessionState] = [.active, .paused, .completed, .cancelled, .failed]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Computed Properties

extension SessionState {

    /// Whether the session is in a terminal state.
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .active, .paused:
            return false
        }
    }

    /// Whether the session can be resumed.
    public var canResume: Bool {
        switch self {
        case .paused:
            return true
        case .active, .completed, .failed, .cancelled:
            return false
        }
    }

    /// Whether the session can be stopped.
    public var canStop: Bool {
        switch self {
        case .active, .paused:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }

    /// A user-facing display string for the session state.
    public var displayString: String {
        switch self {
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    /// Icon name for the session state (SF Symbols).
    public var iconName: String {
        switch self {
        case .active:
            return "record.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "stop.circle.fill"
        }
    }
}

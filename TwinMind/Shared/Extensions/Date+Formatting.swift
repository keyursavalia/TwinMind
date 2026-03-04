//
//  Date+Formatting.swift
//  TwinMind
//
//  Purpose: Date formatting utilities for consistent display across the app.
//  Design decision: Centralized formatters improve performance (reuse) and
//  ensure consistent date/time presentation in the UI.
//

import Foundation

// MARK: - Date Extension

extension Date {

    // MARK: - Relative Formatting

    /// Formats the date as a relative string (e.g., "Today", "Yesterday", "2 days ago").
    public var relativeString: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(self) {
            return "Tomorrow"
        }

        let components = calendar.dateComponents([.day], from: self, to: now)
        if let days = components.day {
            if days > 0 && days < 7 {
                return "\(days) day\(days == 1 ? "" : "s") ago"
            } else if days < 0 && days > -7 {
                return "In \(abs(days)) day\(abs(days) == 1 ? "" : "s")"
            }
        }

        return formattedDate
    }

    /// Formats the date for grouping in lists (e.g., "Today", "Mar 4, 2026").
    public var groupingString: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }

        return formattedDate
    }

    // MARK: - Standard Formatting

    /// Formats the date as "Mar 4, 2026".
    public var formattedDate: String {
        DateFormatters.dateFormatter.string(from: self)
    }

    /// Formats the time as "2:30 PM".
    public var formattedTime: String {
        DateFormatters.timeFormatter.string(from: self)
    }

    /// Formats the date and time as "Mar 4, 2026 at 2:30 PM".
    public var formattedDateTime: String {
        DateFormatters.dateTimeFormatter.string(from: self)
    }

    /// Formats the date as "March 4, 2026".
    public var formattedDateLong: String {
        DateFormatters.dateLongFormatter.string(from: self)
    }

    /// Formats the date and time as "March 4, 2026 at 2:30:45 PM".
    public var formattedDateTimeLong: String {
        DateFormatters.dateTimeLongFormatter.string(from: self)
    }

    // MARK: - ISO 8601 Formatting

    /// Formats the date as ISO 8601 string (e.g., "2026-03-04T14:30:00Z").
    public var iso8601String: String {
        DateFormatters.iso8601Formatter.string(from: self)
    }

    /// Creates a date from an ISO 8601 string.
    ///
    /// - Parameter iso8601String: The ISO 8601 formatted string.
    /// - Returns: A Date instance, or nil if parsing fails.
    public static func from(iso8601String: String) -> Date? {
        return DateFormatters.iso8601Formatter.date(from: iso8601String)
    }

    // MARK: - Component Helpers

    /// Returns the hour component (0-23).
    public var hour: Int {
        Calendar.current.component(.hour, from: self)
    }

    /// Returns the minute component (0-59).
    public var minute: Int {
        Calendar.current.component(.minute, from: self)
    }

    /// Returns the second component (0-59).
    public var second: Int {
        Calendar.current.component(.second, from: self)
    }

    /// Returns the day component.
    public var day: Int {
        Calendar.current.component(.day, from: self)
    }

    /// Returns the month component (1-12).
    public var month: Int {
        Calendar.current.component(.month, from: self)
    }

    /// Returns the year component.
    public var year: Int {
        Calendar.current.component(.year, from: self)
    }

    // MARK: - Time Ago

    /// Returns a human-readable "time ago" string (e.g., "5 minutes ago", "2 hours ago").
    public var timeAgo: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: self,
            to: now
        )

        if let years = components.year, years > 0 {
            return "\(years) year\(years == 1 ? "" : "s") ago"
        } else if let months = components.month, months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") ago"
        } else if let days = components.day, days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if let seconds = components.second, seconds > 0 {
            return "\(seconds) second\(seconds == 1 ? "" : "s") ago"
        }

        return "Just now"
    }
}

// MARK: - Date Formatters

/// Shared date formatters for performance optimization.
private enum DateFormatters {

    /// Medium date formatter (Mar 4, 2026).
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Short time formatter (2:30 PM).
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Date and time formatter (Mar 4, 2026 at 2:30 PM).
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Long date formatter (March 4, 2026).
    static let dateLongFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    /// Long date and time formatter (March 4, 2026 at 2:30:45 PM).
    static let dateTimeLongFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }()

    /// ISO 8601 formatter.
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

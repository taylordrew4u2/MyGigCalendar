//
//  Show+Extensions.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import Foundation
import CoreData

// MARK: - Convenience Accessors
/// These computed properties provide safe, non-optional access to Show
/// attributes, making SwiftUI bindings and display code cleaner.

extension Show {
    var titleOrEmpty: String   { title ?? "" }
    var venueOrEmpty: String   { venue ?? "" }
    var dateOrNow: Date        { date ?? Date() }

    /// Formatted date string like "Sat, Mar 15 · 8:00 PM"
    var dateFormatted: String {
        let d = dateOrNow
        return "\(Self.dayFormatter.string(from: d)) · \(Self.timeFormatter.string(from: d))"
    }

    /// Short relative date label, e.g. "Tomorrow", "In 3 days"
    var relativeDateLabel: String {
        let calendar = Calendar.current
        let now = Date()
        let d = dateOrNow
        if calendar.isDateInToday(d) { return "Today" }
        if calendar.isDateInTomorrow(d) { return "Tomorrow" }
        let days = calendar.dateComponents([.day], from: now, to: d).day ?? 0
        if days > 0 && days <= 7 { return "In \(days) days" }
        return ""
    }

    // MARK: - Shared Formatters
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}

//
//  ShowEditorSupport.swift
//  SEE ME LIVE
//
//  Value logic behind the show editor and the Siri "Open Add Gig" handoff.
//  Kept free of SwiftUI/Core Data so it can be unit tested directly.
//

import Foundation

// MARK: - Show Draft

/// Every field the editor lets the user change, captured as one value so the
/// form can be snapshotted once and compared as a whole.
struct ShowDraft: Equatable {
    var title: String
    var venue: String
    var date: Date
    var addToCalendar: Bool
    var setReminder: Bool
    var flyerImageData: Data?

    /// Default draft for a brand-new show: next week at 8 PM, added to Calendar.
    static func newShow(now: Date = Date(), calendar: Calendar = .current) -> ShowDraft {
        let eightPM = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        let date = calendar.date(byAdding: .day, value: 7, to: eightPM) ?? eightPM
        return ShowDraft(title: "", venue: "", date: date,
                         addToCalendar: true, setReminder: false, flyerImageData: nil)
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedVenue: String { venue.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// True when saving would persist something different from `baseline`.
    /// Leading/trailing whitespace is ignored because save trims it.
    func hasChanges(from baseline: ShowDraft) -> Bool {
        trimmedTitle != baseline.trimmedTitle ||
        trimmedVenue != baseline.trimmedVenue ||
        date != baseline.date ||
        addToCalendar != baseline.addToCalendar ||
        setReminder != baseline.setReminder ||
        flyerImageData != baseline.flyerImageData
    }

    /// Fills the draft with details read from a flyer. Title and venue only
    /// replace empty fields; the date only replaces the one the user had when
    /// the import started, so an edit made while OCR ran is kept.
    func applyingExtracted(title extractedTitle: String?,
                           venue extractedVenue: String?,
                           date extractedDate: Date?,
                           dateAtImportStart: Date) -> ShowDraft {
        var result = self
        if trimmedTitle.isEmpty, let extractedTitle {
            result.title = extractedTitle
        }
        if trimmedVenue.isEmpty, let extractedVenue {
            result.venue = extractedVenue
        }
        if let extractedDate, date == dateAtImportStart {
            result.date = extractedDate
        }
        return result
    }
}

// MARK: - Add Gig Handoff

/// A pending "Open Add Gig" request. Requests coalesce, and a request stays
/// pending until the UI is able to present the editor.
struct AddGigHandoffQueue {
    private(set) var isPending = false

    mutating func request() {
        isPending = true
    }

    /// Returns true (and clears the request) only when one is pending and the
    /// caller can present the editor now.
    mutating func take(canPresent: Bool) -> Bool {
        guard isPending, canPresent else { return false }
        isPending = false
        return true
    }
}

// MARK: - Flyer Import Generation

/// Identifies the current flyer import so a superseded or removed import can
/// never apply its results after an `await`.
struct FlyerImportGeneration {
    private(set) var current = 0

    /// Starts a new import and returns its token.
    mutating func begin() -> Int {
        current &+= 1
        return current
    }

    /// Invalidates any in-flight import (e.g. the flyer was removed).
    mutating func invalidate() {
        current &+= 1
    }

    func isCurrent(_ token: Int) -> Bool {
        token == current
    }
}

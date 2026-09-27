//
//  CalendarService.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import EventKit
import UIKit

// MARK: - Calendar Service
/// Manages EventKit calendar events: create, update, and delete.
/// Stores the EKEvent identifier back in the Core Data `Show` so it can
/// be updated or removed later.

@MainActor
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    private let calendarIDKey = "seeMeLiveCalendarID"
    private let appCalendarTitle = "My Gig Calendar"
    private let appCalendarColor = UIColor(hex: "#EB2429")

    private init() {}

    // MARK: - Authorization

    /// Current authorization status for full-access calendar.
    nonisolated var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Requests full-access calendar permission. Returns true if granted.
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            print("⚠️ Calendar access request failed: \(error)")
            return false
        }
    }

    // MARK: - Create / Update

    /// Creates or updates a calendar event for the given show.
    /// - Returns: The EKEvent identifier, or nil on failure.
    @discardableResult
    func createOrUpdateEvent(for show: Show) -> String? {
        do {
            return try saveEvent(existingIdentifier: show.calendarEventID,
                                 title: show.title ?? "Show",
                                 venue: show.venue,
                                 date: show.date ?? Date(),
                                 setReminder: show.setReminder)
        } catch {
            print("⚠️ Failed to save calendar event: \(error)")
            return nil
        }
    }

    /// Creates or updates a calendar event from plain values.
    /// - Returns: The saved event's identifier.
    /// - Throws: If calendar access is missing or EventKit rejects the save.
    func saveEvent(existingIdentifier: String?,
                   title: String,
                   venue: String?,
                   date: Date,
                   setReminder: Bool) throws -> String {
        guard isAuthorized else { throw CalendarServiceError.notAuthorized }

        let event: EKEvent
        if let existingIdentifier,
           let existing = store.event(withIdentifier: existingIdentifier) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
        }

        if let calendar = getOrCreateAppCalendar() {
            event.calendar = calendar
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }

        // Populate event fields.
        event.title = title.isEmpty ? "Show" : title
        event.location = venue
        event.startDate = date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 2, to: date) ?? date

        event.notes = nil

        // Reminder alarm (1 hour before).
        event.alarms?.forEach { event.removeAlarm($0) }
        if setReminder {
            event.addAlarm(EKAlarm(relativeOffset: -3600))
        }

        try store.save(event, span: .thisEvent)
        guard let identifier = event.eventIdentifier else {
            throw CalendarServiceError.missingIdentifier
        }
        return identifier
    }

    // MARK: - Delete

    /// Deletes the calendar event associated with the given show.
    func deleteEvent(for show: Show) {
        guard isAuthorized, let eventID = show.calendarEventID else { return }
        do {
            try removeEvent(identifier: eventID)
        } catch {
            print("⚠️ Failed to delete calendar event: \(error)")
        }
    }

    /// Removes the event with the given identifier. An event that no longer
    /// exists counts as removed.
    /// - Throws: If calendar access is missing or EventKit rejects the removal.
    func removeEvent(identifier: String) throws {
        guard isAuthorized else { throw CalendarServiceError.notAuthorized }
        guard let event = store.event(withIdentifier: identifier) else { return }
        try store.remove(event, span: .thisEvent)
    }

    /// Gets the app calendar (creating it if needed) so events share one dot color.
    private func getOrCreateAppCalendar() -> EKCalendar? {
        if let savedID = UserDefaults.standard.string(forKey: calendarIDKey),
           let existing = store.calendar(withIdentifier: savedID) {
            return existing
        }

        if let existing = store.calendars(for: .event).first(where: { $0.title == appCalendarTitle }) {
            UserDefaults.standard.set(existing.calendarIdentifier, forKey: calendarIDKey)
            return existing
        }

        guard let source = preferredCalendarSource() else { return nil }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = appCalendarTitle
        calendar.source = source
        calendar.cgColor = appCalendarColor.cgColor

        do {
            try store.saveCalendar(calendar, commit: true)
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIDKey)
            return calendar
        } catch {
            print("⚠️ Failed to create app calendar: \(error)")
            return nil
        }
    }

    private func preferredCalendarSource() -> EKSource? {
        if let icloud = store.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            return icloud
        }
        if let local = store.sources.first(where: { $0.sourceType == .local }) {
            return local
        }
        return store.defaultCalendarForNewEvents?.source
    }
}

// MARK: - Errors

enum CalendarServiceError: LocalizedError {
    case notAuthorized
    case missingIdentifier

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access is not enabled."
        case .missingIdentifier:
            return "Calendar did not return an event identifier."
        }
    }
}

// MARK: - UIColor hex init

private extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(red:   CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8)  & 0xFF) / 255,
                  blue:  CGFloat( rgb        & 0xFF) / 255,
                  alpha: 1)
    }
}

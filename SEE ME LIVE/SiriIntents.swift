//
//  SiriIntents.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 9/8/26.
//

import AppIntents
import CoreData
import Foundation

struct AddGigIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Gig"
    static var description = IntentDescription("Adds a gig to My Gig Calendar.")
    static var openAppWhenRun = false
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) on \(\.$date)") {
            \.$venue
        }
    }

    @Parameter(title: "Show Title")
    var title: String

    @Parameter(title: "Venue")
    var venue: String?

    @Parameter(title: "Date and Time")
    var date: Date

    init() {}

    init(title: String, venue: String?, date: Date) {
        self.title = title
        self.venue = venue
        self.date = date
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .result(dialog: "Tell me the show title first.")
        }

        let trimmedVenue = venue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let objectID = try await GigIntentStore.createShow(
            title: trimmedTitle,
            venue: trimmedVenue,
            date: date
        )

        await GigIntentStore.syncPublicShow(objectID: objectID)
        await GigIntentStore.addCalendarEventIfAuthorized(objectID: objectID)

        let place = trimmedVenue.isEmpty ? "" : " at \(trimmedVenue)"
        return .result(dialog: "Added \(trimmedTitle)\(place) to My Gig Calendar.")
    }
}

struct OpenAddGigIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Add Gig"
    static var description = IntentDescription("Opens My Gig Calendar so you can add a gig.")
    static var openAppWhenRun = true
    static var parameterSummary: some ParameterSummary {
        Summary("Open Add Gig")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await AppIntentHandoffCenter.shared.requestAddGig()
        return .result(dialog: "Opening My Gig Calendar.")
    }
}

struct ShowUpcomingGigsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Upcoming Gigs"
    static var description = IntentDescription("Shows the next few gigs in My Gig Calendar.")
    static var openAppWhenRun = false
    static var parameterSummary: some ParameterSummary {
        Summary("Show Upcoming Gigs")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shows = try await GigIntentStore.upcomingShows(limit: 5)
        guard !shows.isEmpty else {
            return .result(dialog: "You do not have any upcoming gigs in My Gig Calendar.")
        }

        let summary = shows
            .map { "\($0.title) on \($0.dateText)\($0.venueText)" }
            .joined(separator: ". ")

        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

struct SeeMeLiveShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .red

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddGigIntent(),
            phrases: [
                "Add a gig in \(.applicationName)",
                "Add a show to \(.applicationName)"
            ],
            shortTitle: "Add Gig",
            systemImageName: "calendar.badge.plus"
        )

        AppShortcut(
            intent: OpenAddGigIntent(),
            phrases: [
                "Open add gig in \(.applicationName)",
                "Create a gig in \(.applicationName)"
            ],
            shortTitle: "Open Add Gig",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: ShowUpcomingGigsIntent(),
            phrases: [
                "Show my gigs in \(.applicationName)",
                "What gigs are next in \(.applicationName)"
            ],
            shortTitle: "Upcoming Gigs",
            systemImageName: "calendar"
        )
    }
}

@MainActor
final class AppIntentHandoffCenter {
    static let shared = AppIntentHandoffCenter()
    static let addGigRequestedNotification = Notification.Name("AppIntentHandoffCenter.addGigRequested")

    private var shouldPresentAddGig = false

    private init() {}

    func requestAddGig() {
        shouldPresentAddGig = true
        NotificationCenter.default.post(name: Self.addGigRequestedNotification, object: nil)
    }

    func consumeAddGigRequest() -> Bool {
        guard shouldPresentAddGig else { return false }
        shouldPresentAddGig = false
        return true
    }
}

private enum GigIntentStore {
    struct UpcomingShow {
        let title: String
        let venueText: String
        let dateText: String
    }

    static func createShow(title: String, venue: String, date: Date) async throws -> NSManagedObjectID {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        let userID = await UserIdentityService.shared.userID

        return try await context.perform {
            let now = Date()
            let show = Show(context: context)
            show.title = title
            show.venue = venue
            show.date = date
            show.role = ""
            show.price = 0
            show.ticketLink = ""
            show.notes = ""
            show.flyerImageData = nil
            show.addToCalendar = true
            show.setReminder = false
            show.userID = userID
            show.needsPublicSync = true
            show.pendingPublicDelete = false
            show.createdAt = now
            show.updatedAt = now

            try context.save()
            return show.objectID
        }
    }

    static func syncPublicShow(objectID: NSManagedObjectID) async {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        await PublicCloudSyncService.shared.saveOrUpdate(objectID: objectID, in: context)
    }

    @MainActor
    static func addCalendarEventIfAuthorized(objectID: NSManagedObjectID) async {
        guard CalendarService.shared.isAuthorized else { return }

        let context = PersistenceController.shared.container.viewContext
        guard let show = try? context.existingObject(with: objectID) as? Show else { return }

        show.calendarEventID = CalendarService.shared.createOrUpdateEvent(for: show)
        PersistenceController.shared.save(context: context)
    }

    static func upcomingShows(limit: Int) async throws -> [UpcomingShow] {
        let context = PersistenceController.shared.container.newBackgroundContext()

        return try await context.perform {
            let request = Show.fetchRequest()
            request.fetchLimit = limit
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Show.date, ascending: true)]
            request.predicate = NSPredicate(format: "date >= %@", Date() as NSDate)

            let shows = try context.fetch(request)
            return shows.map { show in
                let venue = show.venueOrEmpty.trimmingCharacters(in: .whitespacesAndNewlines)
                return UpcomingShow(
                    title: show.titleOrEmpty.isEmpty ? "Untitled show" : show.titleOrEmpty,
                    venueText: venue.isEmpty ? "" : " at \(venue)",
                    dateText: dateFormatter.string(from: show.dateOrNow)
                )
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

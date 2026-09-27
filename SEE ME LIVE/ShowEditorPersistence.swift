//
//  ShowEditorPersistence.swift
//  SEE ME LIVE
//
//  The editor's local-save boundary. Writes happen on an isolated context so a
//  failed save never leaves half-applied edits in the view context, and errors
//  are thrown to the caller instead of being logged and ignored.
//

import CoreData

enum ShowEditorSaveError: LocalizedError, Equatable {
    case emptyTitle
    case showNoLongerExists

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Enter a show title to save."
        case .showNoLongerExists:
            return "This gig was deleted on another device, so your changes couldn't be saved."
        }
    }
}

enum ShowEditorPersistence {
    struct SaveResult {
        let objectID: NSManagedObjectID
        let isNew: Bool
        /// The calendar event identifier currently stored for the show.
        let calendarEventID: String?
    }

    /// A private-queue context that writes straight to the store. The view
    /// context picks the changes up via `automaticallyMergesChangesFromParent`.
    static func makeContext(for container: NSPersistentContainer) -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Creates or updates a show from `draft` and saves it. On failure the
    /// context is rolled back and the error is rethrown; nothing is persisted.
    static func save(_ draft: ShowDraft,
                     editing objectID: NSManagedObjectID?,
                     userID: String,
                     in context: NSManagedObjectContext,
                     now: Date = Date()) throws -> SaveResult {
        let title = draft.trimmedTitle
        guard !title.isEmpty else { throw ShowEditorSaveError.emptyTitle }

        return try context.performAndWait {
            do {
                let show: Show
                if let objectID {
                    guard let existing = try? context.existingObject(with: objectID) as? Show,
                          !existing.isDeleted else {
                        throw ShowEditorSaveError.showNoLongerExists
                    }
                    show = existing
                } else {
                    show = Show(context: context)
                    // Legacy fields are no longer editable in the UI. Initialize
                    // them only for new shows so editing never destroys data
                    // saved by older versions.
                    show.role = ""
                    show.price = 0
                    show.ticketLink = ""
                    show.notes = ""
                    show.pendingPublicDelete = false
                    show.createdAt = now
                }

                show.title = title
                show.venue = draft.trimmedVenue
                show.date = draft.date
                show.flyerImageData = draft.flyerImageData
                show.addToCalendar = draft.addToCalendar
                show.setReminder = draft.setReminder
                show.userID = userID
                show.updatedAt = now
                show.needsPublicSync = true

                if context.hasChanges {
                    try context.save()
                }
                return SaveResult(objectID: show.objectID,
                                  isNew: objectID == nil,
                                  calendarEventID: show.calendarEventID)
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    /// Stores (or clears) the calendar event identifier for a saved show.
    static func setCalendarEventID(_ eventID: String?,
                                   for objectID: NSManagedObjectID,
                                   in context: NSManagedObjectContext) throws {
        try context.performAndWait {
            do {
                guard let show = try? context.existingObject(with: objectID) as? Show,
                      !show.isDeleted else {
                    throw ShowEditorSaveError.showNoLongerExists
                }
                guard show.calendarEventID != eventID else { return }
                show.calendarEventID = eventID
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }
}

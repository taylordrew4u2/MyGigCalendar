//
//  Persistence.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import CoreData
import CloudKit

// MARK: - Persistence Controller
/// Manages the Core Data stack using NSPersistentCloudKitContainer for
/// automatic private-database sync via iCloud.

struct PersistenceController {
    static let shared = PersistenceController()

    /// In-memory store used for SwiftUI previews and unit tests.
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let ctx = result.container.viewContext
        let now = Date()
        for i in 0..<5 {
            let show = Show(context: ctx)
            show.title = "Sample Show \(i + 1)"
            show.venue = "Venue \(i + 1)"
            show.date = Calendar.current.date(byAdding: .day, value: i, to: now)!
            show.userID = "preview-user"
            show.addToCalendar = true
            show.setReminder = false
            show.needsPublicSync = false
            show.pendingPublicDelete = false
            show.createdAt = now
            show.updatedAt = now
        }
        try? ctx.save()
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "SEE_ME_LIVE")

        if inMemory {
            if let description = container.persistentStoreDescriptions.first {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber,
                                  forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber,
                                  forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            if !inMemory && !CloudAccountStatus.isLikelyAvailableSynchronously {
                description.cloudKitContainerOptions = nil
                print("iCloud unavailable — local-only mode")
            }
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, surface this error to the user instead of crashing.
                fatalError("Core Data store failed to load: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save Helper
    /// Saves the given context if it has changes. Logs errors rather than crashing.
    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("⚠️ Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }
}

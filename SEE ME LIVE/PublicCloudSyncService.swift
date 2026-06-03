//
//  PublicCloudSyncService.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import CloudKit
import CoreData

// MARK: - Public Cloud Sync Service
/// Syncs shows to the CloudKit **public** database so anyone can read them
/// via the public web calendar. Core Data + NSPersistentCloudKitContainer
/// handles the *private* database automatically; this service handles only
/// the public copy.
///
/// Offline strategy: when a save/update/delete fails, the show is flagged
/// (`needsPublicSync` or `pendingPublicDelete`) and retried the next time
/// `flushQueue(using:)` is called (e.g. on app launch or when the scene
/// becomes active).

final class PublicCloudSyncService: Sendable {
    static let shared = PublicCloudSyncService()

    private let publicDB = CKContainer.default().publicCloudDatabase
    private let recordType = "PublicShow"
    private let deleteQueueKey = "com.seemelive.pendingPublicDeletes"

    private init() {}

    // MARK: - Account Check

    private func isCloudKitAvailable() async -> Bool {
        await CloudAccountStatus.isAvailable()
    }

    func startSyncIfAvailable(using context: NSManagedObjectContext) async {
        guard await isCloudKitAvailable() else {
            print("iCloud unavailable — skipping public sync")
            return
        }
        await flushQueue(using: context)
    }

    // MARK: - Pending Delete Storage (MainActor-isolated)
    
    /// Read pending delete IDs from UserDefaults on the main actor.
    @MainActor
    private func getPendingDeleteIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: deleteQueueKey) ?? []
    }
    
    /// Write pending delete IDs to UserDefaults on the main actor.
    @MainActor
    private func setPendingDeleteIDs(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: deleteQueueKey)
    }

    // MARK: - Save / Update

    /// Saves or updates a PublicShow record for the given Core Data Show object ID.
    func saveOrUpdate(objectID: NSManagedObjectID, in context: NSManagedObjectContext) async {
        guard await isCloudKitAvailable() else {
            await context.perform {
                if let s = try? context.existingObject(with: objectID) as? Show {
                    s.needsPublicSync = true
                    s.lastPublicSyncError = "iCloud account unavailable"
                    PersistenceController.shared.save(context: context)
                }
            }
            return
        }

        struct ShowSnapshot {
            let title: String
            let venue: String
            let date: Date
            let userID: String
            let publicRecordID: String?
        }

        guard let snapshot: ShowSnapshot = await context.perform({
            guard let s = try? context.existingObject(with: objectID) as? Show else { return nil }
            return ShowSnapshot(
                title: s.title ?? "",
                venue: s.venue ?? "",
                date: s.date ?? Date(),
                userID: s.userID ?? "",
                publicRecordID: s.publicRecordID
            )
        }) else { return }

        let record: CKRecord

        if let existingID = snapshot.publicRecordID {
            let ckRecordID = CKRecord.ID(recordName: existingID)
            do {
                record = try await publicDB.record(for: ckRecordID)
            } catch {
                record = CKRecord(recordType: recordType)
            }
        } else {
            record = CKRecord(recordType: recordType)
        }

        // Populate fields from snapshot (no managed-object access).
        record["title"]      = snapshot.title as CKRecordValue
        record["venue"]      = snapshot.venue as CKRecordValue
        record["date"]       = snapshot.date as CKRecordValue
        record["userID"]     = snapshot.userID as CKRecordValue
        record["role"]       = nil
        record["price"]      = nil
        record["ticketLink"] = nil
        record["notes"]      = nil
        record["flyer"]      = nil

        do {
            let saved = try await publicDB.save(record)
            let recordName = saved.recordID.recordName
            await context.perform {
                if let showInContext = try? context.existingObject(with: objectID) as? Show {
                    showInContext.publicRecordID = recordName
                    showInContext.needsPublicSync = false
                    showInContext.lastPublicSyncError = nil
                    PersistenceController.shared.save(context: context)
                }
            }
        } catch {
            let errorDescription = error.localizedDescription
            await context.perform {
                if let showInContext = try? context.existingObject(with: objectID) as? Show {
                    showInContext.needsPublicSync = true
                    showInContext.lastPublicSyncError = errorDescription
                    PersistenceController.shared.save(context: context)
                }
            }
            print("⚠️ Public CloudKit save failed: \(error)")
        }
    }

    // MARK: - Delete

    /// Marks a show for public deletion. Call before removing from Core Data.
    @MainActor
    func markForDelete(show: Show) {
        guard let recordID = show.publicRecordID else { return }
        var queue = getPendingDeleteIDs()
        queue.append(recordID)
        setPendingDeleteIDs(queue)
    }

    /// Deletes a single public record by ID.
    private func deleteRecord(id: String) async throws {
        let ckID = CKRecord.ID(recordName: id)
        try await publicDB.deleteRecord(withID: ckID)
    }

    // MARK: - Offline Queue

    /// Flushes any pending saves or deletes that failed while offline.
    func flushQueue(using context: NSManagedObjectContext) async {
        guard await isCloudKitAvailable() else { return }

        // 1. Retry pending saves — fetch objectIDs inside context.perform
        //    to avoid accessing managed objects outside their queue.
        let pendingIDs: [NSManagedObjectID] = await context.perform {
            let fetchRequest: NSFetchRequest<Show> = Show.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "needsPublicSync == YES")
            let results = (try? context.fetch(fetchRequest)) ?? []
            return results.map { $0.objectID }
        }
        for objectID in pendingIDs {
            await saveOrUpdate(objectID: objectID, in: context)
        }

        // 2. Retry pending deletes stored in UserDefaults.
        // Access UserDefaults on MainActor to avoid concurrency issues.
        let ids = await getPendingDeleteIDs()
        var failedIDs: [String] = []
        for id in ids {
            do {
                try await deleteRecord(id: id)
            } catch {
                failedIDs.append(id)
                print("⚠️ Public CloudKit delete retry failed for \(id): \(error)")
            }
        }
        await setPendingDeleteIDs(failedIDs)
    }
}

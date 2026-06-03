//
//  CloudAccountStatus.swift
//  SEE ME LIVE
//
//  Single source of truth for "is iCloud available?" so the Core Data store
//  setup and the public CloudKit sync service can't drift apart.
//
//  Two entry points exist on purpose:
//
//  • `isLikelyAvailableSynchronously` — used while configuring the persistent
//    store, which happens synchronously during launch before an async account
//    lookup can complete. `ubiquityIdentityToken` is the best signal we can
//    read without awaiting.
//
//  • `isAvailable()` — the authoritative CloudKit account check, used by
//    runtime sync paths that can await.
//

import CloudKit
import Foundation

enum CloudAccountStatus {

    /// Synchronous best-effort signal for store-setup time. Non-nil whenever
    /// the user is signed into iCloud and ubiquity is reachable.
    static var isLikelyAvailableSynchronously: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Authoritative CloudKit account check. Use from async runtime paths.
    static func isAvailable() async -> Bool {
        do {
            return try await CKContainer.default().accountStatus() == .available
        } catch {
            return false
        }
    }
}

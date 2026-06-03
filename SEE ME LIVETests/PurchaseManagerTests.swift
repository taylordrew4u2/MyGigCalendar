//
//  PurchaseManagerTests.swift
//  SEE ME LIVETests
//
//  StoreKit coverage for the Remove Watermark purchase flow.
//

import StoreKitTest
import XCTest
@testable import SEE_ME_LIVE

@MainActor
final class PurchaseManagerTests: XCTestCase {
    private var session: SKTestSession!
    private let cachedUnlockKey = "purchase.removeWatermark.cachedUnlocked"

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "SEE_ME_LIVE")
        session.disableDialogs = true
        session.clearTransactions()
        UserDefaults.standard.removeObject(forKey: cachedUnlockKey)
    }

    override func tearDownWithError() throws {
        session.clearTransactions()
        session = nil
        UserDefaults.standard.removeObject(forKey: cachedUnlockKey)
    }

    func testLoadProducts_loadsRemoveWatermarkProduct() async {
        let manager = PurchaseManager()

        await manager.loadProducts()

        XCTAssertEqual(manager.removeWatermarkProduct?.id, PurchaseManager.removeWatermarkProductID)
        XCTAssertFalse(manager.hasRemovedWatermark)
    }

    func testPurchaseRemoveWatermark_unlocksAndCachesAccess() async {
        let manager = PurchaseManager()
        await manager.loadProducts()

        await manager.purchaseRemoveWatermark()

        XCTAssertTrue(manager.hasRemovedWatermark)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: cachedUnlockKey))
    }

    func testRestorePurchases_unlocksExistingTransaction() async throws {
        let manager = PurchaseManager()
        try await session.buyProduct(identifier: PurchaseManager.removeWatermarkProductID, options: [])

        await manager.restorePurchases()

        XCTAssertTrue(manager.hasRemovedWatermark)
        XCTAssertEqual(manager.statusMessage, "Purchase restored.")
    }

    func testPendingPurchase_doesNotUnlock() async {
        let manager = PurchaseManager()
        session.askToBuyEnabled = true
        await manager.loadProducts()

        await manager.purchaseRemoveWatermark()

        XCTAssertFalse(manager.hasRemovedWatermark)
        XCTAssertTrue(manager.isPurchasePending)
        XCTAssertEqual(manager.statusMessage, "Purchase is pending approval.")
    }
}

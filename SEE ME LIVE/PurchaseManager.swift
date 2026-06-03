//
//  PurchaseManager.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 5/9/26.
//

import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let removeWatermarkProductID = "comedy.SEEMELIVE.remove_watermark"
    private static let cachedRemoveWatermarkKey = "purchase.removeWatermark.cachedUnlocked"

    @Published private(set) var hasRemovedWatermark: Bool
    @Published private(set) var removeWatermarkProduct: Product?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isPurchasePending = false
    @Published private(set) var statusMessage: String?

    var removeWatermarkPriceText: String? {
        removeWatermarkProduct?.displayPrice
    }

    var canRetryProductLoad: Bool {
        !isLoadingProducts && removeWatermarkProduct == nil
    }

    private var transactionUpdatesTask: Task<Void, Never>?

    /// Internal (not private) so tests can create isolated instances instead of
    /// mutating the shared singleton; production code should use `.shared`.
    init() {
        hasRemovedWatermark = UserDefaults.standard.bool(forKey: Self.cachedRemoveWatermarkKey)
        transactionUpdatesTask = Task { [weak self] in
            for await verificationResult in Transaction.updates {
                await self?.handleTransactionUpdate(verificationResult)
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func prepareForLaunch() async {
        await checkCurrentEntitlements()
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }

        statusMessage = nil
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: [Self.removeWatermarkProductID])
            removeWatermarkProduct = products.first { $0.id == Self.removeWatermarkProductID }
            if removeWatermarkProduct == nil {
                statusMessage = "Remove Watermark is unavailable."
            }
        } catch {
            removeWatermarkProduct = nil
            statusMessage = "Remove Watermark is unavailable."
            Self.logStoreKitError(error, context: "loadProducts")
        }

        await checkCurrentEntitlements()
    }

    func purchaseRemoveWatermark() async {
        statusMessage = nil
        isPurchasePending = false

        if removeWatermarkProduct == nil {
            await loadProducts()
        }

        guard let product = removeWatermarkProduct else {
            statusMessage = "Remove Watermark is unavailable."
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                guard case .verified(let transaction) = verificationResult else {
                    updateRemoveWatermarkAccess(false)
                    statusMessage = "Purchase could not be verified."
                    return
                }

                guard transaction.productID == Self.removeWatermarkProductID else {
                    await transaction.finish()
                    await checkCurrentEntitlements()
                    return
                }

                isPurchasePending = false
                updateRemoveWatermarkAccess(transaction.revocationDate == nil)
                await transaction.finish()
                await checkCurrentEntitlements()
                statusMessage = hasRemovedWatermark ? "Watermark removed." : nil

            case .userCancelled:
                isPurchasePending = false
                break

            case .pending:
                isPurchasePending = true
                statusMessage = "Purchase is pending approval."

            @unknown default:
                await checkCurrentEntitlements()
            }
        } catch {
            statusMessage = "Purchase failed. Please try again."
            Self.logStoreKitError(error, context: "purchaseRemoveWatermark")
            await checkCurrentEntitlements()
        }
    }

    func restorePurchases() async {
        statusMessage = nil
        isPurchasePending = false

        do {
            try await AppStore.sync()
            // A successful sync is authoritative: if no entitlement is present
            // the user genuinely does not own it, so allow re-locking here.
            await checkCurrentEntitlements(revokeIfMissing: true)
            statusMessage = hasRemovedWatermark ? "Purchase restored." : "No Remove Watermark purchase found."
        } catch {
            // Sync failed (e.g. offline) — do not revoke a cached unlock.
            await checkCurrentEntitlements()
            statusMessage = "Restore failed. Please try again."
            Self.logStoreKitError(error, context: "restorePurchases")
        }
    }

    func checkCurrentEntitlements(revokeIfMissing: Bool = false) async {
        var ownsRemoveWatermark = false
        var sawRevokedRemoveWatermark = false

        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else {
                continue
            }
            guard transaction.productID == Self.removeWatermarkProductID else {
                continue
            }

            if transaction.revocationDate == nil {
                ownsRemoveWatermark = true
                break
            } else {
                sawRevokedRemoveWatermark = true
            }
        }

        if ownsRemoveWatermark {
            isPurchasePending = false
            updateRemoveWatermarkAccess(true)
            return
        }

        // No active entitlement found. Only re-lock when we have a definitive
        // signal — an explicit revocation, or a caller that expects authoritative
        // data (restore). Otherwise keep the cached unlock so a paying user is
        // not re-locked by a transiently empty entitlement set (e.g. a cold
        // launch before StoreKit has finished syncing).
        if sawRevokedRemoveWatermark || revokeIfMissing {
            updateRemoveWatermarkAccess(false)
        }
    }

    private func handleTransactionUpdate(_ verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else {
            await checkCurrentEntitlements()
            return
        }

        if transaction.productID == Self.removeWatermarkProductID {
            await transaction.finish()
            await checkCurrentEntitlements()
        }
    }

    private func updateRemoveWatermarkAccess(_ isUnlocked: Bool) {
        hasRemovedWatermark = isUnlocked
        UserDefaults.standard.set(isUnlocked, forKey: Self.cachedRemoveWatermarkKey)
    }

    private static func logStoreKitError(_ error: Error, context: String) {
        #if DEBUG
        print("StoreKit \(context) error: \(error)")
        #endif
    }
}

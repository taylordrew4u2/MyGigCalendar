//
//  PurchaseManager.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 5/9/26.
//

import Foundation
import Combine
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let removeWatermarkProductID = "comedy.SEEMELIVE.remove_watermark"

    @Published private(set) var hasRemovedWatermark = false
    @Published private(set) var removeWatermarkProduct: Product?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var statusMessage: String?

    var removeWatermarkPriceText: String? {
        removeWatermarkProduct?.displayPrice
    }

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        transactionUpdatesTask = Task { [weak self] in
            for await verificationResult in Transaction.updates {
                await self?.handleTransactionUpdate(verificationResult)
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProducts() async {
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
        }

        await checkCurrentEntitlements()
    }

    func purchaseRemoveWatermark() async {
        statusMessage = nil

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
                    hasRemovedWatermark = false
                    statusMessage = "Purchase could not be verified."
                    return
                }

                guard transaction.productID == Self.removeWatermarkProductID else {
                    await transaction.finish()
                    await checkCurrentEntitlements()
                    return
                }

                hasRemovedWatermark = transaction.revocationDate == nil
                await transaction.finish()
                await checkCurrentEntitlements()
                statusMessage = hasRemovedWatermark ? "Watermark removed." : nil

            case .userCancelled:
                break

            case .pending:
                statusMessage = "Purchase is pending approval."

            @unknown default:
                await checkCurrentEntitlements()
            }
        } catch {
            statusMessage = "Purchase failed. Please try again."
            await checkCurrentEntitlements()
        }
    }

    func restorePurchases() async {
        statusMessage = nil

        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
            statusMessage = hasRemovedWatermark ? "Purchase restored." : "No Remove Watermark purchase found."
        } catch {
            await checkCurrentEntitlements()
            statusMessage = "Restore failed. Please try again."
        }
    }

    func checkCurrentEntitlements() async {
        var ownsRemoveWatermark = false

        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else {
                continue
            }

            if transaction.productID == Self.removeWatermarkProductID,
               transaction.revocationDate == nil {
                ownsRemoveWatermark = true
                break
            }
        }

        hasRemovedWatermark = ownsRemoveWatermark
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
}

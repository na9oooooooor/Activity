import Foundation
import Observation
import StoreKit

enum EnoughProductID:
    String,
    CaseIterable,
    Sendable {

    case monthly =
        "com.nas.Activityapp.plus.monthly"

    case yearly =
        "com.nas.Activityapp.plus.yearly"

    case lifetime =
        "com.nas.Activityapp.plus.lifetime"

    var sortOrder: Int {
        switch self {
        case .yearly:
            return 0

        case .monthly:
            return 1

        case .lifetime:
            return 2
        }
    }
}

private enum PurchaseError:
    LocalizedError {

    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "The App Store could not verify this purchase."
        }
    }
}

@MainActor
@Observable
final class PurchaseManager {
    private(set) var products: [Product] = []

    private(set) var purchasedProductIDs:
        Set<String> = []

    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    private var transactionUpdatesTask:
        Task<Void, Never>?

    var hasPlusAccess: Bool {
        !purchasedProductIDs.isDisjoint(
            with: Set(
                EnoughProductID.allCases.map(\.rawValue)
            )
        )
    }

    init() {
        transactionUpdatesTask =
            observeTransactionUpdates()
    }


    func prepare() async {
        await refreshEntitlements()
        await loadProducts()
    }

    func product(
        for identifier: EnoughProductID
    ) -> Product? {
        products.first {
            $0.id == identifier.rawValue
        }
    }

    func purchase(
        _ product: Product
    ) async -> Bool {
        guard !isPurchasing else {
            return false
        }

        isPurchasing = true
        errorMessage = nil

        defer {
            isPurchasing = false
        }

        do {
            let result =
                try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction =
                    try Self.verified(
                        verification
                    )

                await transaction.finish()
                await refreshEntitlements()

                return hasPlusAccess

            case .pending:
                return false

            case .userCancelled:
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage =
                error.localizedDescription

            return false
        }
    }

    func restorePurchases() async {
        errorMessage = nil

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var activeProductIDs:
            Set<String> = []

        let plusProductIDs =
            Set(
                EnoughProductID.allCases.map(
                    \.rawValue
                )
            )

        for await result
        in Transaction.currentEntitlements {

            guard case .verified(
                let transaction
            ) = result else {
                continue
            }

            guard plusProductIDs.contains(
                transaction.productID
            ) else {
                continue
            }

            activeProductIDs.insert(
                transaction.productID
            )
        }

        purchasedProductIDs =
            activeProductIDs
    }

    private func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil

        defer {
            isLoadingProducts = false
        }

        do {
            let loadedProducts =
                try await Product.products(
                    for:
                        EnoughProductID
                        .allCases
                        .map(\.rawValue)
                )

            products =
                loadedProducts.sorted {
                    let firstOrder =
                        EnoughProductID(
                            rawValue: $0.id
                        )?.sortOrder ?? 100

                    let secondOrder =
                        EnoughProductID(
                            rawValue: $1.id
                        )?.sortOrder ?? 100

                    return firstOrder
                        < secondOrder
                }
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func observeTransactionUpdates()
        -> Task<Void, Never> {

        Task { [weak self] in
            for await result
            in Transaction.updates {

                guard !Task.isCancelled
                else {
                    return
                }

                do {
                    let transaction =
                        try Self.verified(
                            result
                        )

                    await transaction.finish()
                    await self?
                        .refreshEntitlements()
                } catch {
                    self?.errorMessage =
                        error.localizedDescription
                }
            }
        }
    }

    private static func verified<T: Sendable>(
        _ result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .verified(let value):
            return value

        case .unverified:
            throw PurchaseError
                .failedVerification
        }
    }
}

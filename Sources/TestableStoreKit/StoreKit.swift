import Dependencies
import StoreKit
import XCTestDynamicOverlay
import Yumi

public struct SubscriptionStatus: Equatable {
    public var subscriptionGroupID: String
    public var productID: String
    public var autoRenewProductID: String?
    public var state: RenewalState
    public var expirationDate: Date?
    public var revocationDate: Date?
    public var revocationReason: Transaction.RevocationReason?
    public var gracePeriodExpirationDate: Date?

    public init(
        subscriptionGroupID: String,
        productID: String,
        state: Product.SubscriptionInfo.RenewalState
    ) {
        self.subscriptionGroupID = subscriptionGroupID
        self.productID = productID
        self.state = state
    }

    public init?(_ value: Product.SubscriptionInfo.Status) {
        guard case .verified(let renewalInfo) = value.renewalInfo,
              case .verified(let transaction) = value.transaction,
              let groupID = transaction.subscriptionGroupID
        else { return nil }

        subscriptionGroupID = groupID
        productID = transaction.productID
        autoRenewProductID = renewalInfo.autoRenewPreference
        state = value.state
        expirationDate = transaction.expirationDate
        revocationDate = transaction.revocationDate
        revocationReason = transaction.revocationReason
        gracePeriodExpirationDate = renewalInfo.gracePeriodExpirationDate
    }
}

extension SubscriptionStatus {
    public typealias RenewalState = Product.SubscriptionInfo.RenewalState
}

public struct SubscriptionPeriod: Equatable {
    public typealias Unit = Product.SubscriptionPeriod.Unit

    public var value: Int
    public var unit: Unit

    public init(value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }

    public init(_ value: Product.SubscriptionPeriod) {
        self.unit = value.unit
        self.value = value.value
    }

    public static var aMonth = SubscriptionPeriod(value: 1, unit: .month)
    public static var aYear = SubscriptionPeriod(value: 1, unit: .year)
}

public struct SubscriptionPrice: Equatable {
    public var displayPrice: String
    public var price: Decimal
    public var period: SubscriptionPeriod

    public init(displayPrice: String, price: Decimal, period: SubscriptionPeriod) {
        self.displayPrice = displayPrice
        self.price = price
        self.period = period
    }
}

public struct SubscriptionProduct: Equatable, Identifiable {
    public var id: String
    public var subscriptionGroupID: String
    public var price: SubscriptionPrice
    public var freeTrial: SubscriptionPrice?

    @AlwaysEqual
    public var liveValue: Any?

    public init(
        id: String,
        subscriptionGroupID: String,
        price: SubscriptionPrice,
        freeTrial: SubscriptionPrice? = nil
    ) {
        self.id = id
        self.subscriptionGroupID = subscriptionGroupID
        self.price = price
        self.freeTrial = freeTrial
    }

    public init?(_ value: Product) {
        guard let subscription = value.subscription
        else { return nil }

        id = value.id
        subscriptionGroupID = subscription.subscriptionGroupID
        price = .init(
            displayPrice: value.displayPrice,
            price: value.price,
            period: .init(subscription.subscriptionPeriod))

        if let introductoryOffer = subscription.introductoryOffer,
              introductoryOffer.paymentMode == .freeTrial
        {
            freeTrial = .init(
                displayPrice: introductoryOffer.displayPrice,
                price: introductoryOffer.price,
                period: .init(subscription.subscriptionPeriod))
        }

        liveValue = value
    }
}

public enum PurchaseError: Error {
    case userCancelled
    case pending
    case unknown
}

public protocol StoreKitClient {
    func isEligibleForIntroOffer(_ product: SubscriptionProduct) async -> Bool
    func purchase(_ product: SubscriptionProduct) async throws -> SubscriptionStatus

    func status(forSubscriptionWithGroupID subscriptionGroupID: String) async throws -> SubscriptionStatus?
    func statusUpdates(forSubscriptionWithGroupID subscriptionGroupID: String) -> AsyncStream<SubscriptionStatus>
    func products(withIDs productIDs: [String]) async throws -> [String: SubscriptionProduct]
    func approveTransactionUpdates() async
}

struct LiveStoreKitClient: StoreKitClient {
    func isEligibleForIntroOffer(_ product: SubscriptionProduct) async -> Bool {
        let product = product.liveValue as! Product
        return await product.subscription!.isEligibleForIntroOffer
    }

    func purchase(_ product: SubscriptionProduct) async throws -> SubscriptionStatus {
        let liveProduct = product.liveValue as! Product
        let result = try await liveProduct.purchase()
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            guard let rawStatus = try? await Product.SubscriptionInfo.status(for: product.subscriptionGroupID).first,
                  let status = SubscriptionStatus(rawStatus)
            else {
                throw PurchaseError.unknown
            }

            return status
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        default:
            throw PurchaseError.unknown
        }
    }

    func status(forSubscriptionWithGroupID subscriptionGroupID: String) async throws -> SubscriptionStatus? {
        try await Product.SubscriptionInfo.status(for: subscriptionGroupID)
            .first
            .flatMap { SubscriptionStatus($0) }
    }

    func statusUpdates(forSubscriptionWithGroupID subscriptionGroupID: String) -> AsyncStream<SubscriptionStatus> {
        Product.SubscriptionInfo.Status.updates
            .compactMap { update in
                guard let status = SubscriptionStatus(update),
                      status.subscriptionGroupID == subscriptionGroupID
                else { return nil }
                return status
            }
            .eraseToStream()
    }

    func products(withIDs productIDs: [String]) async throws -> [String: SubscriptionProduct] {
        [:]
    }

    func approveTransactionUpdates() async {
        // During Xcode Testing, auto-renewed yet expired subscriptions betweeen app launches
        // will be marked as unfinished in the testing window. They will not be yielded by
        // Transaction.updates until the subscription is renewed again. I tried to use
        // Transaction.unfinished to get those expired subscriptions, but it does not actually
        // work. I will keep this just for some assurance.
        for await update in Transaction.unfinished {
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
        }
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
        }
    }
}

public extension StoreKitClient {
    func isEligibleForIntroOffer(_ product: SubscriptionProduct) async -> Bool {
        XCTFail("Unimplemented: isEligibleForIntroOffer(_:)")
        return false
    }

    func purchase(_ product: SubscriptionProduct) async throws -> SubscriptionStatus {
        let thunk: () throws -> SubscriptionStatus = unimplemented("purchase(_:)")
        return try thunk()
    }

    func status(forSubscriptionWithGroupID subscriptionGroupID: String) async throws -> SubscriptionStatus? {
        let thunk: () throws -> SubscriptionStatus? = unimplemented("status(forSubscriptionWithGroupID:)")
        return try thunk()
    }

    func statusUpdates(forSubscriptionWithGroupID subscriptionGroupID: String) -> AsyncStream<SubscriptionStatus> {
        AsyncStream {
            XCTFail("Unimplemented: statusUpdates(forSubscriptionWithGroupID:)")
            return nil
        }
    }

    func products(withIDs productIDs: [String]) async throws -> [String: SubscriptionProduct] {
        let thunk: () throws -> [String: SubscriptionProduct] = unimplemented("products(withIDs:)")
        return try thunk()
    }

    func approveTransactionUpdates() async {
        XCTFail("Unimplemented: approveTransactionUpdates()")
    }
}

struct DummyStoreKitClient: StoreKitClient {}

extension DependencyValues {
    private enum Key: DependencyKey {
        static var testValue: any StoreKitClient = DummyStoreKitClient()
        static var liveValue: any StoreKitClient = LiveStoreKitClient()
    }

    public var storeKitClient: any StoreKitClient {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}

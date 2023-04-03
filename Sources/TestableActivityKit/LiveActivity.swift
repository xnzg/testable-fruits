#if !targetEnvironment(macCatalyst)
import ActivityKit
import Dependencies
import XCTestDynamicOverlay
import Yumi

@available(iOS 16.1, *)
public struct LiveActivityClient {
    /// A Boolean value that indicates whether your app can start a Live Activity.
    public var areActivitiesEnabled: () -> Bool
    /// An asynchronous sequence you use to observe whether your app can start a Live Activity.
    public var activityEnablementUpdates: () -> AsyncStream<Bool>

    public var typeBearer: any LiveActivityClientTypeBearer

    public func activities<T: ActivityAttributes>(of type: T.Type) -> [Activity<T>] {
        typeBearer.activities(of: type)
    }

    public func request<T: ActivityAttributes>(attributes: T, contentState: T.ContentState) throws -> LiveActivityClient.Activity<T> {
        try typeBearer.request(attributes: attributes, contentState: contentState)
    }

    public init(
        typeBearer: any LiveActivityClientTypeBearer,
        areActivitiesEnabled: @escaping () -> Bool = unimplemented(placeholder: false),
        activityEnablementUpdates: @escaping () -> AsyncStream<Bool> = unimplemented("activityEnablementUpdates")
    ) {
        self.areActivitiesEnabled = areActivitiesEnabled
        self.activityEnablementUpdates = activityEnablementUpdates
        self.typeBearer = typeBearer
    }
}

@available(iOS 16.1, *)
extension DependencyValues {
    private enum Key: DependencyKey {
        static var testValue: LiveActivityClient { .testValue }
        static var liveValue: LiveActivityClient { .liveValue }
    }

    public var liveActivityClient: LiveActivityClient {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}

/// Implementation for generic methods on ``LiveActivityClient``.
@available(iOS 16.1, *)
public protocol LiveActivityClientTypeBearer {
    func activities<T: ActivityAttributes>(of type: T.Type) -> [LiveActivityClient.Activity<T>]
    func request<T: ActivityAttributes>(attributes: T, contentState: T.ContentState) throws -> LiveActivityClient.Activity<T>
}

@available(iOS 16.1, *)
extension LiveActivityClient {
    public struct Activity<Attributes: ActivityAttributes>: Identifiable, Equatable {
        public var id: String
        @AlwaysEqual
        public var activityState: () -> ActivityState
        @AlwaysEqual
        public var attributes: () -> Attributes
        @AlwaysEqual
        public var contentState: () -> Attributes.ContentState
        @AlwaysEqual
        public var updateClosure: (Attributes.ContentState, AlertConfiguration?) async -> Void
        @AlwaysEqual
        public var endClosure: (Attributes.ContentState?, ActivityUIDismissalPolicy) async -> Void

        public init(
            id: String,
            activityState: @escaping () -> ActivityState = unimplemented(placeholder: .ended),
            attributes: @escaping () -> Attributes = { fatalError() },
            contentState: @escaping () -> Attributes.ContentState = { fatalError() },
            updateClosure: @escaping (Attributes.ContentState, AlertConfiguration?) async -> Void = unimplemented("update"),
            endClosure: @escaping (Attributes.ContentState?, ActivityUIDismissalPolicy) async -> Void = unimplemented("end")
        ) {
            self.id = id
            self.activityState = activityState
            self.attributes = attributes
            self.contentState = contentState
            self.updateClosure = updateClosure
            self.endClosure = endClosure
        }

        public func update(using contentState: Attributes.ContentState, alertConfiguration: AlertConfiguration? = nil) async {
            await updateClosure(contentState, alertConfiguration)
        }

        public func end(using contentState: Attributes.ContentState? = nil, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
            await endClosure(contentState, dismissalPolicy)
        }

        fileprivate static func from(_ activity: ActivityKit.Activity<Attributes>) -> Self {
            .init(id: activity.id) {
                activity.activityState
            } attributes: {
                activity.attributes
            } contentState: {
                activity.contentState
            } updateClosure: { attributes, alertConfiguration in
                await activity.update(using: attributes, alertConfiguration: alertConfiguration)
            } endClosure: { attributes, dismissalPolicy in
                await activity.end(using: attributes, dismissalPolicy: dismissalPolicy)
            }
        }
    }
}

@available(iOS 16.1, *)
public extension LiveActivityClientTypeBearer {
    func activities<T: ActivityAttributes>(of type: T.Type) -> [LiveActivityClient.Activity<T>] {
        []
    }

    func request<T: ActivityAttributes>(attributes: T, contentState: T.ContentState) throws -> LiveActivityClient.Activity<T> {
        throw unimplemented()
    }
}

@available(iOS 16.1, *)
extension LiveActivityClient {
    private struct DummyBearer: LiveActivityClientTypeBearer {}

    public static let testValue = LiveActivityClient(typeBearer: DummyBearer())
}

@available(iOS 16.1, *)
extension LiveActivityClient {
    private struct LiveBearer: LiveActivityClientTypeBearer {
        func activities<T>(of type: T.Type) -> [LiveActivityClient.Activity<T>] where T : ActivityAttributes {
            ActivityKit.Activity<T>.activities.map { .from($0) }
        }

        func request<T>(attributes: T, contentState: T.ContentState) throws -> LiveActivityClient.Activity<T> where T : ActivityAttributes {
            let live = try ActivityKit.Activity<T>.request(attributes: attributes, contentState: contentState)
            return .from(live)
        }
    }

    private static let authorizationInfo = ActivityAuthorizationInfo()

    public static let liveValue = LiveActivityClient(typeBearer: LiveBearer()) {
        authorizationInfo.areActivitiesEnabled
    } activityEnablementUpdates: {
        authorizationInfo.activityEnablementUpdates.eraseToStream()
    }
}
#endif

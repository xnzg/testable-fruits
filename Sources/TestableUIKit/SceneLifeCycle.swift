import Combine
import Dependencies
import UIKit
import XCTestDynamicOverlay

public struct SceneLifeCycleClient {
    /// A notification that indicates that UIKit added a scene to your app.
    public var willConnect: () -> AsyncStream<String>
    /// A notification that indicates that UIKit removed a scene from your app.
    public var didDisconnect: () -> AsyncStream<String>
    /// A notification that indicates that a scene is about to begin running in the foreground and become visible to the user.
    public var willEnterForeground: () -> AsyncStream<String>
    /// A notification that indicates that the scene is now onscreen and responding to user events.
    public var didActivate: () -> AsyncStream<String>
    /// A notification that indicates that the scene is about to resign the active state and stop responding to user events.
    public var willDeactivate: () -> AsyncStream<String>
    /// A notification that indicates that the scene is running in the background and is no longer onscreen.
    public var didEnterBackground: () -> AsyncStream<String>

    public init(
        willConnect: @escaping () -> AsyncStream<String> = unimplemented("willConnect"),
        didDisconnect: @escaping () -> AsyncStream<String> = unimplemented("didDisconnect"),
        willEnterForeground: @escaping () -> AsyncStream<String> = unimplemented("willEnterForeground"),
        didActivate: @escaping () -> AsyncStream<String> = unimplemented("didActivate"),
        willDeactivate: @escaping () -> AsyncStream<String> = unimplemented("willDeactivate"),
        didEnterBackground: @escaping () -> AsyncStream<String> = unimplemented("didEnterBackground")
    ) {
        self.willConnect = willConnect
        self.didDisconnect = didDisconnect
        self.willEnterForeground = willEnterForeground
        self.didActivate = didActivate
        self.willDeactivate = willDeactivate
        self.didEnterBackground = didEnterBackground
    }

    public static let testValue = SceneLifeCycleClient()

    public static let liveValue: SceneLifeCycleClient = {
        func update(for notification: NSNotification.Name) -> AsyncStream<String> {
            let publisher: some Publisher<Notification, Never> = NotificationCenter.default.publisher(for: notification)
            return publisher
                .values
                .compactMap {
                    guard let scene = $0.object as? UIScene else { return nil }
                    return scene.session.persistentIdentifier
                }
                .eraseToStream()
        }

        var client = SceneLifeCycleClient()
        client.willConnect = { update(for: UIScene.willConnectNotification) }
        client.didDisconnect = { update(for: UIScene.didDisconnectNotification) }
        client.willEnterForeground = { update(for: UIScene.willEnterForegroundNotification) }
        client.didActivate = { update(for: UIScene.didActivateNotification) }
        client.willDeactivate = { update(for: UIScene.willDeactivateNotification) }
        client.didEnterBackground = { update(for: UIScene.didEnterBackgroundNotification) }

        return client
    }()
}

extension DependencyValues {
    private enum Key: DependencyKey {
        static var testValue = SceneLifeCycleClient.testValue
        static var liveValue = SceneLifeCycleClient.liveValue
    }

    public var sceneLifeCycleClient: SceneLifeCycleClient {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}

// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "testable-fruits",
    platforms: [
        .iOS(.v15),
        .macCatalyst(.v15)
    ],
    products: [
        .library(
            name: "TestableActivityKit",
            targets: [
                "TestableActivityKit",
            ]),
        .library(
            name: "TestableOSLog",
            targets: [
                "TestableOSLog",
            ]),
        .library(
            name: "TestableStoreKit",
            targets: [
                "TestableStoreKit",
            ]),
        .library(
            name: "TestableUIKit",
            targets: [
                "TestableUIKit",
            ]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.2.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.8.4"),
        .package(url: "https://github.com/xnzg/Yumi", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "TestableActivityKit",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                "Yumi",
            ]
        ),
        .target(
            name: "TestableOSLog",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),
        .testTarget(
            name: "TestableOSLogTests",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                "TestableOSLog",
            ]
        ),
        .target(
            name: "TestableStoreKit",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                "Yumi",
            ]
        ),
        .target(
            name: "TestableUIKit",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),
    ]
)

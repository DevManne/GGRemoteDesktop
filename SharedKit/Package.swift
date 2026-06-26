// swift-tools-version: 5.9
import PackageDescription

/// Shared cross-platform logic used by both the macOS host and the iOS client.
///
/// Keeping models, crypto and auth in a package lets both apps depend on a single,
/// independently testable source of truth (see docs/ARCHITECTURE.md).
let package = Package(
    name: "SharedKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "SharedKit", targets: ["SharedKit"])
    ],
    targets: [
        .target(name: "SharedKit"),
        .testTarget(name: "SharedKitTests", dependencies: ["SharedKit"])
    ]
)

// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftAgent",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftAgent",
            targets: ["SwiftAgent"]
        ),
        .executable(
            name: "ContinuousLearner",
            targets: ["ContinuousLearner"]
        ),
        .executable(
            name: "ResearchAssistant",
            targets: ["ResearchAssistant"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftAgent"
        ),
        .testTarget(
            name: "SwiftAgentTests",
            dependencies: ["SwiftAgent"]
        ),
        .executableTarget(
            name: "ContinuousLearner",
            dependencies: ["SwiftAgent"],
            path: "Examples/ContinuousLearner"
        ),
        .executableTarget(
            name: "ResearchAssistant",
            dependencies: ["SwiftAgent"],
            path: "Examples/ResearchAssistant"
        ),
        .executableTarget(
            name: "HITLExample",
            dependencies: ["SwiftAgent"],
            path: "Examples/HITLExample"
        )
    ]
)

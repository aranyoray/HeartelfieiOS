// swift-tools-version: 6.0
import PackageDescription

// Heartelfie — modular Swift package containing all library modules used by the
// `Heartelfie` iOS app target (the app target itself lives in the Xcode project
// generated from `project.yml`). Every module is iOS-first; build via Xcode.
let package = Package(
    name: "Heartelfie",
    defaultLocalization: "en",
platforms: [
.iOS(.v17),
.macOS(.v14)
],
    products: [
        .library(name: "HECore", targets: ["HECore"]),
        .library(name: "HEDesign", targets: ["HEDesign"]),
        .library(name: "HESignal", targets: ["HESignal"]),
        .library(name: "HESensors", targets: ["HESensors"]),
        .library(name: "HEML", targets: ["HEML"]),
        .library(name: "HEPersistence", targets: ["HEPersistence"]),
        .library(name: "HEFeatures", targets: ["HEFeatures"])
    ],
    targets: [
        // MARK: Foundation — shared models, domain types, copy, clinical config.
        .target(
            name: "HECore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: Design system — tokens + reusable SwiftUI components.
        .target(
            name: "HEDesign",
            dependencies: ["HECore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: DSP — filtering, peak detection, SQI, feature extraction.
        .target(
            name: "HESignal",
            dependencies: ["HECore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: Sensors — protocol abstraction + concrete + mock implementations.
        .target(
            name: "HESensors",
            dependencies: ["HECore", "HESignal"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: ML — on-device CoreML wrappers + cloud model client (mockable).
        .target(
            name: "HEML",
            dependencies: ["HECore", "HESignal"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: Persistence — encrypted store + HealthKit bridge + export.
        .target(
            name: "HEPersistence",
            dependencies: ["HECore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: Features — screens, view models, navigation, capture pipeline.
        .target(
            name: "HEFeatures",
            dependencies: [
                "HECore", "HEDesign", "HESignal", "HESensors", "HEML", "HEPersistence"
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: Tests
        .testTarget(
            name: "HECoreTests",
            dependencies: ["HECore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HESignalTests",
            dependencies: ["HESignal", "HECore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)

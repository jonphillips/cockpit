// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "CockpitCore",
  platforms: [.iOS("27.0"), .macOS("26.0")],
  products: [
    .library(name: "CockpitCore", targets: ["CockpitCore"]),
    .executable(name: "JudgmentFixtureHarvest", targets: ["JudgmentFixtureHarvest"]),
    .executable(name: "GmailFixtureToken", targets: ["GmailFixtureToken"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.8.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-structured-queries", from: "0.31.0"),
    .package(path: "../../jon-platform/packages/CloudSyncKit"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "CockpitCore",
      dependencies: [
        .product(name: "CloudSyncKit", package: "CloudSyncKit"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "StructuredQueries", package: "swift-structured-queries"),
      ]
    ),
    .target(name: "JudgmentFixtureSupport"),
    .executableTarget(
      name: "JudgmentFixtureHarvest",
      dependencies: [
        "CockpitCore",
        "JudgmentFixtureSupport",
      ],
      resources: [.copy("Labeler.html")]
    ),
    // A Mac-only OAuth helper (system frameworks only — no CockpitCore/app dependency) that mints a
    // short-lived Gmail access token for the harvest. Never shipped, never on a launch path.
    .executableTarget(name: "GmailFixtureToken"),
    .testTarget(
      name: "CockpitCoreTests",
      dependencies: [
        "CockpitCore",
        "JudgmentFixtureSupport",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ],
      resources: [.copy("Fixtures")]
    ),
  ]
)

// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "CockpitCore",
  platforms: [.iOS("27.0"), .macOS("26.0")],
  products: [
    .library(name: "CockpitCore", targets: ["CockpitCore"]),
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
    .testTarget(
      name: "CockpitCoreTests",
      dependencies: [
        "CockpitCore",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
  ]
)

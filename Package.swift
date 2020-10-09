// swift-tools-version:5.2

import PackageDescription

let package = Package(
  name: "Yagi",
  platforms: [
    .iOS(.v10)
  ],
  products: [
    .library(name: "Yagi", targets: ["Yagi"]),
  ],
  targets: [
    .target(name: "Yagi", path: "Sources"),
  ],
  swiftLanguageVersions: [
    .v5
  ]
)

// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "LocalFileSorter", platforms: [.macOS("26.0")], products: [
    .executable(name: "LocalFileSorter", targets: ["LocalFileSorter"]),
    .executable(name: "SorterCheck", targets: ["SorterCheck"])
], targets: [
    .target(name: "SorterCore"),
    .executableTarget(name: "LocalFileSorter", dependencies: ["SorterCore"]),
    .executableTarget(name: "SorterCheck", dependencies: ["SorterCore"]),
    .executableTarget(name: "SorterTests", dependencies: ["SorterCore"], path: "Tests/SorterCoreTests")
], swiftLanguageModes: [.v5])

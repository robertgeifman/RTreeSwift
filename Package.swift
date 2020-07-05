// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RTreeSwift",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [
        .library(name: "RTreeSwift", targets: ["RTreeSwift"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        .target(
            name: "RTreeIndexImpl",
            path: "Source/RTreeIndexImpl",
            exclude: ["module", "Reference"]),
        .target(
            name: "RTreeSwift",
            dependencies: ["RTreeIndexImpl"],
            path: "Source",
            exclude: ["RTreeIndexImpl", "rtree-unused"]),
    ]
)

// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftRTree",
    products: [
        .library(name: "SwiftRTree", targets: ["SwiftRTree"])
    ],
    targets: [
        .target(
            name: "RTreeIndexImpl",
            path: "Source/RTreeIndexImpl",
            exclude: ["module", "Reference"]),
        .target(
            name: "SwiftRTree",
            dependencies: ["RTreeIndexImpl"],
            path: "Source",
            exclude: ["RTreeIndexImpl"]),
    ]
)

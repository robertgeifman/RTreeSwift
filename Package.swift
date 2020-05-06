// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RTreeSwift",
    products: [
        .library(name: "RTreeSwift", targets: ["RTreeSwift"])
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
            exclude: ["RTreeIndexImpl"]),
    ]
)

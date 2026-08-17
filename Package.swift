// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CatGPT",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CatGPT",
            targets: ["CatGPT"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CatGPT",
            path: "Sources"
        ),
        .testTarget(
            name: "CatGPTTests",
            dependencies: ["CatGPT"],
            path: "Tests/CatGPTTests"
        )
    ]
)

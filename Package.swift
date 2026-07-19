// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CatWatch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CatWatch",
            targets: ["CatWatch"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CatWatch",
            path: "Sources"
        ),
        .testTarget(
            name: "CatWatchTests",
            dependencies: ["CatWatch"],
            path: "Tests/CatWatchTests"
        )
    ]
)

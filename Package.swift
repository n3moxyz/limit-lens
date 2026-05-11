// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LimitLens",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LimitLens", targets: ["LimitLens"])
    ],
    targets: [
        .executableTarget(
            name: "LimitLens",
            path: ".",
            exclude: [
                ".codex",
                ".git",
                "Assets",
                "dist",
                "docs",
                "LICENSE",
                "README.md",
                "script",
                "Tests"
            ],
            sources: [
                "App",
                "Models",
                "Services",
                "Stores",
                "Support",
                "Views"
            ]
        ),
        .testTarget(
            name: "LimitLensTests",
            dependencies: ["LimitLens"],
            path: "Tests/LimitLensTests"
        )
    ]
)

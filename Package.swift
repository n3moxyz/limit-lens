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
                "LICENSE",
                "README.md",
                "script"
            ],
            sources: [
                "App",
                "Models",
                "Services",
                "Stores",
                "Support",
                "Views"
            ]
        )
    ]
)

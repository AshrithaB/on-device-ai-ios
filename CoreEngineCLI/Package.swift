// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CoreEngineCLI",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../CoreEngine")
    ],
    targets: [
        .executableTarget(
            name: "CoreEngineCLI",
            dependencies: [
                .product(name: "CoreEngine", package: "CoreEngine")
            ]
        )
    ]
)

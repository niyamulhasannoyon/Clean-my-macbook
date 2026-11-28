// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TidyMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TidyMacCore",
            targets: ["TidyMacCore"]
        ),
        .executable(
            name: "TidyMac",
            targets: ["TidyMac"]
        )
    ],
    targets: [
        .target(
            name: "TidyMacCore",
            path: "TidyMac",
            exclude: [
                "App",
                "Views",
                "Resources"
            ],
            sources: [
                "Models",
                "Services"
            ]
        ),
        .executableTarget(
            name: "TidyMac",
            dependencies: ["TidyMacCore"],
            path: "TidyMac",
            exclude: [
                "Models",
                "Services",
                "Resources"
            ],
            sources: [
                "App",
                "Views"
            ]
        ),
        .executableTarget(
            name: "UnitTests",
            dependencies: ["TidyMacCore"],
            path: "Tests/UnitTests"
        )
    ]
)

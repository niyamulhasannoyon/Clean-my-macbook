// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TidyMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TidyMac",
            targets: ["TidyMac"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TidyMac",
            path: "TidyMac",
            exclude: [
                "Resources/Info.plist",
                "Resources/Assets.xcassets",
                "Resources/AppIcon.icns",
                "Resources/TidyMac.entitlements",
                "Resources/PrivacyInfo.xcprivacy"
            ]
        ),
        .executableTarget(
            name: "UnitTests",
            path: "Tests/UnitTests"
        )
    ]
)

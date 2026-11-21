// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnixartIOS",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "AnixartIOS", targets: ["AnixartIOS"])
    ],
    targets: [
        .executableTarget(
            name: "AnixartIOS",
            path: "Sources/AnixartIOS"
        )
    ]
)

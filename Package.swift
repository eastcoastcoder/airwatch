// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Airwatch",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Airwatch", targets: ["Airwatch"])
    ],
    targets: [
        .executableTarget(
            name: "Airwatch",
            path: "Sources/Airwatch"
        )
    ]
)

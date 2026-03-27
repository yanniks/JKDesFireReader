// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JKDesFireReader",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "JKDesFireReader", targets: ["JKDesFireReader"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "JKDesFireReader",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            path: "JKDesFireReader/"
        ),
        .testTarget(
            name: "JKDesFireReaderTests",
            dependencies: ["JKDesFireReader"],
            path: "Tests/JKDesFireReaderTests"
        ),
    ]
)

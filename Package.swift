// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "JKDesFireReader",
    platforms: [
        .iOS(.v13)],
    products: [
        .library(name: "JKDesFireReader", targets: ["JKDesFireReader"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "JKDesFireReader",
            dependencies: ["PromiseKit"],
            path: "JKDesFireReader/"
        ),
    ]
)

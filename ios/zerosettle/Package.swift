// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "zerosettle",
    platforms: [
        .iOS("18.0"),
    ],
    products: [
        .library(name: "zerosettle", targets: ["zerosettle"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/zerosettle/ZeroSettleKit.git", from: "1.3.5"),
    ],
    targets: [
        .target(
            name: "zerosettle",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "ZeroSettleKit", package: "ZeroSettleKit"),
            ]
        ),
    ]
)

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
        .package(url: "https://github.com/zerosettle/ZeroSettleKit.git", from: "1.3.6"),
    ],
    targets: [
        .target(
            name: "zerosettle",
            dependencies: [
                .product(name: "ZeroSettleKit", package: "ZeroSettleKit"),
            ]
        ),
    ]
)

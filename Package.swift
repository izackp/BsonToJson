// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "bsonToJson",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)],
    products: [
        .executable(name: "bsonToJson", targets: ["bsonToJson"]),
        .executable(name: "bsonToJsonBatch", targets: ["bsonToJsonBatch"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/orlandos-nl/BSON.git", from: "8.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(name: "bsonToJson",
                dependencies: [
                    .product(name: "BSON", package: "BSON"),
                    .product(name: "ArgumentParser", package: "swift-argument-parser")
                ]),
        .executableTarget(name: "bsonToJsonBatch",
                dependencies: [
                    .product(name: "BSON", package: "BSON"),
                    .product(name: "ArgumentParser", package: "swift-argument-parser")
                ]),
    ]
)

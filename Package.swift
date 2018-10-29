// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DPOS",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/behrang/YamlSwift.git", from: "3.4.3"),
        .package(url: "https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL.git", from: "1.2.0"),
        .package(url: "https://github.com/sdrpa/Then", from: "4.1.2"),
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "DPOS",
            dependencies: [
               "SwiftKueryPostgreSQL",
               "Yaml",
               "Then",
               "Utility"
         ]),
        .testTarget(
            name: "DPOSTests",
            dependencies: ["DPOS"]),
    ]
)

// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftTUI",
    products: [ // <--- products argument first
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftTUI",
            targets: ["SwiftTUI"]
        ),
        .executable(
            name: "swifted",
            targets: ["swifted"]
        )
    ],
    dependencies: [ // <--- then dependencies argument
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftTUI",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                "CNcurses"
            ]
        ),
        .executableTarget(
            name: "swifted",
            dependencies: ["SwiftTUI"],
            path: "Sources/Examples"
        ),
        .testTarget(
            name: "SwiftTUITests",
            dependencies: ["SwiftTUI"]
        ),
        .target(
            name: "CNcurses",
            path: "Sources/CNcurses",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("ncursesw")
            ]
        )
    ]
)

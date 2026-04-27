// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "backDOOM",
    platforms: [
        .macOS(.v26),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "backDOOM", targets: ["backDOOM"])
    ],
    targets: [
        .executableTarget(
            name: "backDOOM",
            resources: [
                .copy("Assets")
            ]
        )
    ]
)

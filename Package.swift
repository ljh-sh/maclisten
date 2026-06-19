// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "maclisten",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "maclisten", targets: ["maclisten"])
    ],
    targets: [
        .executableTarget(
            name: "maclisten",
            path: "Sources",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        )
    ]
)

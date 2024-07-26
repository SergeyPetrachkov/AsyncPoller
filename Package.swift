// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AsyncPoller",
	platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(
            name: "AsyncPoller",
            targets: ["AsyncPoller"]
		),
    ],
    targets: [
        .target(
            name: "AsyncPoller",
			swiftSettings: [
				.swiftLanguageVersion(.v6)
			]
		),
        .testTarget(
            name: "AsyncPollerTests",
            dependencies: ["AsyncPoller"]
        ),
    ]
)

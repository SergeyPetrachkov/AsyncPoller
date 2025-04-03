// swift-tools-version: 6.0

import PackageDescription

let settings: [SwiftSetting] = [.swiftLanguageMode(.v6)]

let package = Package(
	name: "AsyncPoller",
	platforms: [.iOS(.v16), .macOS(.v13)],
	products: [
		.library(
			name: "AsyncPoller",
			targets: ["AsyncPoller"]
		),
	],
	targets: [
		.target(
			name: "AsyncPoller",
			swiftSettings: settings
		),
		.testTarget(
			name: "AsyncPollerTests",
			dependencies: ["AsyncPoller"],
			swiftSettings: settings
		),
	]
)


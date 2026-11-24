// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	
	name: "Arbit",
	
	platforms: [
		.iOS(.v16),
		.macOS(.v13),
		.tvOS(.v15),
		.watchOS(.v8)
	],
	
	products: [ .library( name: "Arbit", targets: ["Arbit"]), ],
	
	targets: [
		.target(name: "Arbit", dependencies: [], exclude: ["Arbit_UnusedFunc.swift"]),
		.executableTarget(name: "Run", dependencies: ["Arbit"], path: "Run"),
		.testTarget(name: "ArbitTests", dependencies: ["Arbit"])
	]
)


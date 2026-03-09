// swift-tools-version: 5.9
import PackageDescription

let package = Package(
	name: "OpenWhisperRegressionTests",
	platforms: [
		.macOS(.v14),
	],
	products: [
		.library(name: "OpenWhisperCore", targets: ["OpenWhisperCore"]),
	],
	targets: [
		.target(
			name: "OpenWhisperCore",
			path: "OpenWhisper",
			exclude: [
				"AppDelegate.swift",
				"AudioDuration.swift",
				"CodeSigningInfo.swift",
				"FnKeyListener.swift",
				"HoldToTalkRecorder.swift",
				"Info.plist",
				"LoginItemManager.swift",
				"OpenAIWhisperTranscriber.swift",
				"OpenWhisperApp.swift",
				"OverlayController.swift",
				"Permissions.swift",
				"Resources",
				"SVGImage.swift",
				"TextInserter.swift",
				"UsageFormat.swift",
				"UsageStore.swift",
				"WaveformView.swift",
			],
			sources: ["FnKeyPressStateMachine.swift"]
		),
		.testTarget(
			name: "OpenWhisperCoreTests",
			dependencies: ["OpenWhisperCore"],
			path: "OpenWhisperTests"
		),
	]
)

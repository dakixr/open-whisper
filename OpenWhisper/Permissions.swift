import ApplicationServices
import AVFoundation

enum AccessibilityPermissions {
	static func isTrusted(prompt: Bool) -> Bool {
		let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
		let options = [promptKey: prompt] as CFDictionary
		return AXIsProcessTrustedWithOptions(options)
	}
}

enum MicrophonePermissions {
	static var status: AVAuthorizationStatus {
		AVCaptureDevice.authorizationStatus(for: .audio)
	}
}


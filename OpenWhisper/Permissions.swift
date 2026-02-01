import ApplicationServices
import AppKit
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

	static func requestIfNeeded() async -> Bool {
		switch status {
		case .authorized:
			return true
		case .notDetermined:
			return await withCheckedContinuation { continuation in
				AVCaptureDevice.requestAccess(for: .audio) { granted in
					continuation.resume(returning: granted)
				}
			}
		default:
			return false
		}
	}
}

enum PrivacySettings {
	static func openMicrophone() {
		open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
	}

	static func openAccessibility() {
		open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
	}

	static func openInputMonitoring() {
		open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
	}

	private static func open(_ raw: String) {
		guard let url = URL(string: raw) else { return }
		NSWorkspace.shared.open(url)
	}
}

import AppKit
import ApplicationServices

final class TextInserter {
	@discardableResult
	func copyToClipboard(_ text: String) -> Bool {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		return pasteboard.setString(text, forType: .string)
	}

	@discardableResult
	func pasteFromClipboard() -> Bool {
		guard isTrustedForAccessibility() else { return false }

		let src = CGEventSource(stateID: .combinedSessionState)
		let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // kVK_ANSI_V
		let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
		vDown?.flags = .maskCommand
		vUp?.flags = .maskCommand

		guard let vDown, let vUp else { return false }
		vDown.post(tap: .cghidEventTap)
		vUp.post(tap: .cghidEventTap)
		return true
	}

	private func isTrustedForAccessibility() -> Bool {
		let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
		let options = [promptKey: true] as CFDictionary
		return AXIsProcessTrustedWithOptions(options)
	}
}

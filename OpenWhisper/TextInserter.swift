import AppKit
import ApplicationServices

final class TextInserter {
	enum InsertResult: Equatable {
		case typed
		case pasted
		case copiedOnly
	}

	@discardableResult
	func copyToClipboard(_ text: String) -> Bool {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		return pasteboard.setString(text, forType: .string)
	}

	func insertTextPreferDirect(_ text: String) -> InsertResult {
		// Accessibility is required for reliable global input injection and for Cmd+V.
		guard AccessibilityPermissions.isTrusted(prompt: false) else {
			_ = copyToClipboard(text)
			return .copiedOnly
		}

		// First try to type directly (doesn't touch clipboard).
		if typeTextViaUnicodeEvent(text) {
			return .typed
		}

		// Fallback to clipboard paste (requires Accessibility).
		let pasted = pasteViaClipboard(text)
		return pasted ? .pasted : .copiedOnly
	}

	private func typeTextViaUnicodeEvent(_ text: String) -> Bool {
		guard let src = CGEventSource(stateID: .combinedSessionState) else { return false }
		var utf16 = Array(text.utf16)
		guard !utf16.isEmpty else { return true }

		guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
			  let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) else { return false }

		utf16.withUnsafeMutableBufferPointer { buf in
			guard let base = buf.baseAddress else { return }
			down.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: base)
			up.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: base)
		}

		down.post(tap: .cgAnnotatedSessionEventTap)
		up.post(tap: .cgAnnotatedSessionEventTap)
		return true
	}

	private func pasteViaClipboard(_ text: String) -> Bool {
		let pasteboard = NSPasteboard.general
		let previousString = pasteboard.string(forType: .string)

		_ = copyToClipboard(text)

		guard let src = CGEventSource(stateID: .combinedSessionState) else {
			restoreClipboard(previousString)
			return false
		}

		let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // kVK_ANSI_V
		let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
		vDown?.flags = .maskCommand
		vUp?.flags = .maskCommand

		guard let vDown, let vUp else {
			restoreClipboard(previousString)
			return false
		}
		vDown.post(tap: .cgAnnotatedSessionEventTap)
		vUp.post(tap: .cgAnnotatedSessionEventTap)

		// Give the target app time to read the pasteboard before restoring.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
			self?.restoreClipboard(previousString)
		}
		return true
	}

	private func restoreClipboard(_ previousString: String?) {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		if let previousString {
			_ = pasteboard.setString(previousString, forType: .string)
		}
	}
}

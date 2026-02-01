import AppKit

final class FnKeyListener {
	private let onPress: () -> Void
	private let onRelease: () -> Void

	private var globalMonitor: Any?
	private var localMonitor: Any?
	private var isPressed = false

	init(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
		self.onPress = onPress
		self.onRelease = onRelease
	}

	func start() {
		stop()

		// Global monitor requires Input Monitoring permission for keyboard events.
		globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
			self?.handle(event: event)
		}

		// Local monitor handles events when the app is focused (useful for debugging).
		localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
			self?.handle(event: event)
			return event
		}
	}

	func stop() {
		if let globalMonitor {
			NSEvent.removeMonitor(globalMonitor)
		}
		if let localMonitor {
			NSEvent.removeMonitor(localMonitor)
		}
		globalMonitor = nil
		localMonitor = nil
	}

	private func handle(event: NSEvent) {
		// Fn key is keyCode 63 on Apple keyboards.
		guard event.type == .flagsChanged, event.keyCode == 63 else { return }

		let pressedNow = event.modifierFlags.contains(.function)
		if pressedNow && !isPressed {
			isPressed = true
			onPress()
		} else if !pressedNow && isPressed {
			isPressed = false
			onRelease()
		}
	}
}

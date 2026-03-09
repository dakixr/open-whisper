import AppKit

final class FnKeyListener {
	private let fnKeyCode = CGKeyCode(63)
	private let onPress: () -> Void
	private let onRelease: () -> Void
	private let currentTimeProvider: () -> TimeInterval
	private let fnKeyPressedProvider: () -> Bool

	private var globalMonitor: Any?
	private var localMonitor: Any?
	private var stateMachine: FnKeyPressStateMachine
	private var pressWorkItem: DispatchWorkItem?
	private var releasePollTimer: DispatchSourceTimer?
	private let debounceSeconds: TimeInterval = 0.2
	private let releasePollInterval: DispatchTimeInterval = .milliseconds(50)

	init(
		onPress: @escaping () -> Void,
		onRelease: @escaping () -> Void,
		currentTimeProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
		fnKeyPressedProvider: @escaping () -> Bool = { NSEvent.modifierFlags.contains(.function) }
	) {
		self.onPress = onPress
		self.onRelease = onRelease
		self.currentTimeProvider = currentTimeProvider
		self.fnKeyPressedProvider = fnKeyPressedProvider
		self.stateMachine = FnKeyPressStateMachine(debounceSeconds: debounceSeconds)
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
		pressWorkItem?.cancel()
		pressWorkItem = nil
		stopReleasePolling()
		stateMachine.reset()

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
		guard event.type == .flagsChanged, event.keyCode == fnKeyCode else { return }

		let pressedNow = event.modifierFlags.contains(.function)
		if pressedNow {
			process(stateMachine.handlePress(at: currentTimeProvider()))

			let work = DispatchWorkItem { [weak self] in
				self?.processPolledState()
			}
			pressWorkItem?.cancel()
			pressWorkItem = work
			DispatchQueue.main.asyncAfter(deadline: .now() + debounceSeconds, execute: work)
		} else {
			process(stateMachine.handleRelease(at: currentTimeProvider()))
		}
	}

	private func startReleasePolling() {
		stopReleasePolling()

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + releasePollInterval, repeating: releasePollInterval)
		timer.setEventHandler { [weak self] in
			self?.processPolledState()
		}
		timer.resume()
		releasePollTimer = timer
	}

	private func stopReleasePolling() {
		releasePollTimer?.cancel()
		releasePollTimer = nil
	}

	private func processPolledState() {
		process(stateMachine.poll(keyIsCurrentlyPressed: fnKeyPressedProvider(), at: currentTimeProvider()))
	}

	private func process(_ actions: [FnKeyPressStateMachine.Action]) {
		for action in actions {
			switch action {
			case .startHold:
				startReleasePolling()
				onPress()
			case .stopHold:
				pressWorkItem?.cancel()
				pressWorkItem = nil
				stopReleasePolling()
				onRelease()
			}
		}
	}
}

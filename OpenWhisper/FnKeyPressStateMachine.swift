import Foundation

struct FnKeyPressStateMachine {
	enum Action: Equatable {
		case startHold
		case stopHold
	}

	private(set) var isPressed = false
	private(set) var didStartHold = false
	private var debounceDeadline: TimeInterval?
	private let debounceSeconds: TimeInterval

	init(debounceSeconds: TimeInterval = 0.2) {
		self.debounceSeconds = debounceSeconds
	}

	mutating func handlePress(at now: TimeInterval) -> [Action] {
		guard !isPressed else { return [] }

		isPressed = true
		didStartHold = false
		debounceDeadline = now + debounceSeconds
		return []
	}

	mutating func handleRelease(at now: TimeInterval) -> [Action] {
		guard isPressed else { return [] }
		return finishPressIfNeeded(at: now, keyIsCurrentlyPressed: false)
	}

	mutating func poll(keyIsCurrentlyPressed: Bool, at now: TimeInterval) -> [Action] {
		if isPressed, !keyIsCurrentlyPressed {
			return finishPressIfNeeded(at: now, keyIsCurrentlyPressed: false)
		}

		guard isPressed, !didStartHold, let debounceDeadline, now >= debounceDeadline else {
			return []
		}

		self.debounceDeadline = nil
		didStartHold = true
		return [.startHold]
	}

	mutating func reset() {
		isPressed = false
		didStartHold = false
		debounceDeadline = nil
	}

	private mutating func finishPressIfNeeded(at now: TimeInterval, keyIsCurrentlyPressed: Bool) -> [Action] {
		_ = now
		_ = keyIsCurrentlyPressed

		guard isPressed else { return [] }

		let shouldStopHold = didStartHold
		reset()
		return shouldStopHold ? [.stopHold] : []
	}
}

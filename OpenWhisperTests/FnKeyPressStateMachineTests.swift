import XCTest
@testable import OpenWhisperCore

final class FnKeyPressStateMachineTests: XCTestCase {
	func testQuickTapDoesNotStartHold() {
		var machine = FnKeyPressStateMachine(debounceSeconds: 0.2)

		XCTAssertEqual(machine.handlePress(at: 0.0), [])
		XCTAssertEqual(machine.poll(keyIsCurrentlyPressed: true, at: 0.1), [])
		XCTAssertEqual(machine.handleRelease(at: 0.1), [])
	}

	func testHoldStartsAfterDebounceAndStopsOnRelease() {
		var machine = FnKeyPressStateMachine(debounceSeconds: 0.2)

		XCTAssertEqual(machine.handlePress(at: 0.0), [])
		XCTAssertEqual(machine.poll(keyIsCurrentlyPressed: true, at: 0.2), [.startHold])
		XCTAssertEqual(machine.handleRelease(at: 0.3), [.stopHold])
	}

	func testMissedReleaseEventStopsOnPoll() {
		var machine = FnKeyPressStateMachine(debounceSeconds: 0.2)

		XCTAssertEqual(machine.handlePress(at: 0.0), [])
		XCTAssertEqual(machine.poll(keyIsCurrentlyPressed: true, at: 0.2), [.startHold])
		XCTAssertEqual(machine.poll(keyIsCurrentlyPressed: false, at: 0.35), [.stopHold])
	}

	func testMissedReleaseBeforeDebounceDoesNotStartHold() {
		var machine = FnKeyPressStateMachine(debounceSeconds: 0.2)

		XCTAssertEqual(machine.handlePress(at: 0.0), [])
		XCTAssertEqual(machine.poll(keyIsCurrentlyPressed: false, at: 0.2), [])
		XCTAssertEqual(machine.poll(keyIsCurrentlyPressed: true, at: 0.25), [])
	}

	func testRepeatedPressWhileHeldDoesNotDuplicateStart() {
		var machine = FnKeyPressStateMachine(debounceSeconds: 0.2)

		XCTAssertEqual(machine.handlePress(at: 0.0), [])
		XCTAssertEqual(machine.handlePress(at: 0.05), [])
		XCTAssertEqual(machine.poll(keyIsCurrentlyPressed: true, at: 0.2), [.startHold])
		XCTAssertEqual(machine.poll(keyIsCurrentlyPressed: true, at: 0.4), [])
	}
}

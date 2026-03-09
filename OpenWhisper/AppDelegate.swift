import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
	private enum SessionState {
		case idle
		case recording
		case transcribing
	}

	private let overlayController = OverlayController()
	private let recorder = HoldToTalkRecorder()
	private let transcriber = OpenAIWhisperTranscriber()
	private let inserter = TextInserter()
	private var fnListener: FnKeyListener?
	@MainActor private var sessionState: SessionState = .idle

	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.accessory)

		// Prompt for Accessibility once (needed for Cmd+V). macOS will handle the one-time approval flow.
		if !AccessibilityPermissions.isTrusted(prompt: false) {
			let key = "didPromptAccessibility"
			if !UserDefaults.standard.bool(forKey: key) {
				_ = AccessibilityPermissions.isTrusted(prompt: true)
				UserDefaults.standard.set(true, forKey: key)
			}
		}

		fnListener = FnKeyListener(
			onPress: { [weak self] in
				Task { @MainActor in
					self?.startHold()
				}
			},
			onRelease: { [weak self] in
				Task { @MainActor in
					self?.stopHold()
				}
			}
		)
		fnListener?.start()
	}

	@MainActor
	private func startHold() {
		guard sessionState == .idle else { return }
		sessionState = .recording

		recorder.onLevelUpdate = { [weak self] level in
			Task { @MainActor in
				guard self?.sessionState == .recording else { return }
				self?.overlayController.update(level: level)
			}
		}
		recorder.onStartError = { [weak self] error in
			Task { @MainActor in
				guard let self, self.sessionState == .recording else { return }
				self.resetSession()
				self.overlayController.show(state: .error(error.localizedDescription))
			}
		}

		overlayController.show(state: .recording)
		recorder.start()
	}

	@MainActor
	private func stopHold() {
		guard sessionState == .recording else { return }
		sessionState = .transcribing
		Task {
			recorder.onLevelUpdate = nil
			recorder.onStartError = nil
			let result = await recorder.stop()
			switch result {
			case .failure(let error):
				await MainActor.run {
					self.resetSession()
					self.overlayController.show(state: .error(error.localizedDescription))
				}
			case .success(let audioURL):
				await MainActor.run {
					self.overlayController.show(state: .transcribing)
				}

				let durationSeconds = await AudioDuration.seconds(for: audioURL)
				let textResult = await self.transcriber.transcribe(fileURL: audioURL)
				switch textResult {
				case .failure(let error):
					if !isMissingKey(error) {
						await MainActor.run {
							UsageStore.shared.recordTranscription(durationSeconds: durationSeconds, succeeded: false)
						}
					}
					await MainActor.run {
						self.resetSession()
						self.overlayController.show(state: .error(error.localizedDescription))
					}
				case .success(let text):
					await MainActor.run {
						UsageStore.shared.recordTranscription(durationSeconds: durationSeconds, succeeded: true)
						self.resetSession()
					}
					let insertResult = self.inserter.insertTextPreferDirect(text)
					await MainActor.run {
						switch insertResult {
						case .typed:
							self.overlayController.show(state: .done(.typed))
						case .pasted:
							self.overlayController.show(state: .done(.pasted))
						case .copiedOnly:
							self.overlayController.show(state: .copiedOnly)
						}
					}
				}
			}
		}
	}

	@MainActor
	private func resetSession() {
		sessionState = .idle
		recorder.onLevelUpdate = nil
		recorder.onStartError = nil
	}

	private func isMissingKey(_ error: Error) -> Bool {
		if let e = error as? OpenAIWhisperTranscriber.TranscribeError, e == .missingAPIKey {
			return true
		}
		return false
	}
}

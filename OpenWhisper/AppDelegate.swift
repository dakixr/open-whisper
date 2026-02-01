import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
	private let overlayController = OverlayController()
	private let recorder = HoldToTalkRecorder()
	private let transcriber = OpenAIWhisperTranscriber()
	private let inserter = TextInserter()
	private var fnListener: FnKeyListener?

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
			onPress: { [weak self] in self?.startHold() },
			onRelease: { [weak self] in self?.stopHold() }
		)
		fnListener?.start()
	}

	private func startHold() {
		recorder.onLevelUpdate = { [weak self] level in
			Task { @MainActor in
				self?.overlayController.update(level: level)
			}
		}
		recorder.onStartError = { [weak self] error in
			Task { @MainActor in
				self?.overlayController.show(state: .error(error.localizedDescription))
			}
		}

		Task { @MainActor in
			overlayController.show(state: .recording)
		}
		recorder.start()
	}

	private func stopHold() {
		Task {
			recorder.onLevelUpdate = nil
			recorder.onStartError = nil
			let result = await recorder.stop()
			switch result {
			case .failure(let error):
				await MainActor.run {
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
						UsageStore.shared.recordTranscription(durationSeconds: durationSeconds, succeeded: false)
					}
					await MainActor.run {
						self.overlayController.show(state: .error(error.localizedDescription))
					}
				case .success(let text):
					UsageStore.shared.recordTranscription(durationSeconds: durationSeconds, succeeded: true)
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

	private func isMissingKey(_ error: Error) -> Bool {
		if let e = error as? OpenAIWhisperTranscriber.TranscribeError, e == .missingAPIKey {
			return true
		}
		return false
	}
}

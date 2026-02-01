import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
	private let overlayController = OverlayController()
	private let recorder = HoldToTalkRecorder()
	private let transcriber = OpenAIWhisperTranscriber()
	private let inserter = TextInserter()
	private var fnListener: FnKeyListener?

	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.accessory)

		fnListener = FnKeyListener(
			onPress: { [weak self] in self?.startHold() },
			onRelease: { [weak self] in self?.stopHold() }
		)
		fnListener?.start()
	}

	private func startHold() {
		Task { @MainActor in
			overlayController.show(state: .recording)
		}
		recorder.start()
	}

	private func stopHold() {
		Task {
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
				let textResult = await self.transcriber.transcribe(fileURL: audioURL)
				switch textResult {
				case .failure(let error):
					await MainActor.run {
						self.overlayController.show(state: .error(error.localizedDescription))
					}
				case .success(let text):
					_ = self.inserter.copyToClipboard(text)
					let pasted = self.inserter.pasteFromClipboard()
					await MainActor.run {
						self.overlayController.show(state: pasted ? .done : .copiedOnly)
					}
				}
			}
		}
	}
}

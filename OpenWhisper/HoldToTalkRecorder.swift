import AVFoundation

final class HoldToTalkRecorder {
	enum RecorderError: Error, LocalizedError {
		case microphoneDenied
		case recorderStartFailed(String)
		case recorderStopFailed

		var errorDescription: String? {
			switch self {
			case .microphoneDenied:
				return "Microphone permission not granted."
			case .recorderStartFailed(let msg):
				return "Failed to start recording: \(msg)"
			case .recorderStopFailed:
				return "Failed to stop recording."
			}
		}
	}

	private var recorder: AVAudioRecorder?
	private var fileURL: URL?

	func start() {
		Task {
			let granted = await requestMicrophoneAccessIfNeeded()
			guard granted else { return }
			do { try startRecording() } catch {
				NSLog("OpenWhisper: \(error.localizedDescription)")
			}
		}
	}

	func stop() async -> Result<URL, Error> {
		guard let recorder else { return .failure(RecorderError.recorderStopFailed) }

		let url = fileURL
		recorder.stop()
		self.recorder = nil
		self.fileURL = nil

		guard let url else { return .failure(RecorderError.recorderStopFailed) }
		return .success(url)
	}

	private func startRecording() throws {
		let tempDir = FileManager.default.temporaryDirectory
		let url = tempDir.appendingPathComponent("openwhisper-\(UUID().uuidString).m4a")

		let settings: [String: Any] = [
			AVFormatIDKey: kAudioFormatMPEG4AAC,
			AVSampleRateKey: 44_100,
			AVNumberOfChannelsKey: 1,
			AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
		]

		let recorder = try AVAudioRecorder(url: url, settings: settings)
		recorder.isMeteringEnabled = false
		recorder.prepareToRecord()

		if !recorder.record() {
			throw RecorderError.recorderStartFailed("record() returned false")
		}

		self.recorder = recorder
		self.fileURL = url
	}

	private func requestMicrophoneAccessIfNeeded() async -> Bool {
		switch AVCaptureDevice.authorizationStatus(for: .audio) {
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


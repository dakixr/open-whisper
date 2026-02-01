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
	private var meterTimer: DispatchSourceTimer?

	var onLevelUpdate: ((Float) -> Void)?

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
		stopMetering()
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
		recorder.isMeteringEnabled = true
		recorder.prepareToRecord()

		if !recorder.record() {
			throw RecorderError.recorderStartFailed("record() returned false")
		}

		self.recorder = recorder
		self.fileURL = url
		startMetering()
	}

	private func startMetering() {
		stopMetering()
		guard let recorder else { return }

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now(), repeating: .milliseconds(50))
		timer.setEventHandler { [weak self] in
			guard let self else { return }
			recorder.updateMeters()

			// averagePower is in dBFS (roughly [-160, 0]).
			let db = recorder.averagePower(forChannel: 0)
			let clamped = max(-60.0, min(0.0, db))
			let normalized = Float((clamped + 60.0) / 60.0) // 0...1

			self.onLevelUpdate?(normalized)
		}
		timer.resume()
		meterTimer = timer
	}

	private func stopMetering() {
		meterTimer?.cancel()
		meterTimer = nil
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

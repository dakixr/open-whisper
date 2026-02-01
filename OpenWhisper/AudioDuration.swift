import AVFoundation
import Foundation

enum AudioDuration {
	static func seconds(for fileURL: URL) async -> Double {
		let asset = AVURLAsset(url: fileURL)
		do {
			let duration = try await asset.load(.duration)
			let seconds = CMTimeGetSeconds(duration)
			if seconds.isFinite && seconds >= 0 { return seconds }
			return 0
		} catch {
			return 0
		}
	}
}

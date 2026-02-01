import AVFoundation
import Foundation

enum AudioDuration {
	static func seconds(for fileURL: URL) -> Double {
		let asset = AVURLAsset(url: fileURL)
		let seconds = CMTimeGetSeconds(asset.duration)
		if seconds.isFinite && seconds >= 0 { return seconds }
		return 0
	}
}


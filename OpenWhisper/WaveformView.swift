import AppKit

final class WaveformView: NSView {
	var barColor: NSColor = .systemRed {
		didSet { needsDisplay = true }
	}

	private var samples: [CGFloat] = Array(repeating: 0.05, count: 14)
	private let maxSamples = 14

	override var isFlipped: Bool { true }

	func push(level: Float) {
		let clamped = max(0.0, min(1.0, level))
		let eased = CGFloat(pow(clamped, 0.65))
		samples.append(eased)
		if samples.count > maxSamples {
			samples.removeFirst(samples.count - maxSamples)
		}
		needsDisplay = true
	}

	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)

		guard let ctx = NSGraphicsContext.current?.cgContext else { return }
		ctx.clear(bounds)

		let count = samples.count
		let gap: CGFloat = 2
		let barWidth: CGFloat = 3
		let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap

		let startX = (bounds.width - totalWidth) / 2.0
		let midY = bounds.height / 2.0
		let minH: CGFloat = 3
		let maxH: CGFloat = bounds.height - 2

		ctx.setFillColor(barColor.withAlphaComponent(0.85).cgColor)

		for (i, s) in samples.enumerated() {
			let h = minH + (maxH - minH) * s
			let x = startX + CGFloat(i) * (barWidth + gap)
			let y = midY - h / 2.0
			let rect = CGRect(x: x, y: y, width: barWidth, height: h)
			let radius = barWidth / 2.0
			let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
			ctx.addPath(path)
			ctx.fillPath()
		}
	}
}


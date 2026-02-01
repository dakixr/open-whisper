import AppKit
import QuartzCore

final class OverlayController {
	enum State: Equatable {
		case recording
		case transcribing
		case done
		case copiedOnly
		case error(String)
	}

	private var window: NSPanel?
	private var textField: NSTextField?
	private var iconView: NSImageView?
	private var waveformView: WaveformView?
	private var dismissTask: Task<Void, Never>?
	private var currentState: State?

	@MainActor
	func update(level: Float) {
		guard currentState == .recording else { return }
		waveformView?.push(level: level)
	}

	@MainActor
	func show(state: State) {
		ensureWindow()
		guard let window, let textField, let iconView, let waveformView else { return }

		dismissTask?.cancel()
		window.alphaValue = 1.0
		currentState = state

		switch state {
		case .recording:
			textField.stringValue = "Listening"
			iconView.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Listening")
			tint(iconView, color: .systemRed)
			waveformView.isHidden = false
			waveformView.barColor = .systemRed
			autoDismiss(after: nil)
		case .transcribing:
			textField.stringValue = "Transcribing"
			iconView.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Transcribing")
			tint(iconView, color: .systemBlue)
			waveformView.isHidden = true
			autoDismiss(after: nil)
		case .done:
			textField.stringValue = "Pasted"
			iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Done")
			tint(iconView, color: .systemGreen)
			waveformView.isHidden = true
			autoDismiss(after: 0.8)
		case .copiedOnly:
			textField.stringValue = "Copied"
			iconView.image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "Copied")
			tint(iconView, color: .systemOrange)
			waveformView.isHidden = true
			autoDismiss(after: 1.2)
		case .error(let message):
			textField.stringValue = "Error"
			iconView.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Error")
			tint(iconView, color: .secondaryLabelColor)
			waveformView.isHidden = true
			autoDismiss(after: 2.0)
			NSLog("OpenWhisper error: \(message)")
		}

		positionWindow(window)
		window.orderFrontRegardless()
		pulse(window)
	}

	@MainActor
	private func ensureWindow() {
		if window != nil { return }

		let panel = NSPanel(
			contentRect: NSRect(x: 0, y: 0, width: 260, height: 42),
			styleMask: [.nonactivatingPanel, .borderless],
			backing: .buffered,
			defer: false
		)
		panel.level = .statusBar
		panel.isFloatingPanel = true
		panel.isOpaque = false
		panel.hasShadow = true
		panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
		panel.backgroundColor = .clear
		panel.ignoresMouseEvents = true

		let visual = NSVisualEffectView()
		visual.material = .hudWindow
		visual.blendingMode = .withinWindow
		visual.state = .active
		visual.wantsLayer = true
		visual.layer?.cornerRadius = 12
		visual.layer?.masksToBounds = true
		panel.contentView = visual

		let icon = NSImageView()
		icon.translatesAutoresizingMaskIntoConstraints = false
		icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
		icon.contentTintColor = .systemRed

			let field = NSTextField(labelWithString: "Listening")
			field.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
			field.textColor = .labelColor
			field.lineBreakMode = .byTruncatingTail
			field.translatesAutoresizingMaskIntoConstraints = false

			let waveform = WaveformView(frame: .zero)
			waveform.translatesAutoresizingMaskIntoConstraints = false
			waveform.barColor = .systemRed
			waveform.isHidden = false

			NSLayoutConstraint.activate([
				waveform.widthAnchor.constraint(equalToConstant: 64),
				waveform.heightAnchor.constraint(equalToConstant: 18),
			])

			let stack = NSStackView(views: [icon, waveform, field])
			stack.orientation = .horizontal
			stack.alignment = .centerY
			stack.spacing = 8
			stack.translatesAutoresizingMaskIntoConstraints = false

		visual.addSubview(stack)

		NSLayoutConstraint.activate([
			icon.widthAnchor.constraint(equalToConstant: 18),
			icon.heightAnchor.constraint(equalToConstant: 18),

			stack.leadingAnchor.constraint(equalTo: visual.leadingAnchor, constant: 12),
			stack.trailingAnchor.constraint(lessThanOrEqualTo: visual.trailingAnchor, constant: -12),
			stack.centerYAnchor.constraint(equalTo: visual.centerYAnchor),
		])

			window = panel
			textField = field
			iconView = icon
			waveformView = waveform
		}

	@MainActor
	private func positionWindow(_ window: NSWindow) {
		guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
		let frame = screen.visibleFrame
		let size = window.frame.size
		let x = frame.midX - size.width / 2
		let y = frame.minY + 72
		window.setFrameOrigin(NSPoint(x: x, y: y))
	}

	@MainActor
	private func autoDismiss(after seconds: TimeInterval?) {
		dismissTask?.cancel()
		guard let seconds else { return }
		dismissTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
			await NSAnimationContext.runAnimationGroup { ctx in
				ctx.duration = 0.18
				ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
				self.window?.animator().alphaValue = 0.0
			}
		}
	}

	@MainActor
	private func tint(_ imageView: NSImageView, color: NSColor) {
		imageView.contentTintColor = color
	}

	@MainActor
	private func pulse(_ window: NSWindow) {
		let original = window.frame
		let bump: CGFloat = 1.03
		let w = original.size.width * bump
		let h = original.size.height * bump
		let dx = (w - original.size.width) / 2
		let dy = (h - original.size.height) / 2
		let bigger = NSRect(x: original.origin.x - dx, y: original.origin.y - dy, width: w, height: h)

		window.setFrame(bigger, display: false)
		NSAnimationContext.runAnimationGroup { ctx in
			ctx.duration = 0.14
			ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
			window.animator().setFrame(original, display: false)
		}
	}
}

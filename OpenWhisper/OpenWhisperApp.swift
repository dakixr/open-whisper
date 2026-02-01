import SwiftUI

@main
struct OpenWhisperApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@State private var usage = UsageStore.shared
	@State private var loginItem = LoginItemManager.shared

	var body: some Scene {
		MenuBarExtra {
			Toggle("Launch at Login", isOn: $loginItem.isEnabled)
			Divider()
			SettingsLink()
			Divider()

			let today = usage.totalsToday
			let all = usage.totalsAllTime
			Text("Today: \(UsageFormat.minutesString(seconds: today.seconds)) • \(UsageFormat.currencyUSD(usage.estimatedCostUSD(for: today)))")
			Text("All time: \(UsageFormat.minutesString(seconds: all.seconds)) • \(UsageFormat.currencyUSD(usage.estimatedCostUSD(for: all)))")
			Text("Rate: \(UsageFormat.currencyUSD(UsagePricing.whisperUSDPerMinute, maxFractionDigits: 3))/min (estimated)")
				.foregroundStyle(.secondary)

			Button("Reset Usage") {
				usage.resetAll()
			}
			Divider()
			Button("Quit") { NSApp.terminate(nil) }
				.keyboardShortcut("q")
		} label: {
			MenuBarIcon()
		}

		Settings {
			SettingsView()
		}
	}
}

private struct MenuBarIcon: View {
	private static let icon: NSImage = {
		(try? SVGImage.templateImage(resource: "menu-icon", size: CGSize(width: 18, height: 18)))
		?? NSImage(systemSymbolName: "waveform", accessibilityDescription: "OpenWhisper")!
	}()

	var body: some View {
		Image(nsImage: Self.icon)
	}
}

private struct SettingsView: View {
	@State private var apiKey: String = ""
	@State private var status: String?
	@State private var loginItem = LoginItemManager.shared
	@State private var permissionStatusMessage: String?

	private var envKeyPresent: Bool {
		let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
		return !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private var keychainKeyPresent: Bool {
		APIKeyStore.shared.hasKeychainKey()
	}

	private var apiKeyConfigured: Bool {
		envKeyPresent || keychainKeyPresent
	}

	private var accessibilityTrusted: Bool {
		AccessibilityPermissions.isTrusted(prompt: false)
	}

	private var microphoneStatus: String {
		switch MicrophonePermissions.status {
		case .authorized:
			return "Allowed"
		case .denied:
			return "Denied"
		case .restricted:
			return "Restricted"
		case .notDetermined:
			return "Not requested"
		@unknown default:
			return "Unknown"
		}
	}

	private var signingInfo: CodeSigningInfo.Info {
		CodeSigningInfo.current()
	}

	private var apiKeySourceLabel: String {
		if envKeyPresent { return "Environment variable (OPENAI_API_KEY)" }
		if keychainKeyPresent { return "Keychain" }
		return "Not configured"
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("OpenWhisper")
				.font(.title2)
			Text("Hold the Fn key to record; release to transcribe and paste.")
				.foregroundStyle(.secondary)
			Text("Requires permissions: Microphone, Input Monitoring, Accessibility.")
				.foregroundStyle(.secondary)

			Toggle("Launch at Login", isOn: $loginItem.isEnabled)
				.toggleStyle(.switch)

			Divider().padding(.vertical, 6)

			Text("OpenAI API Key")
				.font(.headline)

			HStack(spacing: 10) {
				Image(systemName: apiKeyConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
					.foregroundStyle(apiKeyConfigured ? .green : .orange)
				VStack(alignment: .leading, spacing: 2) {
					Text(apiKeyConfigured ? "Configured" : "Not configured")
						.font(.system(size: 13, weight: .semibold))
					Text("Using: \(apiKeySourceLabel)")
						.font(.system(size: 12))
						.foregroundStyle(.secondary)
				}
				Spacer()
			}
			.padding(10)
			.background(.regularMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

			SecureField("sk-…", text: $apiKey)

			HStack(spacing: 10) {
				Button("Save to Keychain") {
					if APIKeyStore.shared.saveKeychainKey(apiKey) {
						apiKey = ""
						status = "Saved. (Environment variable OPENAI_API_KEY, if set, overrides Keychain.)"
					} else {
						status = "Could not save key."
					}
				}
				Button("Clear Keychain Key") {
					_ = APIKeyStore.shared.deleteKeychainKey()
					apiKey = ""
					status = "Cleared."
				}
				.disabled(!APIKeyStore.shared.hasKeychainKey())
				Spacer()
			}

			if let status {
				Text(status).foregroundStyle(.secondary)
			}

			Divider().padding(.vertical, 6)

			Text("Permissions")
				.font(.headline)

				VStack(alignment: .leading, spacing: 8) {
				if signingInfo.isAdHoc {
					HStack(alignment: .top, spacing: 10) {
						Image(systemName: "exclamationmark.triangle.fill")
							.foregroundStyle(.orange)
						VStack(alignment: .leading, spacing: 2) {
							Text("To avoid repeat permission prompts, sign with a Team")
								.font(.system(size: 13, weight: .semibold))
							Text("Xcode → Target → Signing & Capabilities → select your Team. Ad-hoc signing can cause macOS to ask again after rebuilds.")
								.font(.system(size: 12))
								.foregroundStyle(.secondary)
						}
					}
					.padding(.bottom, 2)
				} else if let team = signingInfo.teamIdentifier {
					HStack(spacing: 10) {
						Image(systemName: "checkmark.seal.fill")
							.foregroundStyle(.green)
						Text("Signed (Team \(team))")
							.font(.system(size: 13, weight: .semibold))
						Spacer()
					}
				}

					HStack {
						Image(systemName: microphoneStatus == "Allowed" ? "checkmark.circle.fill" : "mic.slash.fill")
							.foregroundStyle(microphoneStatus == "Allowed" ? .green : .secondary)
						Text("Microphone: \(microphoneStatus)")
							.font(.system(size: 13, weight: .semibold))
						Spacer()
						if microphoneStatus != "Allowed" {
							Button(microphoneStatus == "Not requested" ? "Request…" : "Open…") {
								Task {
									if MicrophonePermissions.status == .notDetermined {
										let granted = await MicrophonePermissions.requestIfNeeded()
										await MainActor.run {
											permissionStatusMessage = granted ? "Microphone permission granted." : "Microphone permission denied."
										}
									} else {
										PrivacySettings.openMicrophone()
									}
								}
							}
						} else {
							Button("Open…") { PrivacySettings.openMicrophone() }
								.foregroundStyle(.secondary)
						}
					}
					HStack {
						Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "hand.raised.slash.fill")
							.foregroundStyle(accessibilityTrusted ? .green : .secondary)
					Text("Accessibility: \(accessibilityTrusted ? "Allowed" : "Not allowed")")
						.font(.system(size: 13, weight: .semibold))
					Spacer()
						if !accessibilityTrusted {
							Button("Request…") {
								_ = AccessibilityPermissions.isTrusted(prompt: true)
							}
						} else {
							Button("Open…") { PrivacySettings.openAccessibility() }
								.foregroundStyle(.secondary)
						}
					}
					HStack {
						Image(systemName: "keyboard")
							.foregroundStyle(.secondary)
						Text("Input Monitoring: Required for Fn hotkey")
							.font(.system(size: 13, weight: .semibold))
						Spacer()
						Button("Open…") { PrivacySettings.openInputMonitoring() }
							.foregroundStyle(.secondary)
					}

					if let permissionStatusMessage {
						Text(permissionStatusMessage)
							.font(.system(size: 12))
							.foregroundStyle(.secondary)
					}
				}
				.padding(10)
				.background(.regularMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

			Text("Tip: If you run from Xcode, set OPENAI_API_KEY in the scheme env vars, or save it to Keychain here.")
				.foregroundStyle(.secondary)
		}
		.padding(16)
		.frame(width: 420)
	}
}

import SwiftUI

@main
struct OpenWhisperApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	var body: some Scene {
		MenuBarExtra {
			SettingsLink()
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

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("OpenWhisper")
				.font(.title2)
			Text("Hold the Fn key to record; release to transcribe and paste.")
				.foregroundStyle(.secondary)
			Text("Requires permissions: Microphone, Input Monitoring, Accessibility.")
				.foregroundStyle(.secondary)

			Divider().padding(.vertical, 6)

			Text("OpenAI API Key")
				.font(.headline)

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

			Text("Tip: If you run from Xcode, set OPENAI_API_KEY in the scheme env vars, or save it to Keychain here.")
				.foregroundStyle(.secondary)
		}
		.padding(16)
		.frame(width: 420)
	}
}

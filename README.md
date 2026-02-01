# OpenWhisper

Hold-to-talk transcription for macOS using the OpenAI Whisper API.

## Usage

Requires macOS 14+ (MenuBarExtra + SettingsLink).

1. Open `OpenWhisper.xcodeproj` in Xcode.
2. Provide an API key (either option):
   - Xcode: Scheme → Run → Arguments → Environment Variables → `OPENAI_API_KEY`
   - Or run the app, then `OW` menu → `Settings…` → “Save to Keychain”
3. Run the app.
4. Grant permissions when prompted:
   - Microphone
   - Input Monitoring (to detect the Fn key globally)
   - Accessibility (to paste into the focused app)

Tip: after granting Input Monitoring / Accessibility, quit and relaunch OpenWhisper.

## Avoid repeat permission prompts

macOS ties privacy permissions to the app’s code signature. If you run with ad-hoc signing (common during development), rebuilding can trigger permission prompts again.

To make permissions “stick”, set a signing Team in Xcode (Target → Signing & Capabilities) and keep the bundle identifier stable (`com.openwhisper.app`).

### Hold-to-talk

- Hold the **Fn** key → overlay shows “Listening…”
- Release **Fn** → audio uploads, transcribes, then pastes into the focused app
- If pasting fails, the result stays in the clipboard

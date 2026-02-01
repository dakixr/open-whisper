# OpenWhisper

Hold-to-talk transcription for macOS using the OpenAI Whisper API.

- Press-and-hold **Fn** → talk → release **Fn** → text is inserted into the focused app
- Menubar app with a small “listening” overlay (with live waveform)
- Tracks daily + all-time usage and estimated cost

## Requirements

- macOS 14+
- OpenAI API key

## Install

### Option A: Download a DMG (recommended)

Go to the GitHub “Releases” page and download the latest `.dmg`, then:

1. Open the DMG
2. Drag `OpenWhisper.app` into `Applications`
3. Launch `OpenWhisper`

### Option B: Build locally (Xcode)

1. Open `OpenWhisper.xcodeproj` in Xcode
2. Run the app

## Setup

### API key

You can provide your API key in either way:

- **In-app (Keychain):** `OW` menu → `Settings…` → paste your key → “Save to Keychain”
- **Environment variable:** `OPENAI_API_KEY` (useful for dev)

Environment variable wins over Keychain if both are set.

### Permissions

OpenWhisper needs these permissions:

- **Microphone**: record audio
- **Input Monitoring**: detect the Fn key globally
- **Accessibility**: paste/type into other apps

Tip: after granting **Input Monitoring** / **Accessibility**, quit and relaunch OpenWhisper.

## Avoid repeat permission prompts

macOS ties privacy permissions to the app’s code signature. If you run with ad-hoc signing (common during development), rebuilding can trigger permission prompts again.

To make permissions “stick”, set a signing Team in Xcode (Target → Signing & Capabilities) and keep the bundle identifier stable (`com.openwhisper.app`).

## Usage

### Hold-to-talk (Fn)

- Hold **Fn** (debounced by 200ms) → overlay shows “Listening”
- Release **Fn** → audio uploads, transcribes, then inserts text into the focused app
- Insert behavior:
  - tries to **type directly** first
  - falls back to **Cmd+V paste**
  - falls back to **clipboard only** if insertion isn’t permitted/possible

### Launch at login

Enable “Launch at Login” from the menubar or Settings.

### Usage + cost tracking

The menubar shows:

- Today: total minutes + estimated cost
- All time: total minutes + estimated cost

Cost is an estimate based on a hardcoded per-minute rate for Whisper; update `OpenWhisper/UsageStore.swift` if pricing changes.

## Development

### Build an app bundle

```bash
./build.sh
```

Output: `dist/OpenWhisper.app`

### Build a DMG locally

```bash
chmod +x scripts/package_dmg.sh
OUT_DIR=dist DMG_NAME=OpenWhisper-local.dmg scripts/package_dmg.sh
```

Output: `dist/OpenWhisper-local.dmg`

## CI / Releases

On every push to `main`, GitHub Actions builds a DMG and creates a GitHub Release containing the DMG.

## Privacy

- Audio is recorded locally and sent to OpenAI for transcription when you release Fn.
- Your API key is stored in macOS Keychain if you use the in-app option.

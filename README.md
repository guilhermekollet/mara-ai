<div align="center">
  <img src="Resources/icon-1024.png" alt="Mara AI" width="96" height="96">

  <h1>Mara AI</h1>

  <p>Live, translated captions for your meetings, right in the macOS menu bar.<br>
  Built for developers who work with teams in other languages.</p>

  <p>
    <a href="https://github.com/guilhermekollet/mara-ai/actions/workflows/ci.yml"><img src="https://github.com/guilhermekollet/mara-ai/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-b8a4f8" alt="MIT license"></a>
    <img src="https://img.shields.io/badge/macOS-26%2B-0d0d0d" alt="macOS 26+">
    <img src="https://img.shields.io/badge/Swift-6.2-F05138" alt="Swift 6.2">
  </p>
</div>

Mara listens to the audio your Mac is already playing — Zoom, Google Meet, Teams, a video in the
browser — transcribes it on-device with Apple's speech recognition and shows a caption in
Portuguese, English or Spanish that forms word by word while people are still talking. No bot joins the call. When the meeting
ends, it summarizes the conversation with AI, using your own OpenAI key.

> **Language note:** the app's interface follows your Mac's language: Portuguese (Brazil), English or
> Spanish, and English on a Mac set to any other language. Code, comments and docs are in English.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [Privacy](#privacy)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Project layout](#project-layout)
- [Contributing](#contributing)
- [License](#license)

## Features

**Meetings in other languages**
- Live captions in a small floating window; scroll back freely, it follows the conversation again
  when you return to the bottom.
- On-device transcription and translation (Apple Speech and Translation): free, private, offline.
  Meetings in English (US), Spanish or Portuguese (Brazil), captioned in any of the three; a
  meeting already in the caption language is transcribed without translating.
- Optional GPT refinement of each finished sentence, with your own OpenAI key.
- A glossary of names and terms, used by speech recognition and by GPT.
- Standby after a stretch without audio, and automatic stop after a longer one.
- Optional microphone, off by default: what you say goes into the transcript labeled as yours
  (untranslated), so the summary knows who said what. Without headphones, the echo of the others
  coming out of the speakers is recognized and dropped. Mara can't see whether you are muted in
  the meeting app, so you turn it on and off yourself (captions window, <kbd>⌃⌥M</kbd> or
  **Ajustes › Geral**).

**AI summary**
- When the meeting ends, GPT tells what was talked about, with your own OpenAI key: whether it was
  a conversation between several people or a presentation, an overview, the topics in order and,
  depending on the kind, the decisions or the key points, plus open questions, written in the
  caption language. Nothing is sent until you ask for it.
- Its own window, with copy, save as Markdown and share; also saved next to the transcript.
- Its own model setting (GPT-6 Luna by default). Long meetings are summarized in parts.

**Everyday details**
- A short introduction on first launch: the audio permission, the meeting language downloaded
  ahead of time and, if you want summaries, your OpenAI key.
- Automatic updates: a new version downloads in the background, is checked against the project's
  signature and installs when you quit Mara (or right away, with **Reiniciar agora**).
- Global shortcuts: <kbd>⌃⌥S</kbd> start/stop, <kbd>⌃⌥L</kbd> show/hide captions,
  <kbd>⌃⌥M</kbd> microphone on/off.
- A usage ledger with every GPT call and its estimated cost.
- Transcripts (plain text) and summaries (Markdown) saved in `~/Documents/Mara AI`.

## Requirements

- macOS 26 (Tahoe) or later.
- To build from source: Swift 6.2 or later — Xcode 26, or the matching Command Line Tools.
- Optional: an [OpenAI API key](https://platform.openai.com/api-keys), for summaries and GPT refinement.

## Getting started

### Download

Get the latest `.zip` from [Releases](https://github.com/guilhermekollet/mara-ai/releases/latest)
(macOS 26 on Apple silicon), unzip it and move **Mara AI** to Applications.

Mara is signed but not notarized: the project has no paid Apple Developer account. The first time
you open it, macOS says it can't verify the developer. Open **System Settings → Privacy &
Security**, scroll down and click **Open Anyway** next to Mara AI. You only do this once: from
0.3.0 on, Mara updates itself, and macOS keeps both this choice and the recording permission.

### Build from source

```bash
git clone https://github.com/guilhermekollet/mara-ai.git
cd mara-ai
scripts/create-signing-cert.sh   # recommended, see "Signing" below
./build.sh
open "build/Mara AI.app"
```

### First run

1. A short introduction opens. It asks for **Screen & System Audio Recording** (macOS then needs
   Mara reopened once, which the introduction does for you), downloads the speech model and
   Apple's translation for the meeting language, and takes your OpenAI key if you want summaries.
2. Mara lives in the menu bar (the dotted "M"). Click it and press **Iniciar**, or use ⌃⌥S.

You can see the introduction again in **Ajustes › Geral**.

### Signing

macOS ties the screen-recording permission to the app's signature. An ad hoc signature changes on
every build, so macOS would ask again each time. `scripts/create-signing-cert.sh` creates a
self-signed certificate in your login keychain, which `build.sh` uses automatically. To use another
identity, set `MARA_SIGNING_IDENTITY`.

## Configuration

Everything lives in **Ajustes** (Settings), opened from the menu bar panel:

| Tab | What you set |
| --- | --- |
| Tradução | Meeting and caption languages, on-device only or Mac + GPT, GPT model |
| Resumo | Summary model and the OpenAI key (also used by the GPT translation) |
| Aparência | Caption size and background opacity, standby and auto-stop timers, sound cues |
| Consumo | GPT usage per session, day, month and in total |
| Glossário | Names and terms the team uses |
| Geral | Automatic updates, your microphone, the global shortcuts, the introduction again |

API keys are stored in the macOS Keychain, never in files.

## Privacy

| Data | Where it goes |
| --- | --- |
| Meeting audio | Stays on your Mac. It is never sent anywhere. |
| Microphone | Off unless you turn it on (macOS asks for the permission the first time). Transcribed on your Mac like the meeting audio; what you said reaches OpenAI only inside a summary you ask for, never in GPT translation. |
| Transcript text | Sent to OpenAI only when GPT refinement is on, or when you ask for a summary. |
| API keys | macOS Keychain. |
| Transcripts and summaries | Text and Markdown files in `~/Documents/Mara AI`. |
| Update checks | Once a day Mara asks GitHub for the latest release; nothing about you or your meetings is sent. Turn it off in **Ajustes › Geral**. |

Mara has no server of its own: requests go straight from your Mac to OpenAI, and to GitHub for
updates.

## Troubleshooting

**macOS says Mara AI can't be opened.** Downloads that aren't notarized are blocked the first time.
Click **Open Anyway** in **System Settings → Privacy & Security**, as in [Download](#download).

**macOS keeps asking for the recording permission, or refuses it.** Reset it and grant it again:

```bash
tccutil reset ScreenCapture com.guilhermekollet.mara-ai
```

Releases up to 0.2.0 were signed ad hoc, so updating from them asks for the permission once more.
From 0.3.0 on, every release is signed with the same certificate and macOS keeps it.

**The menu bar icon doesn't show up.** On MacBooks with a notch, icons that don't fit are hidden
behind it. Remove a few menu bar items (hold <kbd>⌘</kbd> and drag them out) and Mara appears.

**Something went wrong during a meeting.** The current session is logged, with millisecond timings,
in `~/Library/Logs/MaraAI/sessao.log`.

## Development

```bash
swift build                   # debug build
scripts/test.sh               # tests (works with Xcode or with only the Command Line Tools)
./build.sh                    # release build and app bundle
.build/debug/MaraAI --render-summary /tmp/summary.png   # draw the summary window with a sample
```

Useful runtime files:

- `~/Library/Logs/MaraAI/sessao.log` — the current session, step by step.
- `~/Library/Application Support/MaraAI/consumo.jsonl` — every GPT call, one JSON object per line.

The website lives in [`web/`](web/README.md) (Next.js, Tailwind CSS).

### Releasing

Push a version tag and `.github/workflows/release.yml` does the rest: it runs the tests, builds the
app with that version, signs it and publishes a GitHub release with the zip, its SHA-256 checksum
and its update signature.

Two kinds of signing keep updates working, both held as repository secrets:

- `MARA_SIGNING_P12` and `MARA_SIGNING_P12_PASSWORD`: the project's self-signed code-signing
  certificate. Every release carries the same one, so macOS keeps the recording permission across
  updates, and the updater refuses an app signed with anything else.
- `MARA_UPDATE_PRIVATE_KEY`: the Ed25519 key whose public half is in `Updater.swift`. The updater
  installs only a zip with a valid signature from it. Losing it means installed copies can no
  longer update themselves, so keep its backup safe.

```bash
git tag v0.2.0
git push origin v0.2.0
```

`scripts/package-release.sh 0.2.0` builds the same zip locally, in `dist/` (signed ad hoc, without
an update signature, unless the variables above are set).

## Project layout

```
Sources/MaraAI/
  MaraAIApp.swift            App entry point, captions window, menu bar item
  CaptionModel.swift         Session state: capture, transcription, translation, summary
  CaptionLanguage.swift      The languages captions and summaries are written in
  Updater.swift              Automatic updates from GitHub Releases, checked before installing
  TranscriptionSession.swift Apple SpeechAnalyzer pipeline and the standby gate
  SystemAudioCapture.swift   System audio, and the microphone when on, through ScreenCaptureKit
  Microphone.swift           Who spoke, the microphone permission and the echo filter
  Translator.swift           OpenAI calls (refinement, summary) and Keychain helpers
  MeetingSummary.swift       The summary's structure, its JSON schema and Markdown
  SummaryView.swift          Summary window
  MenuBarPanel.swift         Menu bar panel
  SettingsView.swift         Settings window
  OnboardingView.swift       First-launch introduction: permission, language download, OpenAI key
  Localization.swift         Picks the interface language; translations live in Resources/*.lproj
  …                          Theme, icons, animated captions, sound bars, hot keys, usage ledger
Tests/MaraAITests/           Swift Testing suite
scripts/                     Icon generation, signing, test runner, release packaging and update signing
web/                         Website
```

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) to get set up, and the
[Code of Conduct](CODE_OF_CONDUCT.md). Found a security issue? See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © Guilherme Kollet

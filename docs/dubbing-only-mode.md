# Hearing only the dubbing

Study of a mode where the meeting (or a video) goes silent on the speakers while Mara still hears
it, translates it and reads the translation aloud, so the user hears only Mara's voice.

**Verdict: possible, per app, not per browser tab.** Core Audio process taps capture an app's
audio and, with `CATapMuteBehavior.mutedWhenTapped`, keep it from reaching the speakers while
the tap is being read. ScreenCaptureKit, which Mara uses today, can only copy the audio.

## How it was tested

`MaraAI --try-tap <app|pid|all> [seconds] [--unmuted]` (Sources/MaraAI/AudioTap.swift):
- lists the processes Core Audio knows, marking the ones playing now;
- taps the matching processes (or everything but Mara) through a private aggregate device;
- prints each second the level, how many buffers came in all zeros and how late they arrived.

Run it as the app, so macOS credits the capture to Mara and not to the terminal:

```bash
open -n -W --stdout /tmp/tap.log -a "build/Mara AI.app" --args --try-tap afplay 10
```

Measured on macOS 26, MacBook, built-in speakers, 2026-10-17.

## Findings

| Question | Result |
| --- | --- |
| Does the tapped app go silent? | **Yes.** `afplay` reading a count from 1 to 30: silent for the 8 s the muted tap was read, audible again right after (heard by the user). |
| Does the sound come back if Mara dies? | **Yes.** A muted tap whose process was killed with `kill -9`: the sound came back on its own (heard by the user). |
| Does Mara still get the audio while it's muted? | **Yes**, at the same level as unmuted: about −23 to −30 dBFS of speech, no all-zero buffers while it played. |
| Latency from tap to buffer | **~32 ms**, steady (48 kHz stereo, interleaved Float32, ~94 buffers a second). Negligible next to the dubbing's 1–3 s. |
| One browser tab? | **No**, in Chromium or Safari. Two YouTube tabs in a Chromium browser played through a single process, the audio service (`--utility-sub-type=audio.mojom.AudioService`); tapping it captures and mutes every tab of that browser. Chrome, Brave, Dia and Electron apps share this design. Safari is the same, through WebKit's GPU process (below). |
| Safari | **Works, per app.** Two YouTube tabs playing at once had four WebContent processes but one process playing audio, WebKit's GPU process (`com.apple.WebKit.GPU`, "Safari Graphics and Media"). A muted tap on it: both tabs went silent for 10 s and came back on their own (heard by the user), while Mara got their audio at −14 to −24 dBFS, ~32 ms late. The GPU process may also carry other WebKit apps' media. |
| Does ScreenCaptureKit still hear a muted app? | **Yes**, at the same level as the tap, and running it alongside doesn't undo the mute (heard by the user). Mara uses it as the witness that tells a broken tap. |
| Permission | Run from the terminal, the capture is credited to the host app: every buffer arrives **all zeros, with no error**. Run as Mara (which already had Screen & System Audio Recording), audio arrived and no new prompt appeared during the test. `NSAudioCaptureUsageDescription` was added to Info.plist, which taps require. |

A single tab would need a browser extension using `chrome.tabCapture`, which takes a tab's
audio away from the speakers too, and a way to send that audio to Mara. That is a separate
project.

## How it would fit in Mara

Built as "Ouvir só a dublagem" (Sources/MaraAI/Dubbing.swift); `MaraAI --try-dubbing <bundle id|all>
<seconds> <volume>...` runs it without a session. The sketch below is what guided it.

**Capture**
- A second source next to `SystemAudioCapture`: an `AudioTap` with `.mutedWhenTapped` feeding
  the same `onBuffer` path in `TranscriptionSession.start`. `BufferConverter` already downmixes
  48 kHz stereo to the recognizer's format.
- The tap's buffers point at Core Audio's memory (`bufferListNoCopy`), only valid during the IO
  callback. The converter's output is a copy, so the gate, the recognizer and `SentenceAudio` are
  safe; anything that keeps the raw buffer must copy it.
- The microphone keeps coming from ScreenCaptureKit, with `capturesAudio = false` and
  `captureMicrophone = true`.
- The aggregate device is clocked by the output device chosen at creation. When the default
  output changes (headphones in, AirPods), rebuild the tap and the device.

**What to tap**
- *Everything but Mara* is the simplest choice, but it also silences notifications, music and
  other apps for the whole meeting.
- A picker of the apps playing now (Zoom, Teams, Chrome…) is closer to what the user wants.

**Setting**
- "Ouvir só a dublagem", offered only when reading aloud is on and the meeting is translated,
  since otherwise there is nothing to hear.
- Turning it off, stopping the session or going on standby destroys the tap, so the original
  comes back at once.

**Original under the dubbing**
- Instead of full silence, Mara can play the tapped audio itself, quietly (around 10–20 %),
  through its own `AVAudioEngine` with an `AVAudioSourceNode` reading a ring buffer.
- Mara's process is left out of the tap, so this doesn't loop back. It keeps music, laughter
  and the sentences the reader skips audible.

**Side effects**
- With the meeting off the speakers, the microphone no longer hears the others. The echo filter
  matters less, but Mara still pauses the microphone while it reads aloud on speakers.
- Captions, the transcript, the summary and telling speakers apart are unchanged: they receive
  the same audio.

**Risks to handle**
- Taps that start delivering all zeros mid-session have been reported on macOS 26.5 betas. Watch
  for a long run of zero buffers while the app is playing, and fall back to ScreenCaptureKit.
- Lip sync: in a video, the dubbed voice lags the picture by 1–3 s.

## Sources

- [CATapMuteBehavior (Apple)](https://developer.apple.com/documentation/coreaudio/catapmutebehavior)
- [macOS still has no volume mixer, so I built one](https://dev.to/thalesbmc/macos-still-has-no-volume-mixer-so-i-built-one-53lp)
- [Core Audio taps (Recall.ai)](https://www.recall.ai/blog/core-audio-taps)
- [Taps delivering all-zero buffers (Apple Developer Forums)](https://developer.apple.com/forums/thread/825780)

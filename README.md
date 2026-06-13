# BabySmash! for macOS

A fully native macOS port of [Scott Hanselman's BabySmash](https://github.com/shanselman/babysmash) — a game for babies who like to bang on the keyboard. As keys are smashed, colorful shapes, letters, and numbers appear and are spoken aloud.

Written in **Swift + AppKit + Core Animation**, with **no runtime dependencies** (no .NET, no emulator, no VM). It builds with just the Swift toolchain / Command Line Tools.

> This repository is the macOS port only. The original Windows and Linux versions live in the [upstream repo](https://github.com/shanselman/babysmash).

## Supported macOS versions

- **Tested on:** macOS 15 (Sequoia), Apple Silicon (arm64). This is the only configuration it has actually been run on.
- **Expected to work on:** macOS 12 (Monterey) and later. The deployment target is macOS 12 and all APIs used are available since then, but these versions have **not been tested** — please report results.
- **Architecture:** the prebuilt app and `package.sh` produce an **Apple Silicon (arm64)** build. **Intel (x86_64) is untested**; build a universal binary with `swift build -c release --arch arm64 --arch x86_64` if you need it.
- **Not supported / not tested:** macOS 11 (Big Sur) and earlier.

> Status: this is a community port. Everything except the items above is unverified on configurations other than the tested one.

## Features

- 🎨 Colorful shapes with happy faces: circle, oval, square, rectangle, triangle, star, heart, hexagon, trapezoid — filled with radial gradients
- 🔤 Letters and numbers, spoken aloud via `AVSpeechSynthesizer`
- 🔊 Fun sounds and giggles via `NSSound` (startup, laughter on click, bumblebee on draw, rising/falling on scroll)
- 🧠 Word detection: type letters that spell a real word and they animate into a row and are spoken ("You spelled CAT!")
- 🖱️ Mouse drawing mode, scroll-to-zoom a shape, and playful click animations (jiggle, throb, spin, snap)
- 🖥️ Multi-monitor support (one fullscreen window per display)
- 🔒 Locks out system keys to prevent accidental exits (see below)
- ⚙️ Options dialog: sound mode, cursor (Arrow/Hand), font, faces, fade + fade-delay, mouse-draw, force-uppercase, clear-after count, transparent background

## Install (from a release)

Download the `.dmg` from [Releases](../../releases/latest), open it, and drag **BabySmash** onto **Applications**.

The app is ad-hoc signed but **not notarized** by Apple (notarization needs a paid Apple Developer account), so Gatekeeper blocks the first launch. Approve it once, any of these ways:

- **Easiest (Terminal):** `xattr -dr com.apple.quarantine /Applications/BabySmash.app`, then open it.
- **macOS 15 (Sequoia):** double-click it once (it's blocked), then open **System Settings → Privacy & Security**, scroll to the BabySmash note, and click **Open Anyway**. Sequoia removed the one-click "Open" from the first dialog.
- **macOS 13–14:** right-click the app → **Open** → **Open**.

## Build & run

```bash
# Build and assemble BabySmash.app + BabySmash-macOS-arm64.dmg
./package.sh

# Run it
open dist/BabySmash.app
```

Or for development without the screen lock-down:

```bash
swift build
BABYSMASH_NO_KIOSK=1 .build/debug/BabySmash   # ordinary window, no kiosk/key-lock
```

## Keyboard

| Shortcut | Action |
|----------|--------|
| Any key | Show shapes / letters / numbers |
| `Esc` `Esc` (twice within 1s) | Quit |
| `⌥` `O` (Option+O) | Options dialog |
| Triple-click top-left corner | Emergency quit (mouse only) |

Quitting requires a deliberate double-press of Escape so a single accidental tap won't end the game. The triple-click corner is a keyboard-independent escape hatch: mouse events are never intercepted, so it always works even if something goes wrong with key handling.

## Locking out system keys

Two layers, both standard macOS mechanisms:

1. **Kiosk mode** (no permission needed): `NSApplication` presentation options hide the Dock and menu bar and block Cmd+Tab app switching, the force-quit panel, log out, and hiding the app.
2. **Total keyboard lockdown** (optional): a CoreGraphics event tap becomes the only consumer of the keyboard. It swallows *every* key-down, key-up, modifier change, and the media/hardware keys (volume, brightness, play/pause) system-wide, so nothing reaches the underlying app or the system. The only keys that act are BabySmash's own (ESC twice to quit, ⌥O for options); the game receives keys straight from the tap. This needs **Accessibility permission**:

   *System Settings → Privacy & Security → Accessibility → enable BabySmash*, then relaunch.

   Until granted, the game still runs and kiosk mode still blocks the most common exits, but individual keys (Spotlight, media keys, etc.) are no longer fully blocked.

   Residual edge cases macOS handles below the event tap: multi-finger trackpad swipes (Mission Control / spaces) and double-pressing the **Fn / 🌐 globe** key for dictation. Disable the latter under *System Settings → Keyboard → "Press 🌐 key to"* → **Do Nothing** if needed.

**Safety:** the lockdown is gated on BabySmash being the active app. If it ever loses focus (a system dialog, a hang, getting hidden), the keyboard unlocks automatically so you can never end up invisibly trapped behind a global lock. And the triple-click top-left corner always quits, since mouse events are never intercepted.

## Environment flags (development)

- `BABYSMASH_NO_KIOSK=1` — run as an ordinary window, no kiosk lock-down or event tap.
- `BABYSMASH_DEMO=1` — spawn a fixed sequence of figures on launch (used for screenshot verification).

## Credits & license

BabySmash was created by [Scott Hanselman](https://github.com/shanselman/babysmash). This is an independent macOS port; the original concept, sounds, and word list come from the upstream project. See [LICENSE](LICENSE).

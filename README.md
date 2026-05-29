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

## Build & run

```bash
# Build and assemble BabySmash.app
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

Quitting requires a deliberate double-press of Escape so a single accidental tap won't end the game.

## Locking out system keys

Two layers, both standard macOS mechanisms:

1. **Kiosk mode** (no permission needed): `NSApplication` presentation options hide the Dock and menu bar and block Cmd+Tab app switching, the force-quit panel, log out, and hiding the app.
2. **Global shortcut blocking** (optional): a CoreGraphics event tap swallows every Command/Control-modified key system-wide (Cmd+Q, Spotlight, Cmd+W, Ctrl+Arrow, …). This needs **Accessibility permission**:

   *System Settings → Privacy & Security → Accessibility → enable BabySmash*, then relaunch.

   Until granted, the game still runs and kiosk mode still blocks the most common exits.

## Environment flags (development)

- `BABYSMASH_NO_KIOSK=1` — run as an ordinary window, no kiosk lock-down or event tap.
- `BABYSMASH_DEMO=1` — spawn a fixed sequence of figures on launch (used for screenshot verification).

## Credits & license

BabySmash was created by [Scott Hanselman](https://github.com/shanselman/babysmash). This is an independent macOS port; the original concept, sounds, and word list come from the upstream project. See [LICENSE](LICENSE).

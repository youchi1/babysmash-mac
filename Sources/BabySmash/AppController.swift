import AppKit

/// Coordinates all windows/views and turns key presses into figures, sounds,
/// and speech. This is the macOS equivalent of the original Controller.
final class AppController: NSObject, NSWindowDelegate {
    private let settings = Settings.shared
    private let speech = Speech()
    private let sounds = Sounds()
    private let wordFinder = WordFinder()

    private var windows: [SmashWindow] = []
    private var views: [SmashView] = []

    // Shared history of recent figures: a letter Character, or nil for shapes.
    private var history: [Character?] = []
    private let historyCap = 32

    private var lastEscape = Date.distantPast
    private var focusTimer: Timer?
    private var optionsWindow: OptionsWindow?
    private var kioskEnabled = false

    private var testMode: Bool {
        ProcessInfo.processInfo.environment["BABYSMASH_NO_KIOSK"] == "1"
    }

    func start() {
        let kiosk = !testMode

        if testMode {
            buildTestWindow()
        } else {
            buildKioskWindows()
        }

        applySettings()
        views.first?.showInfoLabel()

        if kiosk {
            KeyLock.enableKiosk()
            KeyLock.startEventTap()
            kioskEnabled = true
            startFocusTimer()
        }

        // Startup giggle.
        playSound("EditedJackPlaysBabySmash.wav")

        // Deterministic self-test: spawn a known sequence so a screenshot can
        // confirm shapes, letters, faces, colours, and word detection render.
        if ProcessInfo.processInfo.environment["BABYSMASH_DEMO"] == "1" {
            runDemo()
        }
    }

    private func runDemo() {
        // Keep figures on screen so a screenshot can capture them (transient).
        settings.sessionDisableFade = true
        let sequence: [Character] = ["A", "5", "+", "C", "A", "T", "%", "B", "?", "7"]
        for (i, ch) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 * Double(i + 1)) { [weak self] in
                self?.process(rawCharacter: ch)
            }
        }
    }

    private func buildKioskWindows() {
        for screen in NSScreen.screens {
            let window = makeWindow(frame: screen.frame, kiosk: true)
            window.makeKeyAndOrderFront(nil)
        }
        windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildTestWindow() {
        let frame = NSRect(x: 200, y: 200, width: 1000, height: 700)
        let window = makeWindow(frame: frame, kiosk: false)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow(frame: NSRect, kiosk: Bool) -> SmashWindow {
        let window = SmashWindow(screenFrame: frame, kiosk: kiosk)
        window.controller = self
        if kiosk { window.delegate = self } // for focus auto-recovery
        let view = SmashView(frame: NSRect(origin: .zero, size: frame.size))
        view.controller = self
        view.isPrimary = views.isEmpty
        window.contentView = view
        windows.append(window)
        views.append(view)
        return window
    }

    private func startFocusTimer() {
        // Frequent enough to recover quickly if a stray system shortcut (e.g.
        // Spotlight) steals focus, so the game keeps responding to keys.
        focusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.optionsWindow == nil else { return }
            if NSApp.keyWindow == nil {
                self.windows.first?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Key handling

    func handleKeyDown(_ event: NSEvent) {
        // Double-press Escape to quit (deliberate, so one tap won't exit).
        if event.keyCode == 53 {
            let now = Date()
            if now.timeIntervalSince(lastEscape) <= 1.0 {
                quit()
            } else {
                lastEscape = now
            }
            return
        }

        // Option+O opens the options dialog. Match on the physical key code
        // (kVK_ANSI_O == 31) because, with Option held, charactersIgnoringModifiers
        // can return the option-modified glyph ("ø") rather than "o".
        if event.modifierFlags.contains(.option) && event.keyCode == 31 {
            showOptions()
            return
        }

        // Prefer the unmodified glyph; fall back to the option-modified one so a
        // key still produces a figure even with Option held.
        guard let raw = event.charactersIgnoringModifiers?.first
                ?? event.characters?.first else { return }
        process(rawCharacter: raw)
    }

    /// Turns one raw character into a figure across all windows, then handles
    /// word detection, speech, and sound. Shared by real key events and demo mode.
    func process(rawCharacter raw: Character) {
        views.forEach { $0.hideInfoLabel() }

        let displayChar = displayCharacter(for: raw)
        let template = FigureTemplate.generate(for: displayChar)

        for view in views {
            view.addFigure(template)
        }

        // Track history for word detection.
        if case .letter(let ch) = template.kind, ch.isLetter {
            history.append(Character(ch.uppercased()))
        } else {
            history.append(nil)
        }
        if history.count > historyCap { history.removeFirst(history.count - historyCap) }

        if let word = wordFinder.lastWord(history: history), word.count >= 2 {
            for view in views { view.animateWord(word) }
            if settings.sounds == "Speech" {
                speech.speak("You spelled \(word)!")
            } else {
                playForTemplate(template)
            }
        } else {
            playForTemplate(template)
        }
    }

    private func displayCharacter(for raw: Character) -> Character {
        if raw.isLetter {
            return settings.forceUppercase ? Character(raw.uppercased()) : raw
        }
        if raw.isNumber {
            return raw
        }
        // Symbols, whitespace, control characters -> a random shape.
        return "*"
    }

    // MARK: - Audio

    private func playForTemplate(_ template: FigureTemplate) {
        switch settings.sounds {
        case "Laughter":
            playLaugh()
        case "Speech":
            speech.speak(template.spokenText)
        default:
            break // "None"
        }
    }

    func playLaugh() {
        guard settings.sounds != "None" else { return }
        sounds.play(Sounds.randomLaugh())
    }

    func playSound(_ name: String) {
        guard settings.sounds != "None" else { return }
        sounds.play(name)
    }

    /// The mouse-draw buzz: triggers immediately when the mouse moves if it isn't
    /// already playing, and plays to completion (not stopped when the mouse stops).
    func playDrawSound() {
        guard settings.sounds != "None" else { return }
        // Buzz-only clip: the original smallbumblebee.wav is 10s with ~5s of
        // trailing silence, which caused a long silent gap before it retriggered.
        // This clip is the full buzz with that dead air removed.
        sounds.playNonOverlapping("smallbumblebee-short.wav", channel: "draw")
    }

    /// Scroll-wheel rising/falling sound. Non-overlapping like the original
    /// (SND_NOSTOP): the wheel sends many events per gesture, so without this
    /// they pile up into noise.
    func playWheelSound(_ name: String) {
        guard settings.sounds != "None" else { return }
        sounds.playNonOverlapping(name, channel: "wheel")
    }

    // MARK: - Options & quit

    private func showOptions() {
        guard optionsWindow == nil else { return }
        // The game windows sit at the shielding level; trying to place the dialog
        // above that is unreliable (the window server won't composite it). Instead
        // drop the game windows to normal level while the dialog is open, then
        // restore the shield level on close. Kiosk presentation options stay on,
        // so the screen remains locked down throughout.
        if kioskEnabled {
            for window in windows { window.level = .normal }
        }
        let options = OptionsWindow()
        optionsWindow = options
        options.onClose = { [weak self] in
            guard let self else { return }
            self.optionsWindow = nil
            self.applySettings() // cursor + transparent background apply live
            if self.kioskEnabled {
                let shield = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
                for window in self.windows { window.level = shield }
            }
            self.windows.first?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        options.showModeless()
    }

    /// Applies live-changeable settings (transparent background, cursor) to every
    /// window and view. Font, fade, and clear-after take effect on the next figure.
    private func applySettings() {
        let transparent = settings.transparentBackground
        for window in windows {
            window.isOpaque = !transparent
            window.backgroundColor = transparent ? .clear : NSColor(white: 0.96, alpha: 1)
            window.hasShadow = !transparent
        }
        for view in views { view.applySettings() }
    }

    /// Re-grab key focus if a stray system shortcut steals it, so the game keeps
    /// responding without needing a mouse click. Skipped while options are open.
    func windowDidResignKey(_ notification: Notification) {
        guard kioskEnabled, optionsWindow == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, self.optionsWindow == nil else { return }
            self.windows.first?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func quit() {
        focusTimer?.invalidate()
        if kioskEnabled {
            KeyLock.stopEventTap()
            KeyLock.disableKiosk()
        }
        NSCursor.unhide()
        NSApp.terminate(nil)
    }
}

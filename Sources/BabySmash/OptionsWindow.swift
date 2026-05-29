import AppKit

/// A small settings dialog mirroring the original BabySmash options.
final class OptionsWindow: NSWindow, NSWindowDelegate {
    var onClose: (() -> Void)?

    private let soundPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let cursorPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let fontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let facesCheck = NSButton(checkboxWithTitle: "Show faces on shapes", target: nil, action: nil)
    private let fadeCheck = NSButton(checkboxWithTitle: "Fade shapes away", target: nil, action: nil)
    private let mouseCheck = NSButton(checkboxWithTitle: "Mouse draws shapes", target: nil, action: nil)
    private let upperCheck = NSButton(checkboxWithTitle: "Force uppercase letters", target: nil, action: nil)
    private let transparentCheck = NSButton(checkboxWithTitle: "Transparent background (show desktop)", target: nil, action: nil)
    private let clearField = NSTextField(string: "30")
    private let clearStepper = NSStepper()
    private let fadeSlider = NSSlider(value: 4, minValue: 1, maxValue: 15, target: nil, action: nil)
    private let fadeValueLabel = NSTextField(labelWithString: "4s")

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        title = "BabySmash Options"
        delegate = self
        level = .modalPanel
        // We hold a strong reference (AppController.optionsWindow); without this,
        // closing the window releases it too (default true) and ARC double-frees
        // it -> EXC_BAD_ACCESS in objc_release on pool drain.
        isReleasedWhenClosed = false
        buildUI()
        loadValues()
    }

    private func buildUI() {
        let settings = Settings.shared

        soundPopup.addItems(withTitles: ["Speech", "Laughter", "None"])
        cursorPopup.addItems(withTitles: ["Arrow", "Hand"])
        fontPopup.addItems(withTitles: Settings.fontChoices)

        clearStepper.minValue = 1
        clearStepper.maxValue = 100
        clearStepper.increment = 1
        clearStepper.valueWraps = false
        clearStepper.target = self
        clearStepper.action = #selector(stepperChanged)
        clearField.alignment = .right
        clearField.isEditable = false
        clearField.isBordered = true
        clearField.widthAnchor.constraint(equalToConstant: 60).isActive = true

        fadeSlider.target = self
        fadeSlider.action = #selector(fadeChanged)
        fadeSlider.widthAnchor.constraint(equalToConstant: 160).isActive = true
        fadeValueLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let clearRow = NSStackView(views: [label("Clear after"), clearField, clearStepper, label("shapes")])
        clearRow.orientation = .horizontal
        clearRow.spacing = 8

        let soundRow = NSStackView(views: [label("Sounds"), soundPopup])
        soundRow.orientation = .horizontal
        soundRow.spacing = 8

        let cursorRow = NSStackView(views: [label("Cursor"), cursorPopup])
        cursorRow.orientation = .horizontal
        cursorRow.spacing = 8

        let fontRow = NSStackView(views: [label("Font"), fontPopup])
        fontRow.orientation = .horizontal
        fontRow.spacing = 8

        let fadeRow = NSStackView(views: [label("Fade after"), fadeSlider, fadeValueLabel])
        fadeRow.orientation = .horizontal
        fadeRow.spacing = 8

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let quitButton = NSButton(title: "Quit BabySmash", target: self, action: #selector(quitApp))
        quitButton.bezelColor = NSColor.systemRed

        let buttonRow = NSStackView(views: [quitButton, NSView(), cancelButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.distribution = .fill

        let stack = NSStackView(views: [
            soundRow, cursorRow, fontRow, facesCheck, fadeCheck, fadeRow,
            mouseCheck, upperCheck, transparentCheck, clearRow,
            NSBox.divider(), buttonRow,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        contentView = content
        _ = settings // keep settings referenced
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 13)
        return l
    }

    private func loadValues() {
        let s = Settings.shared
        soundPopup.selectItem(withTitle: s.sounds)
        if soundPopup.indexOfSelectedItem < 0 { soundPopup.selectItem(at: 0) }
        cursorPopup.selectItem(withTitle: s.cursorType)
        if cursorPopup.indexOfSelectedItem < 0 { cursorPopup.selectItem(at: 0) }
        fontPopup.selectItem(withTitle: s.fontFamily)
        if fontPopup.indexOfSelectedItem < 0 { fontPopup.selectItem(at: 0) }
        facesCheck.state = s.facesOnShapes ? .on : .off
        fadeCheck.state = s.fadeAway ? .on : .off
        mouseCheck.state = s.mouseDraw ? .on : .off
        upperCheck.state = s.forceUppercase ? .on : .off
        transparentCheck.state = s.transparentBackground ? .on : .off
        clearStepper.integerValue = s.clearAfter
        clearField.stringValue = "\(s.clearAfter)"
        fadeSlider.doubleValue = s.fadeAfter
        fadeValueLabel.stringValue = "\(Int(s.fadeAfter.rounded()))s"
    }

    @objc private func stepperChanged() {
        clearField.stringValue = "\(clearStepper.integerValue)"
    }

    @objc private func fadeChanged() {
        fadeValueLabel.stringValue = "\(Int(fadeSlider.doubleValue.rounded()))s"
    }

    @objc private func save() {
        let s = Settings.shared
        s.sounds = soundPopup.titleOfSelectedItem ?? "Speech"
        s.cursorType = cursorPopup.titleOfSelectedItem ?? "Arrow"
        s.fontFamily = fontPopup.titleOfSelectedItem ?? "System Rounded"
        s.facesOnShapes = facesCheck.state == .on
        s.fadeAway = fadeCheck.state == .on
        s.mouseDraw = mouseCheck.state == .on
        s.forceUppercase = upperCheck.state == .on
        s.transparentBackground = transparentCheck.state == .on
        s.clearAfter = clearStepper.integerValue
        s.fadeAfter = fadeSlider.doubleValue.rounded()
        close()
    }

    @objc private func cancel() {
        close()
    }

    @objc private func quitApp() {
        (NSApp.delegate as? AppDelegate)?.controller.quit()
    }

    func showModeless() {
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

private extension NSBox {
    static func divider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}

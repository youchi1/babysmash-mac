import AppKit
import CoreGraphics

/// Locks down the Mac so a child cannot accidentally leave the game or trigger
/// anything in the system or other apps.
///
/// Two layers:
///   1. Kiosk presentation options (no permission needed) hide the Dock and
///      menu bar and block Cmd+Tab, the force-quit panel, log out, and hiding.
///   2. A CoreGraphics event tap (needs Accessibility permission) that becomes
///      the SOLE consumer of the keyboard: it swallows every key-down, key-up,
///      modifier change, and the media/hardware-key subtype of the system-defined
///      events, so NOTHING reaches BabySmash's own window, the underlying app, or
///      the system. Key-downs are forwarded to the controller, which is the only
///      thing that ever acts on them (figures, plus the Esc-Esc quit and ⌥O
///      shortcuts). Degrades to kiosk-only if the permission has not been granted.
enum KeyLock {

    /// Invoked on the main thread for every key-down the tap intercepts. The
    /// controller turns it into a figure or handles the Esc/⌥O shortcuts.
    /// Assigned by AppController before the tap is started.
    static var keyDownHandler: ((NSEvent) -> Void)?

    /// Invoked on the main thread for every Escape key-down. Kept separate from
    /// keyDownHandler and driven by the raw keycode so the emergency exit works
    /// even if NSEvent reconstruction fails. Assigned by AppController.
    static var escapeHandler: (() -> Void)?

    /// Invoked on the main thread to spawn a plain shape for keys that carry no
    /// character of their own (e.g. Caps Lock), so every key press still produces
    /// something on screen. Assigned by AppController.
    static var shapeHandler: (() -> Void)?

    /// While true the tap passes keyboard events straight through untouched. Used
    /// while the options dialog is open so its text fields and buttons receive
    /// typing and Return/Escape. Set back to false when the dialog closes.
    static var passthrough = false

    static func enableKiosk() {
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableAppleMenu,
            .disableProcessSwitching,
            .disableForceQuit,
            .disableSessionTermination,
            .disableHideApplication,
        ]
    }

    static func disableKiosk() {
        NSApp.presentationOptions = []
    }

    // Held so the C callback can re-enable the tap if the system disables it.
    private static var eventTap: CFMachPort?

    // NSEvent.EventType.systemDefined; not a named CGEventType case, but the tap
    // can still subscribe to it by raw value. Carries the media/hardware keys.
    private static let systemDefinedType: UInt32 = 14
    // NX_SUBTYPE_AUX_CONTROL_BUTTONS: volume, brightness, play/pause, etc.
    private static let auxControlSubtype: Int16 = 8

    /// Returns true if the global shortcut tap was installed.
    @discardableResult
    static func startEventTap() -> Bool {
        guard ensureAccessibility() else {
            printAccessibilityHint()
            return false
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << systemDefinedType)

        guard let tap = CGEvent.tapCreate(
            // HID level (not session level): events are intercepted before the
            // system processes them, which is the only place a tap can stop
            // Caps Lock from toggling its state/LED. A session tap sees Caps Lock
            // only after the toggle has already happened. The tap dies with the
            // process, so it changes nothing permanently.
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: nil
        ) else {
            printAccessibilityHint()
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    static func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private static func ensureAccessibility() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func printAccessibilityHint() {
        FileHandle.standardError.write(Data("""
        ┌──────────────────────────────────────────────────────────────┐
        │  BabySmash can swallow EVERY key (system shortcuts, media and  │
        │  brightness keys, Spotlight, Cmd+Q, etc.) once you grant       │
        │  Accessibility permission.                                     │
        │  System Settings -> Privacy & Security -> Accessibility        │
        │  -> enable BabySmash, then relaunch.                           │
        │  Kiosk mode already blocks the Dock, menu bar, app switching,  │
        │  and force quit.                                              │
        └──────────────────────────────────────────────────────────────┘

        """.utf8))
    }

    // C function pointer: no captured context allowed, so it reads the static
    // state above and forwards key-downs through `keyDownHandler`.
    private static let tapCallback: CGEventTapCallBack = { _, type, event, _ in
        // The system disables a tap that blocks for too long or on certain user
        // input; re-arm it and let this event through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = KeyLock.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // SAFETY: only lock the keyboard while BabySmash is the active app, and
        // never while the options dialog is open. If the app ever loses
        // activation (a system dialog, a hang, getting hidden), keys flow
        // normally so the user can never be invisibly trapped behind a global
        // lock with no way out.
        if KeyLock.passthrough || !NSApp.isActive {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            // Read the keycode straight from the raw event so the quit shortcut
            // works even if NSEvent reconstruction ever fails. Escape (53) is the
            // emergency exit and must be the most robust path in the app.
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 53 {
                DispatchQueue.main.async { KeyLock.escapeHandler?() }
                return nil
            }
            // Forward a copy to the controller, then delete the original so it
            // never reaches BabySmash's window, another app, or the system.
            if let nsEvent = NSEvent(cgEvent: event) {
                DispatchQueue.main.async { KeyLock.keyDownHandler?(nsEvent) }
            }
            return nil

        case .flagsChanged:
            // Modifier changes (Shift, Ctrl, Option, Cmd, Fn, Caps Lock). Swallow
            // them all so none reach the system. Caps Lock (keycode 57) would
            // otherwise toggle its state/LED; intercepting it here at the HID
            // level stops the toggle, and we turn it into a shape so the key still
            // does something playful instead of changing system behavior.
            if event.getIntegerValueField(.keyboardEventKeycode) == 57 {
                DispatchQueue.main.async { KeyLock.shapeHandler?() }
            }
            return nil

        case .keyUp:
            // Swallow key releases.
            return nil

        default:
            // systemDefined (type 14): swallow only the aux-control subtype so
            // volume/brightness/play keys cannot drive the system. Pass any other
            // system-defined event (screen changes, power, etc.) through.
            if type.rawValue == KeyLock.systemDefinedType,
               let nsEvent = NSEvent(cgEvent: event),
               nsEvent.subtype.rawValue == KeyLock.auxControlSubtype {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }
    }
}

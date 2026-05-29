import AppKit
import CoreGraphics

/// Locks down the Mac so a child cannot accidentally leave the game.
///
/// Two layers, matching the design used for the Avalonia attempt:
///   1. Kiosk presentation options (no permission needed) hide the Dock and
///      menu bar and block Cmd+Tab, the force-quit panel, log out, and hiding.
///   2. A CoreGraphics event tap (needs Accessibility permission) swallows every
///      Command- or Control-modified key event system-wide, covering Cmd+Q,
///      Spotlight, Cmd+W, Ctrl+Arrow, and friends. Degrades gracefully if the
///      permission has not been granted.
enum KeyLock {

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

    /// Returns true if the global shortcut tap was installed.
    @discardableResult
    static func startEventTap() -> Bool {
        guard ensureAccessibility() else {
            printAccessibilityHint()
            return false
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
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
        │  BabySmash can block ALL system shortcuts (Cmd+Q, Cmd+Tab,    │
        │  Spotlight, etc.) once you grant Accessibility permission.    │
        │  System Settings -> Privacy & Security -> Accessibility       │
        │  -> enable BabySmash, then relaunch.                          │
        │  Kiosk mode already blocks the Dock, menu bar, app switching, │
        │  and force quit.                                              │
        └──────────────────────────────────────────────────────────────┘

        """.utf8))
    }

    // C function pointer: no captured context allowed.
    private static let tapCallback: CGEventTapCallBack = { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = KeyLock.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            // Swallow the system shortcut.
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}

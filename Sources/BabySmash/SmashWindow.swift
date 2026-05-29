import AppKit

/// A borderless, always-on-top window that fills one screen and forwards key
/// presses to the controller.
final class SmashWindow: NSWindow {
    weak var controller: AppController?

    init(screenFrame: NSRect, kiosk: Bool) {
        super.init(contentRect: screenFrame,
                   styleMask: kiosk ? [.borderless] : [.titled, .closable, .resizable],
                   backing: .buffered,
                   defer: false)
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true // needed for cursor tracking on every monitor
        backgroundColor = NSColor(white: 0.96, alpha: 1)
        if kiosk {
            level = .init(Int(CGShieldingWindowLevel()))
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            setFrame(screenFrame, display: true)
        } else {
            title = "BabySmash!"
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Handle everything ourselves so unhandled keys don't beep.
        controller?.handleKeyDown(event)
    }

    // Do not let the default Cmd+Q/Cmd+W reach AppKit even without the event tap.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            return true // swallow
        }
        return super.performKeyEquivalent(with: event)
    }
}

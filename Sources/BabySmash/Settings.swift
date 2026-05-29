import Foundation

/// Persists user options in the standard macOS UserDefaults store.
/// Mirrors the settings exposed by the original BabySmash.
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let sounds = "Sounds"             // "Speech" | "Laughter" | "None"
        static let fadeAway = "FadeAway"
        static let fadeAfter = "FadeAfter"       // seconds
        static let clearAfter = "ClearAfter"     // number of figures kept
        static let mouseDraw = "MouseDraw"
        static let facesOnShapes = "FacesOnShapes"
        static let forceUppercase = "ForceUppercase"
        static let cursorType = "CursorType"             // "Arrow" | "Hand"
        static let fontFamily = "FontFamily"             // "" / "System Rounded" or a font name
        static let transparentBackground = "TransparentBackground"
    }

    /// The default kid-friendly fonts offered in the Options dialog. The first
    /// entry is the rounded system font.
    static let fontChoices = [
        "System Rounded", "Chalkboard SE", "Marker Felt", "Noteworthy",
        "Bradley Hand", "Comic Sans MS", "Arial Rounded MT Bold",
    ]

    /// Transient (non-persisted) override used by demo/self-test mode to keep
    /// figures on screen for screenshots without changing the user's real setting.
    var sessionDisableFade = false

    init() {
        defaults.register(defaults: [
            Key.sounds: "Laughter",
            Key.fadeAway: true,
            Key.fadeAfter: 4.0,
            Key.clearAfter: 30,
            Key.mouseDraw: false,
            Key.facesOnShapes: true,
            Key.forceUppercase: true,
            Key.cursorType: "Arrow",
            Key.fontFamily: "System Rounded",
            Key.transparentBackground: false,
        ])
    }

    var sounds: String {
        get { defaults.string(forKey: Key.sounds) ?? "Speech" }
        set { defaults.set(newValue, forKey: Key.sounds) }
    }
    var fadeAway: Bool {
        get { defaults.bool(forKey: Key.fadeAway) }
        set { defaults.set(newValue, forKey: Key.fadeAway) }
    }
    var fadeAfter: Double {
        get { defaults.double(forKey: Key.fadeAfter) }
        set { defaults.set(newValue, forKey: Key.fadeAfter) }
    }
    var clearAfter: Int {
        get { defaults.integer(forKey: Key.clearAfter) }
        set { defaults.set(newValue, forKey: Key.clearAfter) }
    }
    var mouseDraw: Bool {
        get { defaults.bool(forKey: Key.mouseDraw) }
        set { defaults.set(newValue, forKey: Key.mouseDraw) }
    }
    var facesOnShapes: Bool {
        get { defaults.bool(forKey: Key.facesOnShapes) }
        set { defaults.set(newValue, forKey: Key.facesOnShapes) }
    }
    var forceUppercase: Bool {
        get { defaults.bool(forKey: Key.forceUppercase) }
        set { defaults.set(newValue, forKey: Key.forceUppercase) }
    }
    var cursorType: String {
        get { defaults.string(forKey: Key.cursorType) ?? "Arrow" }
        set { defaults.set(newValue, forKey: Key.cursorType) }
    }
    var fontFamily: String {
        get { defaults.string(forKey: Key.fontFamily) ?? "System Rounded" }
        set { defaults.set(newValue, forKey: Key.fontFamily) }
    }
    var transparentBackground: Bool {
        get { defaults.bool(forKey: Key.transparentBackground) }
        set { defaults.set(newValue, forKey: Key.transparentBackground) }
    }
}

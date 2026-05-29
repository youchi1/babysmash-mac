import AppKit

/// The named colour palette used by BabySmash, matching the original game.
struct BabyColor {
    let name: String
    let color: NSColor

    /// Returns a copy of the colour with each RGB channel shifted by `degree`
    /// (clamped to 0...255), used to build the radial gradient highlights.
    func lightenOrDarken(_ degree: CGFloat) -> NSColor {
        let c = color.usingColorSpace(.sRGB) ?? color
        func clamp(_ v: CGFloat) -> CGFloat { min(max(v + degree / 255.0, 0), 1) }
        return NSColor(srgbRed: clamp(c.redComponent),
                       green: clamp(c.greenComponent),
                       blue: clamp(c.blueComponent),
                       alpha: c.alphaComponent)
    }
}

enum Palette {
    // Same nine colours as the original Utils.cs palette.
    static let all: [BabyColor] = [
        BabyColor(name: "Red", color: NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1)),
        BabyColor(name: "Blue", color: NSColor(srgbRed: 0.0, green: 0.0, blue: 1.0, alpha: 1)),
        BabyColor(name: "Yellow", color: NSColor(srgbRed: 1.0, green: 1.0, blue: 0.0, alpha: 1)),
        BabyColor(name: "Green", color: NSColor(srgbRed: 0.0, green: 0.5019, blue: 0.0, alpha: 1)),
        BabyColor(name: "Purple", color: NSColor(srgbRed: 0.5019, green: 0.0, blue: 0.5019, alpha: 1)),
        BabyColor(name: "Pink", color: NSColor(srgbRed: 1.0, green: 0.7529, blue: 0.7960, alpha: 1)),
        BabyColor(name: "Orange", color: NSColor(srgbRed: 1.0, green: 0.6470, blue: 0.0, alpha: 1)),
        BabyColor(name: "Tan", color: NSColor(srgbRed: 0.8235, green: 0.7058, blue: 0.5490, alpha: 1)),
        BabyColor(name: "Gray", color: NSColor(srgbRed: 0.5019, green: 0.5019, blue: 0.5019, alpha: 1)),
    ]

    static func random() -> BabyColor {
        all[Int.random(in: 0..<all.count)]
    }
}

enum Rand {
    static func between(_ minV: Int, _ maxV: Int) -> Int {
        if maxV <= minV { return minV }
        return Int.random(in: minV...maxV)
    }
    static func bool() -> Bool { Bool.random() }
}

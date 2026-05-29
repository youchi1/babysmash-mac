import AppKit
import QuartzCore

enum ShapeType: CaseIterable {
    case circle, oval, square, rectangle, triangle, star, heart, hexagon, trapezoid

    var spokenName: String {
        switch self {
        case .circle: return "Circle"
        case .oval: return "Oval"
        case .square: return "Square"
        case .rectangle: return "Rectangle"
        case .triangle: return "Triangle"
        case .star: return "Star"
        case .heart: return "Heart"
        case .hexagon: return "Hexagon"
        case .trapezoid: return "Trapezoid"
        }
    }
}

/// What to draw for one key press, plus the text to speak for it.
struct FigureTemplate {
    enum Kind {
        case letter(Character)
        case shape(ShapeType)
    }
    let kind: Kind
    let color: BabyColor

    var isLetter: Bool {
        if case .letter = kind { return true }
        return false
    }

    /// The phrase spoken in "Speech" mode.
    var spokenText: String {
        switch kind {
        case .letter(let ch):
            return String(ch)
        case .shape(let shape):
            return "\(color.name) \(shape.spokenName)"
        }
    }

    static func generate(for char: Character) -> FigureTemplate {
        let color = Palette.random()
        if char.isLetter || char.isNumber {
            return FigureTemplate(kind: .letter(char), color: color)
        }
        let shape = ShapeType.allCases[Int.random(in: 0..<ShapeType.allCases.count)]
        return FigureTemplate(kind: .shape(shape), color: color)
    }
}

/// A live figure on screen: its root layer plus metadata used for word layout.
final class Figure {
    let layer: CALayer
    let size: CGSize
    let isLetter: Bool
    let character: Character?
    var scale: CGFloat = 1 // current zoom level, adjusted by the scroll wheel

    init(layer: CALayer, size: CGSize, isLetter: Bool, character: Character?) {
        self.layer = layer
        self.size = size
        self.isLetter = isLetter
        self.character = character
    }
}

enum FigureFactory {
    static let shapeSize: CGFloat = 200
    static let letterFontSize: CGFloat = 220

    static func make(_ template: FigureTemplate, showFaces: Bool) -> Figure {
        switch template.kind {
        case .letter(let ch):
            return makeLetter(ch, color: template.color)
        case .shape(let shape):
            return makeShape(shape, color: template.color, showFaces: showFaces)
        }
    }

    // MARK: - Letters & numbers

    private static func letterFont(size: CGFloat) -> NSFont {
        let family = Settings.shared.fontFamily
        let systemHeavy = NSFont.systemFont(ofSize: size, weight: .heavy)

        if family.isEmpty || family == "System Rounded" {
            if let desc = systemHeavy.fontDescriptor.withDesign(.rounded) {
                return NSFont(descriptor: desc, size: size) ?? systemHeavy
            }
            return systemHeavy
        }
        // Use the chosen family, bolded if a bold variant exists.
        guard let base = NSFont(name: family, size: size) else { return systemHeavy }
        let bold = NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        return bold
    }

    private static func makeLetter(_ ch: Character, color: BabyColor) -> Figure {
        let font = letterFont(size: letterFontSize)
        let darker = color.lightenOrDarken(-60)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color.color,
            .strokeColor: darker,
            .strokeWidth: -7.0, // negative => fill AND stroke
        ]
        let str = NSAttributedString(string: String(ch), attributes: attributes)
        var bounds = str.size()
        bounds.width = ceil(bounds.width) + 24
        bounds.height = ceil(bounds.height) + 24

        let image = NSImage(size: bounds)
        image.lockFocus()
        str.draw(at: NSPoint(x: 12, y: 12))
        image.unlockFocus()

        let layer = CALayer()
        layer.bounds = CGRect(origin: .zero, size: bounds)
        layer.contents = image
        layer.contentsGravity = .resizeAspect
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: -2)

        return Figure(layer: layer, size: bounds, isLetter: true, character: ch)
    }

    // MARK: - Shapes

    private static func makeShape(_ shape: ShapeType, color: BabyColor, showFaces: Bool) -> Figure {
        let size = CGSize(width: shapeSize, height: shapeSize)
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 14, dy: 14)
        let path = path(for: shape, in: rect)

        let container = CALayer()
        container.bounds = CGRect(origin: .zero, size: size)
        container.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Radial gradient fill (lighter centre -> colour -> darker edge), masked to the shape.
        let gradient = CAGradientLayer()
        gradient.frame = container.bounds
        gradient.type = .radial
        gradient.colors = [
            color.lightenOrDarken(60).cgColor,
            color.color.cgColor,
            color.lightenOrDarken(-60).cgColor,
        ]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0.42, y: 0.62) // off-centre highlight
        gradient.endPoint = CGPoint(x: 1.1, y: 1.1)

        let mask = CAShapeLayer()
        mask.path = path
        gradient.mask = mask
        container.addSublayer(gradient)

        // Outline for definition.
        let stroke = CAShapeLayer()
        stroke.path = path
        stroke.fillColor = NSColor.clear.cgColor
        stroke.strokeColor = color.lightenOrDarken(-60).cgColor
        stroke.lineWidth = 6
        container.addSublayer(stroke)

        container.shadowColor = NSColor.black.cgColor
        container.shadowOpacity = 0.2
        container.shadowRadius = 8
        container.shadowOffset = CGSize(width: 0, height: -3)

        if showFaces {
            addFace(to: container, in: rect)
        }

        return Figure(layer: container, size: size, isLetter: false, character: nil)
    }

    /// Adds two eyes and a smile, sized relative to the shape's bounding box.
    private static func addFace(to container: CALayer, in rect: CGRect) {
        let eyeR = rect.width * 0.07
        let eyeY = rect.minY + rect.height * 0.60
        let eyeDX = rect.width * 0.16
        let cx = rect.midX

        for sign in [-1.0, 1.0] {
            let ex = cx + CGFloat(sign) * eyeDX
            let sclera = CAShapeLayer()
            sclera.path = CGPath(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2), transform: nil)
            sclera.fillColor = NSColor.white.cgColor
            sclera.strokeColor = NSColor.black.cgColor
            sclera.lineWidth = 2
            container.addSublayer(sclera)

            let pupilR = eyeR * 0.5
            let pupil = CAShapeLayer()
            pupil.path = CGPath(ellipseIn: CGRect(x: ex - pupilR, y: eyeY - pupilR, width: pupilR * 2, height: pupilR * 2), transform: nil)
            pupil.fillColor = NSColor.black.cgColor
            container.addSublayer(pupil)
        }

        // Smile: an arc across the lower portion of the shape.
        let smile = CAShapeLayer()
        let smilePath = CGMutablePath()
        let smileRect = CGRect(x: cx - rect.width * 0.22,
                               y: rect.minY + rect.height * 0.22,
                               width: rect.width * 0.44,
                               height: rect.height * 0.26)
        // Lower half of an ellipse => a smile curve.
        smilePath.addArc(center: CGPoint(x: smileRect.midX, y: smileRect.maxY),
                         radius: smileRect.width / 2,
                         startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
        smile.path = smilePath
        smile.fillColor = NSColor.clear.cgColor
        smile.strokeColor = NSColor.black.cgColor
        smile.lineWidth = 4
        smile.lineCap = .round
        container.addSublayer(smile)
    }

    // MARK: - Shape paths

    private static func path(for shape: ShapeType, in rect: CGRect) -> CGPath {
        switch shape {
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case .oval:
            let r = rect.insetBy(dx: 0, dy: rect.height * 0.15)
            return CGPath(ellipseIn: r, transform: nil)
        case .square:
            return CGPath(roundedRect: rect, cornerWidth: 16, cornerHeight: 16, transform: nil)
        case .rectangle:
            let r = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.18,
                           width: rect.width, height: rect.height * 0.64)
            return CGPath(roundedRect: r, cornerWidth: 14, cornerHeight: 14, transform: nil)
        case .triangle:
            return polygon([
                CGPoint(x: rect.midX, y: rect.maxY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.minX, y: rect.minY),
            ])
        case .hexagon:
            return regularPolygon(sides: 6, in: rect, rotation: .pi / 6)
        case .trapezoid:
            let inset = rect.width * 0.22
            return polygon([
                CGPoint(x: rect.minX + inset, y: rect.maxY),
                CGPoint(x: rect.maxX - inset, y: rect.maxY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.minX, y: rect.minY),
            ])
        case .star:
            return star(in: rect, points: 5)
        case .heart:
            return heart(in: rect)
        }
    }

    private static func polygon(_ points: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: points)
        p.closeSubpath()
        return p
    }

    private static func regularPolygon(sides: Int, in rect: CGRect, rotation: CGFloat) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var pts: [CGPoint] = []
        for i in 0..<sides {
            let a = rotation + CGFloat(i) * (2 * .pi / CGFloat(sides))
            pts.append(CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a)))
        }
        return polygon(pts)
    }

    private static func star(in rect: CGRect, points: Int) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.42
        var pts: [CGPoint] = []
        let step = CGFloat.pi / CGFloat(points)
        var angle = -CGFloat.pi / 2
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? outer : inner
            pts.append(CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle)))
            angle += step
        }
        return polygon(pts)
    }

    private static func heart(in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        // Build a heart with the point at the bottom.
        let topY = y + h * 0.72
        p.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.08))
        p.addCurve(to: CGPoint(x: x + w * 0.02, y: topY),
                   control1: CGPoint(x: x + w * 0.30, y: y + h * 0.32),
                   control2: CGPoint(x: x + w * 0.02, y: y + h * 0.48))
        p.addArc(center: CGPoint(x: x + w * 0.26, y: topY),
                 radius: w * 0.24, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addArc(center: CGPoint(x: x + w * 0.74, y: topY),
                 radius: w * 0.24, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.08),
                   control1: CGPoint(x: x + w * 0.98, y: y + h * 0.48),
                   control2: CGPoint(x: x + w * 0.70, y: y + h * 0.32))
        p.closeSubpath()
        return p
    }
}

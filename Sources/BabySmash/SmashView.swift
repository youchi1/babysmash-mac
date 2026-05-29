import AppKit
import QuartzCore

/// The full-window canvas. Spawns and animates figures, handles mouse drawing
/// and clicks, and draws a playful custom cursor.
final class SmashView: NSView {
    weak var controller: AppController?
    var isPrimary = false

    private let canvas = CALayer()
    private let mouseLayer = CALayer()
    private let cursorLayer = CALayer()
    private var infoLayer: CATextLayer?

    private var figures: [Figure] = []
    private var mouseEllipses: [CALayer] = []
    private var trackingArea: NSTrackingArea?

    // Set when a mouse-down lands on a figure, so the following drag animates
    // the figure instead of drawing.
    private var suppressDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayers()
        applySettings()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unused") }

    // Let clicks work on a non-key window (e.g. the second monitor) immediately,
    // instead of being swallowed just to focus the window first.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private func setupLayers() {
        guard let root = layer else { return }
        for sub in [canvas, mouseLayer] {
            sub.frame = bounds
            sub.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            root.addSublayer(sub)
        }
        // Custom cursor drawn above everything; its image is set in applySettings().
        cursorLayer.zPosition = 10_000
        cursorLayer.anchorPoint = CGPoint(x: 0.25, y: 0.75) // tip near the pointer
        cursorLayer.shadowColor = NSColor.black.cgColor
        cursorLayer.shadowOpacity = 0.35
        cursorLayer.shadowRadius = 3
        cursorLayer.contentsScale = window?.backingScaleFactor ?? 2
        root.addSublayer(cursorLayer)
    }

    /// Applies live-changeable settings: the cursor shape and the (optional)
    /// transparent background.
    func applySettings() {
        let transparent = Settings.shared.transparentBackground
        layer?.backgroundColor = transparent
            ? NSColor.clear.cgColor
            : NSColor(white: 0.96, alpha: 1).cgColor
        applyCursor()
    }

    private func applyCursor() {
        let isHand = Settings.shared.cursorType == "Hand"
        let symbol = isHand ? "hand.point.up.left.fill" : "cursorarrow"
        let color: NSColor = isHand ? .systemYellow : .systemPink
        if let image = Self.tintedSymbol(symbol, color: color, pointSize: 34) {
            cursorLayer.contents = image
            cursorLayer.bounds = CGRect(origin: .zero, size: image.size)
        }
    }

    /// Renders an SF Symbol as a solid-tinted image for use as the cursor.
    private static func tintedSymbol(_ name: String, color: NSColor, pointSize: CGFloat) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        symbol.isTemplate = true
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        let rect = NSRect(origin: .zero, size: symbol.size)
        symbol.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        tinted.unlockFocus()
        return tinted
    }

    func showInfoLabel() {
        let text = CATextLayer()
        text.string = "BabySmash!\nPress any key to start!\nPress ESC twice to exit, ⌥O for options"
        text.fontSize = 22
        text.foregroundColor = NSColor(white: 0.3, alpha: 1).cgColor
        text.alignmentMode = .left
        text.isWrapped = true
        text.contentsScale = window?.backingScaleFactor ?? 2
        text.frame = CGRect(x: 24, y: bounds.height - 130, width: 700, height: 110)
        text.autoresizingMask = [.layerMaxXMargin, .layerMinYMargin]
        layer?.addSublayer(text)
        infoLayer = text
    }

    func hideInfoLabel() {
        infoLayer?.removeFromSuperlayer()
        infoLayer = nil
    }

    override func layout() {
        super.layout()
        canvas.frame = bounds
        mouseLayer.frame = bounds
    }

    // MARK: - Figures

    func addFigure(_ template: FigureTemplate) {
        let settings = Settings.shared
        let figure = FigureFactory.make(template, showFaces: settings.facesOnShapes)
        let size = figure.size

        let maxX = max(1, bounds.width - size.width)
        let maxY = max(1, bounds.height - size.height)
        let x = CGFloat(Rand.between(0, Int(maxX)))
        let y = CGFloat(Rand.between(0, Int(maxY)))
        figure.layer.position = CGPoint(x: x + size.width / 2, y: y + size.height / 2)
        figure.layer.contentsScale = window?.backingScaleFactor ?? 2

        canvas.addSublayer(figure.layer)
        figures.append(figure)

        applySpawnAnimation(figure.layer)

        if settings.fadeAway && !settings.sessionDisableFade {
            applyFade(figure.layer, after: settings.fadeAfter)
        }

        // Trim to the configured maximum.
        let clearAfter = max(1, settings.clearAfter)
        while figures.count > clearAfter {
            let old = figures.removeFirst()
            old.layer.removeFromSuperlayer()
        }
    }

    private func applySpawnAnimation(_ layer: CALayer) {
        let duration = 1.0
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.0
        scale.toValue = 1.0

        let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        rotate.fromValue = CGFloat.pi * 2
        rotate.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scale, rotate]
        group.duration = duration
        group.timingFunction = randomEaseOut()
        layer.add(group, forKey: "spawn")
    }

    private func randomEaseOut() -> CAMediaTimingFunction {
        // A few overshoot-ish ease-out curves for variety.
        let curves: [(Float, Float, Float, Float)] = [
            (0.34, 1.56, 0.64, 1.0),   // back-ish
            (0.22, 1.0, 0.36, 1.0),    // expo-ish
            (0.0, 0.0, 0.2, 1.0),      // quad
            (0.16, 1.2, 0.3, 1.0),     // elastic-ish
        ]
        let c = curves[Int.random(in: 0..<curves.count)]
        return CAMediaTimingFunction(controlPoints: c.0, c.1, c.2, c.3)
    }

    private func applyFade(_ layer: CALayer, after seconds: Double) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.duration = seconds
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        layer.opacity = 0
        layer.add(fade, forKey: "fade")
    }

    /// Animates the trailing letters of a detected word into a neat row.
    func animateWord(_ word: String) {
        let letters = figures.suffix(while: { $0.isLetter })
        guard letters.count >= word.count else { return }
        let used = Array(letters.suffix(word.count))

        let centerX = used.map { $0.layer.position.x }.reduce(0, +) / CGFloat(used.count)
        let centerY = used.map { $0.layer.position.y }.reduce(0, +) / CGFloat(used.count)
        let totalWidth = used.map { $0.size.width }.reduce(0, +)
        var cursorX = centerX - totalWidth / 2

        for figure in used {
            let target = CGPoint(x: cursorX + figure.size.width / 2, y: centerY)
            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(point: figure.layer.position)
            move.toValue = NSValue(point: target)
            move.duration = 1.2
            move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            move.fillMode = .forwards
            move.isRemovedOnCompletion = false
            figure.layer.position = target
            figure.layer.add(move, forKey: "word")
            cursorX += figure.size.width
        }
    }

    // MARK: - Mouse

    private func figureAt(_ point: CGPoint) -> Figure? {
        for figure in figures.reversed() where figure.layer.opacity > 0.1 {
            let half = CGSize(width: figure.size.width / 2, height: figure.size.height / 2)
            let rect = CGRect(x: figure.layer.position.x - half.width,
                              y: figure.layer.position.y - half.height,
                              width: figure.size.width, height: figure.size.height)
            if rect.contains(point) { return figure }
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let figure = figureAt(point) {
            applyClickAnimation(figure.layer)
            controller?.playLaugh()
            suppressDrag = true // clicking a figure should not start drawing
            return
        }
        suppressDrag = false
        drawEllipse(at: point)
        controller?.playSound("smallbumblebee-short.wav")
    }

    // Dragging (button held) draws and buzzes, regardless of the mouse-draw
    // setting: the held button is the "click condition".
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        moveCursor(to: point)
        guard !suppressDrag else { return }
        draw(at: point)
    }

    // Plain movement draws and buzzes only when the mouse-draw setting is on.
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        moveCursor(to: point)
        if Settings.shared.mouseDraw {
            draw(at: point)
        }
    }

    /// Draw an ellipse on every move (original cadence) and trigger the buzz.
    private func draw(at point: CGPoint) {
        drawEllipse(at: point)
        controller?.playDrawSound()
    }

    override func scrollWheel(with event: NSEvent) {
        // Zoom the figure under the cursor bigger/smaller, like the original.
        let point = convert(event.locationInWindow, from: nil)
        if event.deltaY != 0, let figure = figureAt(point) {
            // Per-event factor proportional to scroll amount (macOS sends many
            // small events per gesture), clamped to a sane range.
            let factor = 1 + Double(event.deltaY) * 0.04
            let newScale = min(max(figure.scale * CGFloat(factor), 0.3), 5.0)
            let anim = CABasicAnimation(keyPath: "transform.scale")
            anim.fromValue = figure.scale
            anim.toValue = newScale
            anim.duration = 0.25
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
            figure.layer.transform = CATransform3DMakeScale(newScale, newScale, 1)
            figure.layer.add(anim, forKey: "zoom")
            figure.scale = newScale
        }
        controller?.playWheelSound(event.deltaY >= 0 ? "rising.wav" : "falling.wav")
    }

    private func drawEllipse(at point: CGPoint) {
        let color = Palette.random()
        let size: CGFloat = 50
        // Lightweight: a single shape layer with a solid fill (no gradient/mask
        // sublayer), since these are created rapidly during drawing.
        let dot = CAShapeLayer()
        dot.path = CGPath(ellipseIn: CGRect(x: -size/2, y: -size/2, width: size, height: size), transform: nil)
        dot.fillColor = color.color.cgColor
        dot.strokeColor = color.lightenOrDarken(-60).cgColor
        dot.lineWidth = 2
        dot.position = point
        mouseLayer.addSublayer(dot)
        mouseEllipses.append(dot)

        while mouseEllipses.count > 30 {
            mouseEllipses.removeFirst().removeFromSuperlayer()
        }
    }

    private func applyClickAnimation(_ layer: CALayer) {
        switch Int.random(in: 0..<4) {
        case 0: // jiggle
            let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            a.values = [0, 0.17, 0, -0.17, 0, 0.08, 0, -0.08, 0]
            a.duration = 0.5
            layer.add(a, forKey: "click")
        case 1: // throb
            let a = CAKeyframeAnimation(keyPath: "transform.scale")
            a.values = [1, 1.15, 1, 0.9, 1, 1.06, 1]
            a.duration = 0.5
            layer.add(a, forKey: "click")
        case 2: // full spin
            let a = CABasicAnimation(keyPath: "transform.rotation.z")
            a.fromValue = 0
            a.toValue = CGFloat.pi * 2
            a.duration = 0.6
            layer.add(a, forKey: "click")
        default: // snap (vertical squash)
            let a = CAKeyframeAnimation(keyPath: "transform.scale.y")
            a.values = [1, 0.1, 1]
            a.duration = 0.35
            layer.add(a, forKey: "click")
        }
    }

    // MARK: - Cursor

    private func moveCursor(to point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cursorLayer.position = point
        CATransaction.commit()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { NSCursor.hide() }
    override func mouseExited(with event: NSEvent) { NSCursor.unhide() }

    private func starPath(radius: CGFloat) -> CGPath {
        let inner = radius * 0.42
        var pts: [CGPoint] = []
        var angle = -CGFloat.pi / 2
        for i in 0..<10 {
            let r = (i % 2 == 0) ? radius : inner
            pts.append(CGPoint(x: r * cos(angle), y: r * sin(angle)))
            angle += .pi / 5
        }
        let p = CGMutablePath()
        p.addLines(between: pts)
        p.closeSubpath()
        return p
    }
}

private extension Array {
    /// Returns the longest trailing run of elements satisfying `predicate`.
    func suffix(while predicate: (Element) -> Bool) -> [Element] {
        var result: [Element] = []
        for element in reversed() {
            if predicate(element) { result.insert(element, at: 0) } else { break }
        }
        return result
    }
}

import AppKit

class DockAnimationManager {
    static let shared = DockAnimationManager()
    
    private var timer: Timer?
    private var isAnimating = false
    private var angle: CGFloat = 0
    private var baseIcon: NSImage?
    
    private init() {
        loadBaseIcon()
    }
    
    private func loadBaseIcon() {
        #if SWIFT_PACKAGE
        if let imagePath = Bundle.module.path(forResource: "app_icon", ofType: "png") {
            baseIcon = NSImage(contentsOfFile: imagePath)
        }
        #else
        baseIcon = NSImage(named: "AppIcon")
        #endif
        if baseIcon == nil {
            baseIcon = NSApplication.shared.applicationIconImage
        }
    }
    
    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        if baseIcon == nil { loadBaseIcon() }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                self?.stepAnimation()
            }
        }
    }
    
    func updateBadge(count: Int) {
        DispatchQueue.main.async {
            if count > 0 {
                NSApp.dockTile.badgeLabel = "\(count)"
            } else {
                NSApp.dockTile.badgeLabel = nil
            }
        }
    }
    
    private func stepAnimation() {
        guard isAnimating else { return }
        angle += 0.25
        if angle > .pi * 2 { angle = 0 }
        
        guard let base = baseIcon else { return }
        let size = NSSize(width: 128, height: 128)
        let composited = NSImage(size: size)
        
        composited.lockFocus()
        // 1. Draw base application icon
        base.draw(in: NSRect(origin: .zero, size: size))
        
        // 2. Draw download badge container
        let badgeRect = NSRect(x: size.width - 44, y: 4, width: 40, height: 40)
        let bgCircle = NSBezierPath(ovalIn: badgeRect)
        NSColor(calibratedRed: 0.1, green: 0.12, blue: 0.18, alpha: 0.9).setFill()
        bgCircle.fill()
        
        // 3. Pulsing glowing stroke
        let pulseAlpha = 0.5 + 0.5 * sin(angle * 2)
        NSColor.systemBlue.withAlphaComponent(pulseAlpha).setStroke()
        let ring = NSBezierPath(ovalIn: badgeRect.insetBy(dx: 2, dy: 2))
        ring.lineWidth = 2.5
        ring.stroke()
        
        // 4. Bouncing download arrow inside badge
        let arrowOffset = CGFloat(2.0 * sin(angle * 3))
        if let arrow = NSImage(systemSymbolName: "arrow.down", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            if let configured = arrow.withSymbolConfiguration(config) {
                let tinted = configured.copy() as? NSImage ?? configured
                tinted.lockFocus()
                NSColor.white.set()
                let imageRect = NSRect(origin: .zero, size: tinted.size)
                imageRect.fill(using: .sourceAtop)
                tinted.unlockFocus()
                
                let drawRect = NSRect(
                    x: badgeRect.origin.x + (badgeRect.width - 20) / 2,
                    y: badgeRect.origin.y + (badgeRect.height - 20) / 2 + arrowOffset,
                    width: 20,
                    height: 20
                )
                tinted.draw(in: drawRect)
            }
        }
        
        composited.unlockFocus()
        NSApplication.shared.applicationIconImage = composited
    }
    
    func stopAnimation() {
        isAnimating = false
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            NSApp.dockTile.badgeLabel = nil
            if let base = self.baseIcon {
                NSApplication.shared.applicationIconImage = base
            }
        }
    }
}

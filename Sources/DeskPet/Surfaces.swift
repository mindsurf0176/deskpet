import AppKit
import CoreGraphics

struct Surface: Equatable {
    var id: UInt32
    var minX: CGFloat
    var maxX: CGFloat
    var y: CGFloat

    var isFloor: Bool { id == 0 }

    func contains(x: CGFloat) -> Bool {
        x >= minX && x <= maxX
    }
}

enum SurfaceScanner {
    static func floor(in screen: NSRect) -> Surface {
        Surface(id: 0, minX: screen.minX, maxX: screen.maxX, y: screen.minY)
    }

    static func ledges(
        excluding windowNumbers: Set<Int>,
        screen: NSRect,
        petHeight: CGFloat
    ) -> [Surface] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return [floor(in: screen)]
        }

        let maxSitY = screen.maxY - max(48, petHeight * 0.45)
        var occupied: [NSRect] = []
        var ledges: [Surface] = []
        ledges.append(floor(in: screen))

        for rec in info {
            let number = intValue(rec[kCGWindowNumber as String])
            if windowNumbers.contains(number) { continue }
            let layer = intValue(rec[kCGWindowLayer as String])
            if layer != 0 { continue }
            let alpha = cgFloat(rec[kCGWindowAlpha as String]) ?? 1
            if alpha < 0.85 { continue }
            guard let quartz = rectValue(rec[kCGWindowBounds as String]) else { continue }
            let cocoa = cocoaRect(from: quartz)
            if cocoa.width < 260 || cocoa.height < 70 { continue }
            if cocoa.width >= screen.width - 8 && cocoa.height >= screen.height - 8 { continue }
            if !cocoa.intersects(screen.insetBy(dx: -40, dy: -40)) { continue }
            if cocoa.maxY > maxSitY { continue }

            let topBand = NSRect(x: cocoa.minX, y: cocoa.maxY - 3, width: cocoa.width, height: 6)
            let covered = occupied.contains { $0.intersects(topBand) }
            occupied.append(cocoa)
            if covered { continue }

            ledges.append(
                Surface(
                    id: UInt32(truncatingIfNeeded: number),
                    minX: cocoa.minX,
                    maxX: cocoa.maxX,
                    y: cocoa.maxY
                )
            )
        }
        return ledges
    }

    static func support(
        feetX: CGFloat,
        feetY: CGFloat,
        width: CGFloat,
        ledges: [Surface]
    ) -> Surface {
        let mid = feetX + width / 2
        let below = ledges.filter { $0.contains(x: mid) && $0.y <= feetY + 10 }
        return below.max(by: { $0.y < $1.y }) ?? ledges.first { $0.isFloor } ?? Surface(id: 0, minX: 0, maxX: 0, y: 0)
    }

    private static func cocoaRect(from quartz: CGRect) -> NSRect {
        let mainH = CGDisplayBounds(CGMainDisplayID()).height
        return NSRect(
            x: quartz.origin.x,
            y: mainH - quartz.origin.y - quartz.height,
            width: quartz.width,
            height: quartz.height
        )
    }

    private static func rectValue(_ raw: Any?) -> CGRect? {
        if let rect = raw as? CGRect { return rect }
        guard let dict = raw as? [String: Any] else { return nil }
        let x = cgFloat(dict["X"]) ?? 0
        let y = cgFloat(dict["Y"]) ?? 0
        let w = cgFloat(dict["Width"]) ?? 0
        let h = cgFloat(dict["Height"]) ?? 0
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func intValue(_ raw: Any?) -> Int {
        if let n = raw as? Int { return n }
        if let n = raw as? NSNumber { return n.intValue }
        return -1
    }

    private static func cgFloat(_ raw: Any?) -> CGFloat? {
        if let n = raw as? CGFloat { return n }
        if let n = raw as? Double { return CGFloat(n) }
        if let n = raw as? NSNumber { return CGFloat(truncating: n) }
        return nil
    }
}


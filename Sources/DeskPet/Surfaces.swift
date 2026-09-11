import AppKit
import CoreGraphics

enum Face: Equatable {
    case floor
    case top
    case left
    case right

    var isVertical: Bool { self == .left || self == .right }
}

enum PetFacing: Equatable {
    case upright
    case left
    case right
}

struct Surface: Equatable {
    var id: UInt32
    var face: Face
    var minAlong: CGFloat
    var maxAlong: CGFloat
    var depth: CGFloat
    var bounds: NSRect
    var outside: Bool

    var isFloor: Bool { face == .floor }

    func contains(along value: CGFloat) -> Bool {
        value >= minAlong && value <= maxAlong
    }

    func origin(chrome: NSSize, along: CGFloat) -> NSPoint {
        let clamped = min(max(along, minAlong), max(minAlong, maxAlong - alongSpan(chrome: chrome)))
        switch face {
        case .floor, .top:
            return NSPoint(x: clamped, y: depth)
        case .left:
            let x = outside ? depth - chrome.width : depth
            return NSPoint(x: x, y: clamped)
        case .right:
            let x = outside ? depth : depth - chrome.width
            return NSPoint(x: x, y: clamped)
        }
    }

    func alongSpan(chrome: NSSize) -> CGFloat {
        face.isVertical ? chrome.height : chrome.width
    }

    func along(of panelOrigin: NSPoint) -> CGFloat {
        face.isVertical ? panelOrigin.y : panelOrigin.x
    }
}

enum SurfaceScanner {
    static let screenLeftID: UInt32 = .max - 1
    static let screenRightID: UInt32 = .max - 2

    static func floor(in screen: NSRect) -> Surface {
        Surface(
            id: 0,
            face: .floor,
            minAlong: screen.minX,
            maxAlong: screen.maxX,
            depth: screen.minY,
            bounds: screen,
            outside: false
        )
    }

    static func ledges(
        excluding windowNumbers: Set<Int>,
        screen: NSRect,
        petSize: NSSize
    ) -> [Surface] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return screenEdges(screen: screen) + [floor(in: screen)]
        }

        let long = max(petSize.width, petSize.height)
        let maxSitY = screen.maxY - max(48, petSize.height * 0.45)
        var occupied: [NSRect] = []
        var ledges: [Surface] = []
        ledges.append(contentsOf: screenEdges(screen: screen))
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
            if cocoa.width < 240 || cocoa.height < 80 { continue }
            if cocoa.width >= screen.width - 8 && cocoa.height >= screen.height - 8 { continue }
            if !cocoa.intersects(screen.insetBy(dx: -40, dy: -40)) { continue }

            occupied.append(cocoa)
            let id = UInt32(truncatingIfNeeded: number)

            if cocoa.maxY <= maxSitY {
                let topBand = NSRect(x: cocoa.minX, y: cocoa.maxY - 3, width: cocoa.width, height: 6)
                let covered = occupied.dropLast().contains { $0.intersects(topBand) }
                if !covered {
                    ledges.append(
                        Surface(
                            id: id,
                            face: .top,
                            minAlong: cocoa.minX,
                            maxAlong: cocoa.maxX,
                            depth: cocoa.maxY,
                            bounds: cocoa,
                            outside: false
                        )
                    )
                }
            }

            if cocoa.height >= 120, cocoa.minX - long >= screen.minX + 4 {
                ledges.append(
                    Surface(
                        id: id,
                        face: .left,
                        minAlong: cocoa.minY,
                        maxAlong: cocoa.maxY,
                        depth: cocoa.minX,
                        bounds: cocoa,
                        outside: true
                    )
                )
            }
            if cocoa.height >= 120, cocoa.maxX + long <= screen.maxX - 4 {
                ledges.append(
                    Surface(
                        id: id,
                        face: .right,
                        minAlong: cocoa.minY,
                        maxAlong: cocoa.maxY,
                        depth: cocoa.maxX,
                        bounds: cocoa,
                        outside: true
                    )
                )
            }
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
        let below = ledges.filter {
            !$0.face.isVertical && $0.contains(along: mid) && $0.depth <= feetY + 10
        }
        return below.max(by: { $0.depth < $1.depth })
            ?? ledges.first { $0.isFloor }
            ?? Surface(id: 0, face: .floor, minAlong: 0, maxAlong: 0, depth: 0, bounds: .zero, outside: false)
    }

    static func sibling(_ ledges: [Surface], of surface: Surface, face: Face) -> Surface? {
        ledges.first { $0.id == surface.id && $0.face == face }
    }

    private static func screenEdges(screen: NSRect) -> [Surface] {
        [
            Surface(
                id: screenLeftID,
                face: .left,
                minAlong: screen.minY,
                maxAlong: screen.maxY,
                depth: screen.minX,
                bounds: screen,
                outside: false
            ),
            Surface(
                id: screenRightID,
                face: .right,
                minAlong: screen.minY,
                maxAlong: screen.maxY,
                depth: screen.maxX,
                bounds: screen,
                outside: false
            ),
        ]
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

enum ImageRotate {
    static func turn(_ image: CGImage, facing: PetFacing) -> CGImage {
        guard facing != .upright else { return image }
        let radians: CGFloat = facing == .left ? .pi / 2 : -.pi / 2
        let width = image.height
        let height = image.width
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.interpolationQuality = .none
        ctx.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        ctx.rotate(by: radians)
        ctx.translateBy(x: -CGFloat(image.width) / 2, y: -CGFloat(image.height) / 2)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }
}


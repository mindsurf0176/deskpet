import AppKit
import QuartzCore

final class CaptionView: NSView {
    private let effect = NSVisualEffectView()
    private let label = NSTextField(labelWithString: "")
    private let maskLayer = CAShapeLayer()

    var text: String = "" {
        didSet {
            label.stringValue = text
            needsLayout = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.mask = maskLayer
        addSubview(effect)

        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func layout() {
        super.layout()
        effect.frame = bounds
        let bubble = CGRect(x: 0, y: 6, width: bounds.width, height: max(0, bounds.height - 6))
        label.frame = bubble.insetBy(dx: 8, dy: 3)
        let path = CGMutablePath()
        path.addRoundedRect(in: bubble, cornerWidth: 11, cornerHeight: 11)
        let mid = bounds.midX
        path.move(to: CGPoint(x: mid - 5.5, y: 6))
        path.addLine(to: CGPoint(x: mid, y: 0.5))
        path.addLine(to: CGPoint(x: mid + 5.5, y: 6))
        path.closeSubpath()
        maskLayer.frame = bounds
        maskLayer.path = path
    }
}

enum PixelHit {
    static func opaque(_ image: CGImage, at point: NSPoint, in size: NSSize, slop: CGFloat) -> Bool {
        guard size.width > 1, size.height > 1 else { return false }
        let nx = point.x / size.width
        let ny = point.y / size.height
        let pad = slop / max(size.width, size.height)
        if nx < -pad || nx > 1 + pad || ny < -pad || ny > 1 + pad {
            return false
        }
        let x = min(max(nx, 0), 1) * CGFloat(max(image.width - 1, 1))
        let y = (1 - min(max(ny, 0), 1)) * CGFloat(max(image.height - 1, 1))
        let radius = max(2, slop * CGFloat(image.width) / size.width)
        return sample(image, x: x, y: y, radius: radius)
    }

    private static func sample(_ image: CGImage, x: CGFloat, y: CGFloat, radius: CGFloat) -> Bool {
        let r = max(1, Int(radius.rounded(.up)))
        let side = r * 2 + 1
        let rect = CGRect(
            x: Int(x.rounded()) - r,
            y: Int(y.rounded()) - r,
            width: side,
            height: side
        )
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let cropRect = rect.intersection(bounds)
        guard !cropRect.isNull, cropRect.width >= 1, cropRect.height >= 1,
              let crop = image.cropping(to: cropRect)
        else { return false }

        let width = crop.width
        let height = crop.height
        let count = width * height * 4
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        data.initialize(repeating: 0, count: count)
        defer { data.deallocate() }

        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return true }
        ctx.interpolationQuality = .none
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        var index = 3
        while index < count {
            if data[index] > 28 { return true }
            index += 4
        }
        return false
    }
}

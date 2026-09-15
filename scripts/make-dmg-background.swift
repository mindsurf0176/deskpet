#!/usr/bin/env swift
import AppKit

// Renders the disk image backdrop at 1x and 2x into a single TIFF so the
// installer window stays sharp on Retina displays.

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: make-dmg-background.swift <background.tiff>\n", stderr)
    exit(2)
}

let dest = URL(fileURLWithPath: CommandLine.arguments[1])
let width: CGFloat = 640
let height: CGFloat = 400
let iconRow: CGFloat = 205      // Finder icon centre, measured from the top
let appColumn: CGFloat = 170
let applicationsColumn: CGFloat = 470

let cream = NSColor(calibratedRed: 0.96, green: 0.84, blue: 0.62, alpha: 1)

func fromTop(_ y: CGFloat) -> CGFloat { height - y }

func centered(_ text: String, font: NSFont, color: NSColor, top: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributed = NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style,
    ])
    let box = NSRect(x: 0, y: fromTop(top) - font.ascender, width: width, height: font.ascender * 2)
    attributed.draw(in: box)
}

func plate(centerX: CGFloat) {
    let side: CGFloat = 176
    let rect = NSRect(
        x: centerX - side / 2,
        y: fromTop(iconRow) - side / 2,
        width: side,
        height: side
    )
    let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    NSColor(calibratedWhite: 1, alpha: 0.05).setFill()
    path.fill()
    NSColor(calibratedWhite: 1, alpha: 0.09).setStroke()
    path.lineWidth = 1
    path.stroke()
}

func arrow() {
    let y = fromTop(iconRow)
    let start = appColumn + 110
    let end = applicationsColumn - 110
    let head: CGFloat = 13
    cream.withAlphaComponent(0.5).setStroke()
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: start, y: y))
    shaft.line(to: NSPoint(x: end - head, y: y))
    shaft.lineWidth = 2
    shaft.lineCapStyle = .round
    shaft.stroke()
    let tip = NSBezierPath()
    tip.move(to: NSPoint(x: end - head, y: y + head * 0.72))
    tip.line(to: NSPoint(x: end, y: y))
    tip.line(to: NSPoint(x: end - head, y: y - head * 0.72))
    tip.lineWidth = 2
    tip.lineCapStyle = .round
    tip.lineJoinStyle = .round
    tip.stroke()
}

func draw() {
    let backdrop = NSGradient(
        starting: NSColor(calibratedRed: 0.17, green: 0.14, blue: 0.12, alpha: 1),
        ending: NSColor(calibratedRed: 0.08, green: 0.07, blue: 0.06, alpha: 1)
    )
    backdrop?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

    centered("DeskPet", font: .systemFont(ofSize: 30, weight: .semibold), color: cream, top: 62)
    centered(
        "Drag DeskPet onto Applications",
        font: .systemFont(ofSize: 14, weight: .medium),
        color: NSColor(calibratedWhite: 1, alpha: 0.72),
        top: 92
    )
    centered(
        "DeskPet을 Applications 폴더로 옮기세요",
        font: .systemFont(ofSize: 13),
        color: NSColor(calibratedWhite: 1, alpha: 0.5),
        top: 114
    )

    plate(centerX: appColumn)
    plate(centerX: applicationsColumn)
    arrow()

    centered(
        "Open DeskPet, then choose Add a Pet",
        font: .systemFont(ofSize: 12),
        color: NSColor(calibratedWhite: 1, alpha: 0.46),
        top: 344
    )
    centered(
        "실행한 뒤 펫 추가에서 펫 폴더를 선택하세요",
        font: .systemFont(ofSize: 12),
        color: NSColor(calibratedWhite: 1, alpha: 0.32),
        top: 366
    )
}

func render(scale: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width) * scale,
        pixelsHigh: Int(height) * scale,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fputs("deskpet: could not allocate background bitmap\n", stderr)
        exit(1)
    }
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

guard let data = NSBitmapImageRep.representationOfImageReps(
    in: [render(scale: 1), render(scale: 2)],
    using: .tiff,
    properties: [:]
) else {
    fputs("deskpet: could not encode background\n", stderr)
    exit(1)
}
try data.write(to: dest)

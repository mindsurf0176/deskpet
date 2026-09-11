#!/usr/bin/env swift
import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: make-icns.swift <AppIcon.icns>\n", stderr)
    exit(2)
}

let dest = URL(fileURLWithPath: CommandLine.arguments[1])
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("DeskPet.iconset")
try? FileManager.default.removeItem(at: tmp)
try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

func png(size: CGFloat, scale: CGFloat) -> Data? {
    let px = Int(size * scale)
    let image = NSImage(size: NSSize(width: px, height: px))
    image.lockFocus()
    NSColor(calibratedRed: 0.17, green: 0.14, blue: 0.12, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: px, height: px), xRadius: CGFloat(px) * 0.22, yRadius: CGFloat(px) * 0.22).fill()
    let config = NSImage.SymbolConfiguration(pointSize: CGFloat(px) * 0.52, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let inset = CGFloat(px) * 0.18
        NSColor(calibratedRed: 0.96, green: 0.84, blue: 0.62, alpha: 1).set()
        symbol.draw(
            in: NSRect(x: inset, y: inset, width: CGFloat(px) - inset * 2, height: CGFloat(px) - inset * 2),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

let entries: [(String, CGFloat, CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2),
]

for (name, size, scale) in entries {
    if let data = png(size: size, scale: scale) {
        try data.write(to: tmp.appendingPathComponent(name))
    }
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", "-o", dest.path, tmp.path]
try proc.run()
proc.waitUntilExit()
try? FileManager.default.removeItem(at: tmp)
exit(proc.terminationStatus)


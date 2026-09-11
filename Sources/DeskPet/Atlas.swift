import AppKit
import ImageIO

enum PetState: String, CaseIterable {
    case idle
    case runningRight = "running-right"
    case runningLeft = "running-left"
    case waving
    case jumping
    case failed
    case waiting
    case running
    case review

    var row: Int {
        switch self {
        case .idle: return 0
        case .runningRight: return 1
        case .runningLeft: return 2
        case .waving: return 3
        case .jumping: return 4
        case .failed: return 5
        case .waiting: return 6
        case .running: return 7
        case .review: return 8
        }
    }

    var frameCount: Int {
        switch self {
        case .idle, .waiting, .running, .review: return 6
        case .runningRight, .runningLeft, .failed: return 8
        case .waving: return 4
        case .jumping: return 5
        }
    }

    var durationsMs: [Int] {
        switch self {
        case .idle: return [280, 110, 110, 140, 140, 320]
        case .runningRight, .runningLeft: return [120, 120, 120, 120, 120, 120, 120, 220]
        case .waving: return [140, 140, 140, 280]
        case .jumping: return [140, 140, 140, 140, 280]
        case .failed: return [140, 140, 140, 140, 140, 140, 140, 240]
        case .waiting: return [150, 150, 150, 150, 150, 260]
        case .running: return [120, 120, 120, 120, 120, 220]
        case .review: return [150, 150, 150, 150, 150, 280]
        }
    }

    var loops: Bool {
        switch self {
        case .waving, .jumping, .failed: return false
        default: return true
        }
    }
}

enum ActivityKind: String {
    case idle
    case running
    case waiting
    case failed
    case review
}

struct SpriteAtlas {
    static let cellWidth = 192
    static let cellHeight = 208
    static let columns = 8
    static let rows = 9

    let frames: [[CGImage]]

    static func load(from url: URL) throws -> SpriteAtlas {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let webp = CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
              ),
              let raster = rasterize(webp)
        else {
            throw AtlasError.unreadable(url.path)
        }
        var rows: [[CGImage]] = []
        rows.reserveCapacity(Self.rows)
        for row in 0..<Self.rows {
            var cols: [CGImage] = []
            cols.reserveCapacity(Self.columns)
            for col in 0..<Self.columns {
                let rect = CGRect(
                    x: col * Self.cellWidth,
                    y: row * Self.cellHeight,
                    width: Self.cellWidth,
                    height: Self.cellHeight
                )
                if let slice = raster.cropping(to: rect) {
                    cols.append(slice)
                } else if let empty = emptyCell() {
                    cols.append(empty)
                }
            }
            rows.append(cols)
        }
        return SpriteAtlas(frames: rows)
    }

    func image(state: PetState, frame: Int) -> CGImage? {
        let row = frames[state.row]
        guard !row.isEmpty else { return nil }
        let index = max(0, frame) % max(1, min(state.frameCount, row.count))
        return row[index]
    }

    private static func rasterize(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    private static func emptyCell() -> CGImage? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: cellWidth,
            height: cellHeight,
            bitsPerComponent: 8,
            bytesPerRow: cellWidth * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        return ctx.makeImage()
    }
}

enum AtlasError: Error {
    case unreadable(String)
}

import AppKit
import Foundation

struct DeskPetSettings: Equatable {
    var petID: String
    var scale: Double
    var x: Double?
    var y: Double?

    var clickThrough: Bool
    var captions: Bool
    var perch: Bool
    var gravity: Bool
    var sound: Bool
    var language: AppLanguage
    var tone: SpeechTone

    static let `default` = DeskPetSettings(
        petID: "sherry",
        scale: 0.5,
        x: nil,
        y: nil,
        clickThrough: true,
        captions: true,
        perch: true,
        gravity: true,
        sound: true,
        language: .auto,
        tone: .casual
    )
    static let minScale = 0.35
    static let maxScale = 1.5

    var clampedScale: Double {
        min(max(scale, Self.minScale), Self.maxScale)
    }

    var displaySize: NSSize {
        let s = CGFloat(clampedScale)
        return NSSize(
            width: CGFloat(SpriteAtlas.cellWidth) * s,
            height: CGFloat(SpriteAtlas.cellHeight) * s
        )
    }

    var origin: NSPoint? {
        guard let x, let y else { return nil }
        return NSPoint(x: x, y: y)
    }
}

struct PetCatalogItem: Equatable {
    var id: String
    var displayName: String
    var sheetURL: URL
}

enum PetCatalog {
    static var root: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/pets")
    }

    static func all() -> [PetCatalogItem] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [PetCatalogItem] = []
        for dir in dirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let jsonURL = dir.appendingPathComponent("pet.json")
            let sheetURL = dir.appendingPathComponent("spritesheet.webp")
            guard fm.fileExists(atPath: sheetURL.path) else { continue }
            let folderID = dir.lastPathComponent
            var id = folderID
            var name = folderID
            if let data = try? Data(contentsOf: jsonURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let raw = json["id"] as? String, !raw.isEmpty { id = raw }
                if let raw = json["displayName"] as? String, !raw.isEmpty { name = raw }
            }
            items.append(PetCatalogItem(id: id, displayName: name, sheetURL: sheetURL))
        }
        return items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    static func item(id: String) -> PetCatalogItem? {
        let items = all()
        return items.first { $0.id == id } ?? items.first { $0.id == "sherry" } ?? items.first
    }
}

enum ConfigStore {
    static var url: URL {
        PetCatalog.root.appendingPathComponent("deskpet-config.json")
    }

    static func load() -> DeskPetSettings {
        var settings = DeskPetSettings.default
        if let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let petID = json["petID"] as? String, !petID.isEmpty {
                settings.petID = petID
            }
            if let scale = json["scale"] as? Double {
                settings.scale = scale
            }
            if let x = json["x"] as? Double, let y = json["y"] as? Double {
                settings.x = x
                settings.y = y
            }
            if let clickThrough = json["clickThrough"] as? Bool {
                settings.clickThrough = clickThrough
            }
            if let captions = json["captions"] as? Bool {
                settings.captions = captions
            }
            if let perch = json["perch"] as? Bool {
                settings.perch = perch
            }
            if let sound = json["sound"] as? Bool {
                settings.sound = sound
            }
            if let gravity = json["gravity"] as? Bool {
                settings.gravity = gravity
            }
            if let raw = json["language"] as? String, let language = AppLanguage(rawValue: raw) {
                settings.language = language
            }
            if let raw = json["tone"] as? String, let tone = SpeechTone(rawValue: raw) {
                settings.tone = tone
            }
        } else if let legacy = PositionStore.load() {
            settings.x = legacy.x
            settings.y = legacy.y
        }
        if let env = ProcessInfo.processInfo.environment["DESKPET_ID"], !env.isEmpty {
            settings.petID = env
        }
        settings.scale = settings.clampedScale
        return settings
    }

    static func save(_ settings: DeskPetSettings) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var payload: [String: Any] = [
            "petID": settings.petID,
            "scale": settings.clampedScale,
            "clickThrough": settings.clickThrough,
            "captions": settings.captions,
            "perch": settings.perch,
            "gravity": settings.gravity,
            "sound": settings.sound,
            "language": settings.language.rawValue,
            "tone": settings.tone.rawValue,
        ]
        if let x = settings.x { payload["x"] = x }
        if let y = settings.y { payload["y"] = y }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

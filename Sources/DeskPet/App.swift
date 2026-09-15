import AppKit
import Darwin
import Foundation

@main
enum DeskPetMain {
    static func main() {
        acquireLock()
        let settings = ConfigStore.load()
        while PetCatalog.item(id: settings.petID) == nil {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            app.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Meet your desktop companion"
            alert.informativeText = "Add a pet to get started. Your companion reacts while you work and lets you know when your coding agent is done.\n\n시작하려면 펫을 추가하세요. pet.json과 spritesheet.webp가 들어 있는 폴더를 선택하면 됩니다."
            alert.addButton(withTitle: "Add a Pet · 펫 추가")
            alert.addButton(withTitle: "Setup Guide")
            alert.addButton(withTitle: "Quit")
            switch alert.runModal() {
            case .alertFirstButtonReturn: _ = PetImport.choose()
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(URL(string: "https://github.com/mindsurf0176/deskpet/blob/main/docs/pets.md")!)
            default: exit(0)
            }
        }
        guard let pet = PetCatalog.item(id: settings.petID) else { return }
        let atlas: SpriteAtlas
        do {
            atlas = try SpriteAtlas.load(from: pet.sheetURL)
        } catch {
            fputs("deskpet: failed to load spritesheet: \(error)\n", stderr)
            exit(1)
        }
        var resolved = settings
        resolved.petID = pet.id

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate(atlas: atlas, settings: resolved)
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }

    private static func acquireLock() {
        let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/pets")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("deskpet.lock").path
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            fputs("deskpet already running\n", stderr)
            exit(0)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller: PetController

    init(atlas: SpriteAtlas, settings: DeskPetSettings) {
        self.controller = PetController(atlas: atlas, settings: settings)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        controller.attachMouse()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.applicationWillTerminate()
    }
}

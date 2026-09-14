import AppKit
import Darwin
import Foundation

@main
enum DeskPetMain {
    static func main() {
        acquireLock()
        let settings = ConfigStore.load()
        guard let pet = PetCatalog.item(id: settings.petID) else {
            fputs("deskpet: no pets in \(PetCatalog.root.path)\n", stderr)
            fputs("Put a Codex hatch-pet at ~/.codex/pets/<id>/ (pet.json + spritesheet.webp)\n", stderr)
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            app.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Add a pet to DeskPet"
            alert.informativeText = "Place a pet folder containing pet.json and spritesheet.webp in ~/.codex/pets, then reopen DeskPet. DeskPet does not include artwork."
            alert.addButton(withTitle: "Open Pets Folder")
            alert.addButton(withTitle: "Setup Guide")
            alert.addButton(withTitle: "Quit")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(PetCatalog.root)
            } else if response == .alertSecondButtonReturn {
                NSWorkspace.shared.open(URL(string: "https://github.com/mindsurf0176/deskpet/blob/main/docs/pets.md")!)
            }
            exit(0)
        }
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

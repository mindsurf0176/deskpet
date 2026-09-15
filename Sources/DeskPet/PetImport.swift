import AppKit

enum PetImport {
    static func choose() -> Bool {
        let picker = NSOpenPanel()
        picker.title = "Add a pet · 펫 추가"
        picker.message = "Choose a folder containing pet.json and spritesheet.webp."
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.allowsMultipleSelection = false
        guard picker.runModal() == .OK, let source = picker.url else { return false }
        do {
            let metadata = try Data(contentsOf: source.appendingPathComponent("pet.json"))
            guard let json = try JSONSerialization.jsonObject(with: metadata) as? [String: Any],
                  let id = json["id"] as? String, !id.isEmpty,
                  id != ".", id != "..", !id.contains("/"), !id.contains("\\") else {
                throw NSError(domain: "DeskPet", code: 1, userInfo: [NSLocalizedDescriptionKey: "pet.json needs a valid pet ID."])
            }
            let sheet = source.appendingPathComponent("spritesheet.webp")
            _ = try SpriteAtlas.load(from: sheet)
            let destination = PetCatalog.root.appendingPathComponent(id)
            try FileManager.default.createDirectory(at: PetCatalog.root, withIntermediateDirectories: true)
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw NSError(domain: "DeskPet", code: 2, userInfo: [NSLocalizedDescriptionKey: "This pet is already installed. Select it in Settings."])
            }
            let staging = PetCatalog.root.appendingPathComponent(".import-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: staging) }
            try metadata.write(to: staging.appendingPathComponent("pet.json"))
            try FileManager.default.copyItem(at: sheet, to: staging.appendingPathComponent("spritesheet.webp"))
            try FileManager.default.moveItem(at: staging, to: destination)
            return true
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return false
        }
    }
}

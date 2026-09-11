import AppKit

final class SettingsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SettingsController: NSObject {
    private let panel: SettingsPanel
    private let petPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let slider = NSSlider()
    private let sizeLabel = NSTextField(labelWithString: "")
    private weak var owner: PetController?
    private var clickThroughBox: NSButton!
    private var captionsBox: NSButton!

    init(owner: PetController) {
        self.owner = owner
        self.panel = SettingsPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 168),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
        buildUI()
        panel.orderOut(nil)
    }

    func show(anchor: NSPoint? = nil) {
        reloadPets()
        syncControls()
        place(anchor: anchor)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func place(anchor: NSPoint?) {
        let size = panel.frame.size
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        var origin: NSPoint
        if let anchor {
            origin = NSPoint(x: anchor.x - size.width / 2, y: anchor.y - size.height - 8)
        } else {
            origin = NSPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
        }
        origin.x = min(max(origin.x, screen.minX + 16), screen.maxX - size.width - 16)
        origin.y = min(max(origin.y, screen.minY + 16), screen.maxY - size.height - 16)
        panel.setFrameOrigin(origin)
    }

    private func configurePanel() {
        panel.title = "DeskPet"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    }

    private func buildUI() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 168))
        panel.contentView = root

        let petCaption = caption(L10n.pet)
        petPopup.translatesAutoresizingMaskIntoConstraints = false
        petPopup.target = self
        petPopup.action = #selector(petChanged)

        let sizeRow = NSView()
        sizeRow.translatesAutoresizingMaskIntoConstraints = false
        let sizeCaption = caption(L10n.size)
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        sizeLabel.textColor = .secondaryLabelColor
        sizeLabel.alignment = .right
        sizeRow.addSubview(sizeCaption)
        sizeRow.addSubview(sizeLabel)

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minValue = DeskPetSettings.minScale
        slider.maxValue = DeskPetSettings.maxScale
        slider.numberOfTickMarks = 0
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(scaleChanged)

        let clickThrough = NSButton(checkboxWithTitle: L10n.clickThrough, target: self, action: #selector(clickThroughChanged))
        clickThrough.translatesAutoresizingMaskIntoConstraints = false
        clickThrough.font = .systemFont(ofSize: 12)
        let captions = NSButton(checkboxWithTitle: L10n.captions, target: self, action: #selector(captionsChanged))
        captions.translatesAutoresizingMaskIntoConstraints = false
        captions.font = .systemFont(ofSize: 12)
        self.clickThroughBox = clickThrough
        self.captionsBox = captions

        let ends = NSView()
        ends.translatesAutoresizingMaskIntoConstraints = false
        let small = hint(L10n.smaller)
        let large = hint(L10n.larger)
        large.alignment = .right
        ends.addSubview(small)
        ends.addSubview(large)

        root.addSubview(petCaption)
        root.addSubview(petPopup)
        root.addSubview(sizeRow)
        root.addSubview(slider)
        root.addSubview(ends)
        root.addSubview(clickThrough)
        root.addSubview(captions)

        NSLayoutConstraint.activate([
            petCaption.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            petCaption.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            petCaption.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),

            petPopup.topAnchor.constraint(equalTo: petCaption.bottomAnchor, constant: 6),
            petPopup.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            petPopup.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),

            sizeRow.topAnchor.constraint(equalTo: petPopup.bottomAnchor, constant: 16),
            sizeRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            sizeRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            sizeRow.heightAnchor.constraint(equalToConstant: 18),

            sizeCaption.leadingAnchor.constraint(equalTo: sizeRow.leadingAnchor),
            sizeCaption.centerYAnchor.constraint(equalTo: sizeRow.centerYAnchor),
            sizeLabel.trailingAnchor.constraint(equalTo: sizeRow.trailingAnchor),
            sizeLabel.centerYAnchor.constraint(equalTo: sizeRow.centerYAnchor),
            sizeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: sizeCaption.trailingAnchor, constant: 8),

            slider.topAnchor.constraint(equalTo: sizeRow.bottomAnchor, constant: 6),
            slider.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            slider.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),

            ends.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 2),
            ends.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            ends.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            ends.heightAnchor.constraint(equalToConstant: 16),

            small.leadingAnchor.constraint(equalTo: ends.leadingAnchor),
            small.centerYAnchor.constraint(equalTo: ends.centerYAnchor),
            large.trailingAnchor.constraint(equalTo: ends.trailingAnchor),
            large.centerYAnchor.constraint(equalTo: ends.centerYAnchor),

            clickThrough.topAnchor.constraint(equalTo: ends.bottomAnchor, constant: 14),
            clickThrough.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            clickThrough.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),

            captions.topAnchor.constraint(equalTo: clickThrough.bottomAnchor, constant: 6),
            captions.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            captions.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            captions.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
        ])
        panel.setContentSize(NSSize(width: 300, height: 236))
    }

    private func caption(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = .systemFont(ofSize: 12, weight: .semibold)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func hint(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = .systemFont(ofSize: 11)
        field.textColor = .tertiaryLabelColor
        return field
    }

    private func reloadPets() {
        petPopup.removeAllItems()
        let pets = PetCatalog.all()
        if pets.isEmpty {
            petPopup.addItem(withTitle: L10n.noPets)
            petPopup.isEnabled = false
            return
        }
        petPopup.isEnabled = true
        for pet in pets {
            petPopup.addItem(withTitle: pet.displayName)
            petPopup.lastItem?.representedObject = pet.id
        }
    }

    private func syncControls() {
        guard let owner else { return }
        let id = owner.currentPetID
        if let index = petPopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == id }) {
            petPopup.selectItem(at: index)
        }
        slider.doubleValue = owner.currentScale
        refreshSizeLabel(owner.currentScale)
        clickThroughBox.state = owner.clickThroughEnabled ? .on : .off
        captionsBox.state = owner.captionsEnabled ? .on : .off
    }

    private func refreshSizeLabel(_ scale: Double) {
        let size = DeskPetSettings(petID: "", scale: scale, x: nil, y: nil, clickThrough: true, captions: true).displaySize
        sizeLabel.stringValue = "\(Int(size.width.rounded()))×\(Int(size.height.rounded()))"
    }

    @objc private func petChanged() {
        guard let id = petPopup.selectedItem?.representedObject as? String else { return }
        owner?.applyPet(id: id)
    }

    @objc private func scaleChanged() {
        let scale = slider.doubleValue
        refreshSizeLabel(scale)
        owner?.applyScale(scale)
    }

    @objc private func clickThroughChanged() {
        owner?.applyClickThrough(clickThroughBox.state == .on)
    }

    @objc private func captionsChanged() {
        owner?.applyCaptions(captionsBox.state == .on)
    }
}

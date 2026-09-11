import AppKit
import QuartzCore

final class SettingsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class SettingsController: NSObject {
    private let panel: SettingsPanel
    private let petPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let tonePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let slider = NSSlider()
    private let sizeLabel = NSTextField(labelWithString: "")
    private weak var owner: PetController?
    private var clickThroughBox: NSSwitch!
    private var captionsBox: NSSwitch!
    private var perchBox: NSSwitch!
    private var gravityBox: NSSwitch!
    private var soundBox: NSSwitch!
    private var petCaption: NSTextField!
    private var sizeCaption: NSTextField!
    private var smallHint: NSTextField!
    private var largeHint: NSTextField!
    private var speechCaption: NSTextField!
    private var languageCaption: NSTextField!
    private var toneCaption: NSTextField!
    private var optionsCaption: NSTextField!
    private var clickThroughLabel: NSTextField!
    private var captionsLabel: NSTextField!
    private var perchLabel: NSTextField!
    private var gravityLabel: NSTextField!
    private var soundLabel: NSTextField!
    private var dismissMonitor: Any?
    private var keyMonitor: Any?

    init(owner: PetController) {
        self.owner = owner
        self.panel = SettingsPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 488),
            styleMask: [.borderless],
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
        reloadCopy()
        syncControls()
        place(anchor: anchor)
        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.installDismissMonitor()
        }
    }

    func dismiss() {
        removeDismissMonitor()
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
            self?.panel.alphaValue = 1
        })
    }

    private func installDismissMonitor() {
        removeDismissMonitor()
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.dismiss()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if event.window != self.panel {
                    self.dismiss()
                }
            }
            return event
        }
    }

    private func removeDismissMonitor() {
        if let dismissMonitor {
            NSEvent.removeMonitor(dismissMonitor)
            self.dismissMonitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func place(anchor: NSPoint?) {
        let size = panel.frame.size
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        var origin: NSPoint
        if let anchor {
            origin = NSPoint(x: anchor.x - size.width / 2, y: anchor.y - size.height - 10)
        } else {
            origin = NSPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
        }
        origin.x = min(max(origin.x, screen.minX + 16), screen.maxX - size.width - 16)
        origin.y = min(max(origin.y, screen.minY + 16), screen.maxY - size.height - 16)
        panel.setFrameOrigin(origin)
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
    }

    private func buildUI() {
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 300, height: 488))
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        effect.autoresizingMask = [.width, .height]
        panel.contentView = effect

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(root)

        let header = NSTextField(labelWithString: "DeskPet")
        header.translatesAutoresizingMaskIntoConstraints = false
        header.font = .systemFont(ofSize: 15, weight: .semibold)
        header.textColor = .labelColor

        petCaption = caption(L10n.pet)
        petPopup.translatesAutoresizingMaskIntoConstraints = false
        petPopup.target = self
        petPopup.action = #selector(petChanged)
        petPopup.controlSize = .regular

        let sizeRow = NSView()
        sizeRow.translatesAutoresizingMaskIntoConstraints = false
        sizeCaption = caption(L10n.size)
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        sizeLabel.textColor = .secondaryLabelColor
        sizeLabel.alignment = .right
        sizeRow.addSubview(sizeCaption)
        sizeRow.addSubview(sizeLabel)

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minValue = DeskPetSettings.minScale
        slider.maxValue = DeskPetSettings.maxScale
        slider.isContinuous = true
        slider.trackFillColor = .controlAccentColor
        slider.target = self
        slider.action = #selector(scaleChanged)

        let ends = NSView()
        ends.translatesAutoresizingMaskIntoConstraints = false
        smallHint = hint(L10n.smaller)
        largeHint = hint(L10n.larger)
        largeHint.alignment = .right
        ends.addSubview(smallHint)
        ends.addSubview(largeHint)

        let divider = NSBox()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.boxType = .separator

        speechCaption = caption(L10n.speech)
        let languageRow = labeledPopup(L10n.languageLabel, languagePopup, #selector(languageChanged))
        languageCaption = languageRow.1
        let toneRow = labeledPopup(L10n.toneLabel, tonePopup, #selector(toneChanged))
        toneCaption = toneRow.1
        let captions = toggleRow(L10n.captions, #selector(captionsChanged))
        captionsLabel = captions.2
        captionsBox = captions.1

        let divider2 = NSBox()
        divider2.translatesAutoresizingMaskIntoConstraints = false
        divider2.boxType = .separator

        optionsCaption = caption(L10n.options)
        let clickThrough = toggleRow(L10n.clickThrough, #selector(clickThroughChanged))
        clickThroughLabel = clickThrough.2
        clickThroughBox = clickThrough.1
        let perch = toggleRow(L10n.perch, #selector(perchChanged))
        perchLabel = perch.2
        perchBox = perch.1
        let gravity = toggleRow(L10n.gravity, #selector(gravityChanged))
        gravityLabel = gravity.2
        gravityBox = gravity.1
        let sound = toggleRow(L10n.sound, #selector(soundChanged))
        soundLabel = sound.2
        soundBox = sound.1

        root.addSubview(header)
        root.addSubview(petCaption)
        root.addSubview(petPopup)
        root.addSubview(sizeRow)
        root.addSubview(slider)
        root.addSubview(ends)
        root.addSubview(divider)
        root.addSubview(speechCaption)
        root.addSubview(languageRow.0)
        root.addSubview(toneRow.0)
        root.addSubview(captions.0)
        root.addSubview(divider2)
        root.addSubview(optionsCaption)
        root.addSubview(clickThrough.0)
        root.addSubview(perch.0)
        root.addSubview(gravity.0)
        root.addSubview(sound.0)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: effect.topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -16),

            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            petCaption.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            petCaption.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            petCaption.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            petPopup.topAnchor.constraint(equalTo: petCaption.bottomAnchor, constant: 6),
            petPopup.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            petPopup.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            sizeRow.topAnchor.constraint(equalTo: petPopup.bottomAnchor, constant: 14),
            sizeRow.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sizeRow.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            sizeRow.heightAnchor.constraint(equalToConstant: 16),

            sizeCaption.leadingAnchor.constraint(equalTo: sizeRow.leadingAnchor),
            sizeCaption.centerYAnchor.constraint(equalTo: sizeRow.centerYAnchor),
            sizeLabel.trailingAnchor.constraint(equalTo: sizeRow.trailingAnchor),
            sizeLabel.centerYAnchor.constraint(equalTo: sizeRow.centerYAnchor),
            sizeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: sizeCaption.trailingAnchor, constant: 8),

            slider.topAnchor.constraint(equalTo: sizeRow.bottomAnchor, constant: 6),
            slider.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            ends.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 2),
            ends.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            ends.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            ends.heightAnchor.constraint(equalToConstant: 14),

            smallHint.leadingAnchor.constraint(equalTo: ends.leadingAnchor),
            smallHint.centerYAnchor.constraint(equalTo: ends.centerYAnchor),
            largeHint.trailingAnchor.constraint(equalTo: ends.trailingAnchor),
            largeHint.centerYAnchor.constraint(equalTo: ends.centerYAnchor),

            divider.topAnchor.constraint(equalTo: ends.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            speechCaption.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),
            speechCaption.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            speechCaption.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            languageRow.0.topAnchor.constraint(equalTo: speechCaption.bottomAnchor, constant: 8),
            languageRow.0.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            languageRow.0.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            languageRow.0.heightAnchor.constraint(equalToConstant: 28),

            toneRow.0.topAnchor.constraint(equalTo: languageRow.0.bottomAnchor, constant: 2),
            toneRow.0.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            toneRow.0.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            toneRow.0.heightAnchor.constraint(equalToConstant: 28),

            captions.0.topAnchor.constraint(equalTo: toneRow.0.bottomAnchor, constant: 2),
            captions.0.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            captions.0.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            captions.0.heightAnchor.constraint(equalToConstant: 28),

            divider2.topAnchor.constraint(equalTo: captions.0.bottomAnchor, constant: 12),
            divider2.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            divider2.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            optionsCaption.topAnchor.constraint(equalTo: divider2.bottomAnchor, constant: 12),
            optionsCaption.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            optionsCaption.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            clickThrough.0.topAnchor.constraint(equalTo: optionsCaption.bottomAnchor, constant: 8),
            clickThrough.0.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            clickThrough.0.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            clickThrough.0.heightAnchor.constraint(equalToConstant: 28),

            perch.0.topAnchor.constraint(equalTo: clickThrough.0.bottomAnchor, constant: 2),
            perch.0.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            perch.0.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            perch.0.heightAnchor.constraint(equalToConstant: 28),

            gravity.0.topAnchor.constraint(equalTo: perch.0.bottomAnchor, constant: 2),
            gravity.0.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            gravity.0.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            gravity.0.heightAnchor.constraint(equalToConstant: 28),

            sound.0.topAnchor.constraint(equalTo: gravity.0.bottomAnchor, constant: 2),
            sound.0.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sound.0.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            sound.0.heightAnchor.constraint(equalToConstant: 28),
            sound.0.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        fillLanguagePopup()
        fillTonePopup()
        panel.setContentSize(NSSize(width: 300, height: 488))
    }

    private func toggleRow(_ title: String, _ action: Selector) -> (NSView, NSSwitch, NSTextField) {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        let toggle = NSSwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.controlSize = .small
        toggle.target = self
        toggle.action = action
        row.addSubview(label)
        row.addSubview(toggle)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -8),
        ])
        return (row, toggle, label)
    }

    private func labeledPopup(_ title: String, _ popup: NSPopUpButton, _ action: Selector) -> (NSView, NSTextField) {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.target = self
        popup.action = action
        popup.controlSize = .small
        row.addSubview(label)
        row.addSubview(popup)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            popup.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            popup.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 148),
            popup.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
        ])
        return (row, label)
    }

    private func caption(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = .systemFont(ofSize: 11, weight: .semibold)
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

    func reloadCopy() {
        petCaption.stringValue = L10n.pet
        sizeCaption.stringValue = L10n.size
        smallHint.stringValue = L10n.smaller
        largeHint.stringValue = L10n.larger
        speechCaption.stringValue = L10n.speech
        languageCaption.stringValue = L10n.languageLabel
        toneCaption.stringValue = L10n.toneLabel
        captionsLabel.stringValue = L10n.captions
        optionsCaption.stringValue = L10n.options
        clickThroughLabel.stringValue = L10n.clickThrough
        perchLabel.stringValue = L10n.perch
        gravityLabel.stringValue = L10n.gravity
        soundLabel.stringValue = L10n.sound
        fillLanguagePopup()
        fillTonePopup()
        syncControls()
    }

    private func fillLanguagePopup() {
        languagePopup.target = nil
        defer { languagePopup.target = self }
        let selected = languagePopup.selectedItem?.representedObject as? String
        languagePopup.removeAllItems()
        for language in AppLanguage.allCases {
            languagePopup.addItem(withTitle: language.menuTitle)
            languagePopup.lastItem?.representedObject = language.rawValue
        }
        if let selected, let index = languagePopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == selected }) {
            languagePopup.selectItem(at: index)
        }
    }

    private func fillTonePopup() {
        tonePopup.target = nil
        defer { tonePopup.target = self }
        let selected = tonePopup.selectedItem?.representedObject as? String
        tonePopup.removeAllItems()
        for tone in SpeechTone.allCases {
            tonePopup.addItem(withTitle: tone.menuTitle)
            tonePopup.lastItem?.representedObject = tone.rawValue
        }
        if let selected, let index = tonePopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == selected }) {
            tonePopup.selectItem(at: index)
        }
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
        perchBox.state = owner.perchEnabled ? .on : .off
        gravityBox.state = owner.gravityEnabled ? .on : .off
        soundBox.state = owner.soundEnabled ? .on : .off
        if let index = languagePopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == owner.currentLanguage.rawValue }) {
            languagePopup.selectItem(at: index)
        }
        if let index = tonePopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == owner.currentTone.rawValue }) {
            tonePopup.selectItem(at: index)
        }
    }

    private func refreshSizeLabel(_ scale: Double) {
        var settings = DeskPetSettings.default
        settings.scale = scale
        let size = settings.displaySize
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

    @objc private func perchChanged() {
        owner?.applyPerch(perchBox.state == .on)
    }

    @objc private func gravityChanged() {
        owner?.applyGravity(gravityBox.state == .on)
    }

    @objc private func soundChanged() {
        owner?.applySound(soundBox.state == .on)
    }

    @objc private func languageChanged() {
        guard let raw = languagePopup.selectedItem?.representedObject as? String,
              let language = AppLanguage(rawValue: raw) else { return }
        owner?.applyLanguage(language)
    }

    @objc private func toneChanged() {
        guard let raw = tonePopup.selectedItem?.representedObject as? String,
              let tone = SpeechTone(rawValue: raw) else { return }
        owner?.applyTone(tone)
    }
}

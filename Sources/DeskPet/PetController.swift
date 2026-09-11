import AppKit
import QuartzCore

final class PetView: NSView {
    var atlas: SpriteAtlas
    var state: PetState = .idle
    var frameIndex = 0
    var reducedMotion = false

    init(atlas: SpriteAtlas) {
        self.atlas = atlas
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.contentsGravity = .resize
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        present()
    }

    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }

    func present() {
        let image = reducedMotion
            ? atlas.image(state: .idle, frame: 0)
            : atlas.image(state: state, frame: frameIndex)
        layer?.contents = image
    }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetController: NSObject, NSWindowDelegate {
    private var atlas: SpriteAtlas
    private let view: PetView
    private let panel: PetPanel
    private var statusItem: NSStatusItem?
    private var hideMenuItem: NSMenuItem?
    private var timer: Timer?
    private var activity = ActivityKind.idle
    private var oneshot: PetState?
    private var dragging = false
    private var dragStart = NSPoint.zero
    private var windowStart = NSPoint.zero
    private var lastDragX: CGFloat = 0
    private var nextFrameAt: CFTimeInterval = 0
    private var nextWanderAt: CFTimeInterval = 0
    private var wanderTarget: CGFloat?
    private var lastProcessScan: CFTimeInterval = 0
    private var lastPluginRead: CFTimeInterval = 0
    private var lastWanderStep: CFTimeInterval = 0
    private var processKind = ActivityKind.idle
    private var scanning = false
    private var persistWork: DispatchWorkItem?
    private let scanQueue = DispatchQueue(label: "deskpet.activity", qos: .utility)
    private var lastSavedOrigin = NSPoint.zero
    private var hidden = false
    private var settings: DeskPetSettings
    private var settingsController: SettingsController?
    private let reducedMotion: Bool

    var currentPetID: String { settings.petID }
    var currentScale: Double { settings.scale }
    private var displaySize: NSSize { settings.displaySize }

    init(atlas: SpriteAtlas, settings: DeskPetSettings) {
        self.atlas = atlas
        self.settings = settings
        self.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        self.view = PetView(atlas: atlas)
        self.view.reducedMotion = reducedMotion
        self.panel = PetPanel(
            contentRect: NSRect(origin: .zero, size: settings.displaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
        configureStatusItem()
        view.frame = NSRect(origin: .zero, size: displaySize)
        panel.contentView = view
        restorePosition()
        settingsController = SettingsController(owner: self)
        nextWanderAt = CACurrentMediaTime() + 8
        play(.waving)
    }

    func start() {
        if !hidden { panel.orderFrontRegardless() }
        startDisplayLink()
    }

    func applicationWillTerminate() {
        persistWork?.cancel()
        persist()
        timer?.invalidate()
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false
        panel.delegate = self
        panel.acceptsMouseMovedEvents = false
        panel.isExcludedFromWindowsMenu = true
        panel.title = "DeskPet"
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(systemSymbolName: "pawprint", accessibilityDescription: "DeskPet")
        icon?.isTemplate = true
        item.button?.image = icon
        item.button?.imageScaling = .scaleProportionallyDown
        item.button?.toolTip = "DeskPet"
        let menu = NSMenu()
        menu.addItem(withTitle: L10n.settings, action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.wave, action: #selector(wave), keyEquivalent: "").target = self
        let hide = menu.addItem(withTitle: L10n.hide, action: #selector(toggleHidden), keyEquivalent: "")
        hide.target = self
        hideMenuItem = hide
        menu.addItem(withTitle: L10n.resetPosition, action: #selector(resetPosition), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.quit, action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        statusItem = item
        refreshHideTitle()
        refreshTooltip()
    }

    private func restorePosition() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        if let saved = settings.origin, screen.insetBy(dx: -40, dy: -40).contains(saved) {
            panel.setFrameOrigin(saved)
        } else {
            let origin = NSPoint(
                x: screen.maxX - displaySize.width - 28,
                y: screen.minY + 28
            )
            panel.setFrameOrigin(origin)
        }
        lastSavedOrigin = panel.frame.origin
    }

    private func savePosition() {
        lastSavedOrigin = panel.frame.origin
        settings.x = panel.frame.origin.x
        settings.y = panel.frame.origin.y
        persistWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persist()
        }
        persistWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    private func persist() {
        settings.x = panel.frame.origin.x
        settings.y = panel.frame.origin.y
        ConfigStore.save(settings)
    }

    func applyPet(id: String) {
        guard id != settings.petID else { return }
        guard let item = PetCatalog.all().first(where: { $0.id == id }) else { return }
        do {
            let next = try SpriteAtlas.load(from: item.sheetURL)
            atlas = next
            view.atlas = next
            view.present()
            settings.petID = item.id
            persist()
            refreshTooltip()
            play(.waving)
        } catch {
            NSSound.beep()
        }
    }

    func applyScale(_ scale: Double) {
        let next = min(max(scale, DeskPetSettings.minScale), DeskPetSettings.maxScale)
        guard abs(next - settings.scale) > 0.001 else { return }
        let old = panel.frame
        settings.scale = next
        let size = displaySize
        var origin = NSPoint(
            x: old.midX - size.width / 2,
            y: old.minY
        )
        if let screen = (panel.screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - size.width - 8)
            origin.y = min(max(origin.y, screen.minY + 8), screen.maxY - size.height - 8)
        }
        view.frame = NSRect(origin: .zero, size: size)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        persist()
        view.present()
    }

    @objc private func openSettings() {
        var anchor: NSPoint?
        if let button = statusItem?.button, let win = button.window {
            let rect = win.convertToScreen(button.convert(button.bounds, to: nil))
            anchor = NSPoint(x: rect.midX, y: rect.minY)
        }
        settingsController?.show(anchor: anchor)
    }

    private func play(_ state: PetState) {
        oneshot = state.loops ? nil : state
        view.state = state
        view.frameIndex = 0
        nextFrameAt = CACurrentMediaTime()
        view.present()
    }

    @objc private func wave() {
        play(.waving)
        if hidden { toggleHidden() }
    }

    @objc private func toggleHidden() {
        hidden.toggle()
        if hidden {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
        refreshHideTitle()
    }

    @objc private func resetPosition() {
        hidden = false
        panel.orderFrontRegardless()
        let screen = (panel.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        panel.setFrameOrigin(NSPoint(x: screen.maxX - displaySize.width - 28, y: screen.minY + 28))
        savePosition()
        refreshHideTitle()
    }

    @objc private func quit() {
        savePosition()
        NSApp.terminate(nil)
    }

    private func refreshHideTitle() {
        hideMenuItem?.title = hidden ? L10n.show : L10n.hide
    }

    private func refreshTooltip() {
        let name = PetCatalog.item(id: settings.petID)?.displayName ?? settings.petID
        statusItem?.button?.toolTip = name
    }

    private func startDisplayLink() {
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = CACurrentMediaTime()
        if now - lastPluginRead > 0.6 {
            lastPluginRead = now
            let plugin = ActivityReader.readPlugin()
            applyActivity(ActivityReader.resolve(
                now: Date().timeIntervalSince1970,
                plugin: plugin,
                process: processKind
            ))
        }
        if now - lastProcessScan > 3, !scanning {
            lastProcessScan = now
            scanning = true
            scanQueue.async { [weak self] in
                let process = ActivityReader.scanProcesses()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.scanning = false
                    self.processKind = process
                }
            }
        }
        advanceFrame(now: now)
        stepWander(now: now)
        if hypot(panel.frame.origin.x - lastSavedOrigin.x, panel.frame.origin.y - lastSavedOrigin.y) > 12 {
            savePosition()
        }
    }

    private func applyActivity(_ next: ActivityKind) {
        guard next != activity else { return }
        let previous = activity
        activity = next
        if dragging { return }
        switch next {
        case .running:
            if previous == .idle || previous == .review {
                play(.jumping)
            } else {
                play(.running)
            }
            wanderTarget = nil
        case .waiting:
            play(.waiting)
            wanderTarget = nil
        case .failed:
            play(.failed)
            wanderTarget = nil
        case .review:
            play(.review)
            wanderTarget = nil
        case .idle:
            play(.idle)
        }
    }

    private func advanceFrame(now: CFTimeInterval) {
        if reducedMotion {
            if view.state != .idle || view.frameIndex != 0 {
                view.state = .idle
                view.frameIndex = 0
                view.present()
            }
            return
        }
        if now < nextFrameAt { return }
        let state = displayState()
        if view.state != state {
            view.state = state
            view.frameIndex = 0
        } else {
            let last = state.frameCount - 1
            if view.frameIndex >= last {
                if !state.loops {
                    oneshot = nil
                    view.state = displayState()
                    view.frameIndex = 0
                } else {
                    view.frameIndex = 0
                }
            } else {
                view.frameIndex += 1
            }
        }
        let durations = view.state.durationsMs
        let ms = durations[min(view.frameIndex, durations.count - 1)]
        nextFrameAt = now + Double(ms) / 1000.0
        view.present()
    }

    private func displayState() -> PetState {
        if dragging {
            return (panel.frame.origin.x >= lastDragX) ? .runningRight : .runningLeft
        }
        if let oneshot { return oneshot }
        switch activity {
        case .idle: return wanderTarget == nil ? .idle : ((wanderTarget! >= panel.frame.origin.x) ? .runningRight : .runningLeft)
        case .running: return .running
        case .waiting: return .waiting
        case .failed: return .failed
        case .review: return .review
        }
    }

    private func stepWander(now: CFTimeInterval) {
        guard !reducedMotion, !dragging, !hidden, activity == .idle, oneshot == nil else { return }
        let screen = (panel.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        if now - lastWanderStep < 0.09 { return }
        lastWanderStep = now
        if let target = wanderTarget {
            let x = panel.frame.origin.x
            let step: CGFloat = 7
            if abs(target - x) <= step {
                panel.setFrameOrigin(NSPoint(x: target, y: panel.frame.origin.y))
                wanderTarget = nil
                play(.idle)
                nextWanderAt = now + Double.random(in: 12...28)
            } else {
                let dir: CGFloat = target > x ? 1 : -1
                var next = x + dir * step
                next = min(max(next, screen.minX + 8), screen.maxX - displaySize.width - 8)
                panel.setFrameOrigin(NSPoint(x: next, y: panel.frame.origin.y))
            }
            return
        }
        if now >= nextWanderAt {
            let minX = screen.minX + 8
            let maxX = screen.maxX - displaySize.width - 8
            guard maxX > minX else { return }
            wanderTarget = CGFloat.random(in: minX...maxX)
        }
    }

    func mouseDown(with event: NSEvent) {
        dragging = false
        dragStart = NSEvent.mouseLocation
        windowStart = panel.frame.origin
        lastDragX = windowStart.x
        _ = event
    }

    func mouseDragged(with event: NSEvent) {
        let loc = NSEvent.mouseLocation
        let dx = loc.x - dragStart.x
        let dy = loc.y - dragStart.y
        if !dragging && hypot(dx, dy) > 4 {
            dragging = true
            wanderTarget = nil
            oneshot = nil
        }
        guard dragging else { return }
        lastDragX = panel.frame.origin.x
        panel.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
        view.state = displayState()
        view.present()
        _ = event
    }

    func mouseUp(with event: NSEvent) {
        if dragging {
            dragging = false
            savePosition()
            play(displayState())
        } else if event.clickCount >= 1 {
            play(.waving)
        }
    }

    func rightMouseUp(with event: NSEvent) {
        statusItem?.menu?.popUp(positioning: nil, at: event.locationInWindow, in: view)
    }
}

extension PetController {
    func attachMouse() {
        view.window?.acceptsMouseMovedEvents = false
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseUp]) { [weak self] event in
            guard let self, event.window == self.panel else { return event }
            switch event.type {
            case .leftMouseDown: self.mouseDown(with: event)
            case .leftMouseDragged: self.mouseDragged(with: event)
            case .leftMouseUp: self.mouseUp(with: event)
            case .rightMouseUp: self.rightMouseUp(with: event)
            default: break
            }
            return event
        }
    }
}

import AppKit
import QuartzCore

final class PetView: NSView {
    var atlas: SpriteAtlas
    var state: PetState = .idle
    var frameIndex = 0
    var reducedMotion = false
    private var currentImage: CGImage?

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
        currentImage = image
        layer?.contents = image
    }

    func opaque(at point: NSPoint, slop: CGFloat) -> Bool {
        guard let image = currentImage else {
            return bounds.insetBy(dx: -slop, dy: -slop).contains(point)
        }
        return PixelHit.opaque(image, at: point, in: bounds.size, slop: slop)
    }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetController: NSObject, NSWindowDelegate {
    private var atlas: SpriteAtlas
    private let chrome = NSView()
    private let view: PetView
    private let captionView = CaptionView()
    private let panel: PetPanel
    private var statusItem: NSStatusItem?
    private var hideMenuItem: NSMenuItem?
    private var timer: Timer?
    private var activity = ActivityKind.idle
    private var signal = ActivitySignal.idle
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
    private var localMoveMonitor: Any?
    private var globalMoveMonitor: Any?
    private var captionUntil: CFTimeInterval = 0
    private var hopping = false
    private var hopStart: CFTimeInterval = 0
    private var hopBaseY: CGFloat = 0
    private var ledges: [Surface] = []
    private var currentPerch: Surface?
    private var falling = false
    private var fallSpeed: CGFloat = 0
    private var lastSurfaceScan: CFTimeInterval = 0

    var currentPetID: String { settings.petID }
    var currentScale: Double { settings.scale }
    var clickThroughEnabled: Bool { settings.clickThrough }
    var captionsEnabled: Bool { settings.captions }
    var perchEnabled: Bool { settings.perch }
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
        layoutChrome()
        restorePosition()
        settingsController = SettingsController(owner: self)
        nextWanderAt = CACurrentMediaTime() + 8
        play(.waving)
    }

    func start() {
        if !hidden { panel.orderFrontRegardless() }
        startDisplayLink()
        startClickThrough()
    }

    func applicationWillTerminate() {
        persistWork?.cancel()
        persist()
        timer?.invalidate()
        if let localMoveMonitor {
            NSEvent.removeMonitor(localMoveMonitor)
        }
        if let globalMoveMonitor {
            NSEvent.removeMonitor(globalMoveMonitor)
        }
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
        panel.acceptsMouseMovedEvents = true
        panel.isExcludedFromWindowsMenu = true
        panel.title = "DeskPet"

        chrome.wantsLayer = true
        chrome.layer?.backgroundColor = NSColor.clear.cgColor
        chrome.autoresizingMask = [.width, .height]
        panel.contentView = chrome
        chrome.addSubview(view)
        chrome.addSubview(captionView)
        captionView.isHidden = true
    }

    private func layoutChrome() {
        let pet = displaySize
        let showCaption = !captionView.isHidden
        let captionHeight: CGFloat = showCaption ? 26 : 0
        let gap: CGFloat = showCaption ? 6 : 0
        let size = NSSize(width: pet.width, height: pet.height + captionHeight + gap)
        let origin = panel.frame.origin
        view.frame = NSRect(origin: .zero, size: pet)
        captionView.frame = NSRect(
            x: 6,
            y: pet.height + gap,
            width: max(24, pet.width - 12),
            height: captionHeight
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        chrome.frame = NSRect(origin: .zero, size: size)
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
        if hopping || falling { return }
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
        if !hopping {
            settings.x = panel.frame.origin.x
            settings.y = panel.frame.origin.y
        }
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
        panel.setFrameOrigin(origin)
        layoutChrome()
        persist()
        view.present()
    }

    func applyClickThrough(_ on: Bool) {
        settings.clickThrough = on
        persist()
        updateClickThrough(at: NSEvent.mouseLocation)
    }

    func applyCaptions(_ on: Bool) {
        settings.captions = on
        persist()
        refreshCaption(from: signal, force: true)
    }

    func applyPerch(_ on: Bool) {
        settings.perch = on
        persist()
        if on {
            falling = true
            fallSpeed = 0
        } else {
            falling = false
            fallSpeed = 0
            currentPerch = nil
        }
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
        updateClickThrough(at: NSEvent.mouseLocation)
    }

    @objc private func resetPosition() {
        hidden = false
        hopping = false
        falling = false
        fallSpeed = 0
        panel.orderFrontRegardless()
        let screen = (panel.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        panel.setFrameOrigin(NSPoint(x: screen.maxX - displaySize.width - 28, y: screen.minY + (settings.perch ? 0 : 28)))
        if settings.perch { falling = true }
        savePosition()
        refreshHideTitle()
        updateClickThrough(at: NSEvent.mouseLocation)
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
        let suffix: String
        switch activity {
        case .waiting: suffix = L10n.captionWaiting
        case .failed: suffix = L10n.captionFailed
        case .running: suffix = L10n.working
        case .review: suffix = L10n.captionReview
        case .idle: suffix = ""
        }
        statusItem?.button?.toolTip = suffix.isEmpty ? name : "\(name) · \(suffix)"
    }

    private func startDisplayLink() {
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func startClickThrough() {
        localMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.updateClickThrough(at: NSEvent.mouseLocation)
            return event
        }
        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.updateClickThrough(at: NSEvent.mouseLocation)
        }
        updateClickThrough(at: NSEvent.mouseLocation)
    }

    private func updateClickThrough(at screenPoint: NSPoint) {
        guard settings.clickThrough, !dragging, !hidden else {
            panel.ignoresMouseEvents = false
            return
        }
        if activity == .waiting {
            panel.ignoresMouseEvents = false
            return
        }
        let windowPoint = panel.convertPoint(fromScreen: screenPoint)
        if !captionView.isHidden, captionView.frame.insetBy(dx: -4, dy: -4).contains(windowPoint) {
            panel.ignoresMouseEvents = false
            return
        }
        let petPoint = view.convert(windowPoint, from: nil)
        panel.ignoresMouseEvents = !view.opaque(at: petPoint, slop: 6)
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
        expireCaption(now: now)
        stepHop(now: now)
        stepGravity(now: now)
        advanceFrame(now: now)
        stepWander(now: now)
        if !hopping, !falling, hypot(panel.frame.origin.x - lastSavedOrigin.x, panel.frame.origin.y - lastSavedOrigin.y) > 12 {
            savePosition()
        }
    }

    private func applyActivity(_ next: ActivitySignal) {
        let previousKind = activity
        let detailChanged = next.detail != signal.detail || next.kind != signal.kind
        signal = next
        if detailChanged {
            refreshCaption(from: next)
        }
        if next.kind == .waiting, previousKind != .waiting, !hidden {
            startHop()
            panel.orderFrontRegardless()
        }
        guard next.kind != activity else {
            if detailChanged { refreshTooltip() }
            return
        }
        activity = next.kind
        refreshTooltip()
        if dragging { return }
        switch next.kind {
        case .running:
            if previousKind == .idle || previousKind == .review {
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

    private func refreshCaption(from next: ActivitySignal, force: Bool = false) {
        guard settings.captions, !reducedMotion else {
            setCaption("")
            return
        }
        let now = CACurrentMediaTime()
        switch next.kind {
        case .waiting:
            setCaption(L10n.captionWaiting)
            captionUntil = .greatestFiniteMagnitude
        case .failed:
            setCaption(L10n.captionFailed)
            captionUntil = now + 4
        case .review:
            setCaption(L10n.captionReview)
            captionUntil = now + 2.4
        case .running:
            let label = L10n.tool(next.detail)
            if !label.isEmpty {
                setCaption(label)
                captionUntil = now + 1.8
            } else if force {
                setCaption("")
            }
        case .idle:
            setCaption("")
            captionUntil = now
        }
    }

    private func expireCaption(now: CFTimeInterval) {
        guard !captionView.isHidden, now >= captionUntil else { return }
        if activity == .waiting { return }
        setCaption("")
    }

    private func setCaption(_ text: String) {
        let hide = text.isEmpty
        if captionView.text == text, captionView.isHidden == hide { return }
        captionView.text = text
        captionView.isHidden = hide
        layoutChrome()
    }

    private func startHop() {
        guard !reducedMotion, !dragging else { return }
        hopping = true
        hopStart = CACurrentMediaTime()
        hopBaseY = currentPerch?.y ?? panel.frame.origin.y
        falling = false
        fallSpeed = 0
    }

    private func stepHop(now: CFTimeInterval) {
        guard hopping else { return }
        let duration = 0.9
        let t = now - hopStart
        if t >= duration {
            hopping = false
            panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x, y: hopBaseY))
            return
        }
        let decay = 1 - t / duration
        let y = hopBaseY + abs(sin(t / duration * .pi * 3)) * 16 * decay
        panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x, y: y))
    }

    private func refreshLedges() {
        let screen = (panel.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        ledges = SurfaceScanner.ledges(
            excluding: [panel.windowNumber],
            screen: screen,
            petHeight: displaySize.height
        )
    }

    private func stepGravity(now: CFTimeInterval) {
        guard settings.perch, !dragging, !hidden, !hopping else { return }
        if now - lastSurfaceScan > 0.28 {
            lastSurfaceScan = now
            refreshLedges()
        }
        if ledges.isEmpty { refreshLedges() }
        let support = SurfaceScanner.support(
            feetX: panel.frame.origin.x,
            feetY: panel.frame.origin.y,
            width: displaySize.width,
            ledges: ledges
        )
        let x = min(max(panel.frame.origin.x, support.minX), max(support.minX, support.maxX - displaySize.width))
        if reducedMotion {
            falling = false
            fallSpeed = 0
            currentPerch = support
            panel.setFrameOrigin(NSPoint(x: x, y: support.y))
            return
        }
        let gap = panel.frame.origin.y - support.y
        if gap > 3 {
            falling = true
        }
        if falling {
            fallSpeed = min(24, fallSpeed + 1.2)
            var y = panel.frame.origin.y - fallSpeed
            if y <= support.y {
                y = support.y
                falling = false
                fallSpeed = 0
                currentPerch = support
                wanderTarget = nil
                if activity == .idle, oneshot == nil {
                    play(.idle)
                }
            }
            panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x, y: y))
            return
        }
        currentPerch = support
        let outside = panel.frame.origin.x < support.minX - 1 || panel.frame.origin.x > support.maxX - displaySize.width + 1
        if outside {
            panel.setFrameOrigin(NSPoint(x: x, y: support.y))
        } else if abs(panel.frame.origin.y - support.y) > 0.5 {
            panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x, y: support.y))
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
        if falling { return .jumping }
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
        guard !reducedMotion, !dragging, !hidden, !hopping, !falling, activity == .idle, oneshot == nil else { return }
        let screen = (panel.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        if now - lastWanderStep < 0.09 { return }
        lastWanderStep = now
        let perch = currentPerch
        let minX: CGFloat
        let maxX: CGFloat
        if settings.perch, let perch {
            minX = perch.minX + 8
            maxX = perch.maxX - displaySize.width - 8
        } else {
            minX = screen.minX + 8
            maxX = screen.maxX - displaySize.width - 8
        }
        let sitY = perch?.y ?? panel.frame.origin.y
        if let target = wanderTarget {
            let x = panel.frame.origin.x
            let step: CGFloat = 7
            if abs(target - x) <= step {
                panel.setFrameOrigin(NSPoint(x: target, y: sitY))
                wanderTarget = nil
                play(.idle)
                nextWanderAt = now + Double.random(in: 12...28)
            } else {
                let dir: CGFloat = target > x ? 1 : -1
                var next = x + dir * step
                if settings.perch, let perch, (next < perch.minX - 2 || next > perch.maxX - displaySize.width + 2) {
                    falling = true
                    fallSpeed = 0.6
                    wanderTarget = nil
                    currentPerch = nil
                    let offX = next < perch.minX
                        ? perch.minX - displaySize.width / 2 - 8
                        : perch.maxX - displaySize.width / 2 + 8
                    panel.setFrameOrigin(NSPoint(x: offX, y: panel.frame.origin.y))
                    return
                }
                next = min(max(next, minX), max(minX, maxX))
                panel.setFrameOrigin(NSPoint(x: next, y: sitY))
            }
            return
        }
        if now >= nextWanderAt {
            guard maxX > minX else { return }
            if settings.perch, let perch, Double.random(in: 0...1) < 0.22 {
                wanderTarget = Bool.random() ? perch.minX - displaySize.width - 6 : perch.maxX + 6
            } else {
                wanderTarget = CGFloat.random(in: minX...maxX)
            }
        }
    }

    func mouseDown(with event: NSEvent) {
        dragging = false
        dragStart = NSEvent.mouseLocation
        windowStart = panel.frame.origin
        lastDragX = windowStart.x
        hopping = false
        falling = false
        fallSpeed = 0
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
            hopping = false
            panel.ignoresMouseEvents = false
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
            if settings.perch {
                falling = true
                fallSpeed = 0
            }
            savePosition()
            play(displayState())
            updateClickThrough(at: NSEvent.mouseLocation)
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
        view.window?.acceptsMouseMovedEvents = true
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

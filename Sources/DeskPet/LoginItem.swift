import AppKit
import ServiceManagement

/// Startup control for the installed app.
///
/// Older source installs started DeskPet through a LaunchAgent. Both mechanisms
/// fighting over startup made the switch unusable, so the LaunchAgent is retired
/// the first time the switch is touched and the login item becomes the only
/// source of truth.
enum LoginItem {
    private static let legacyLabels = ["ai.deskpet", "ai.minseo.deskpet"]

    /// Login items only exist for a real app bundle, not for a bare binary.
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: return true
        default: return hasLegacyAgent
        }
    }

    static var hasLegacyAgent: Bool {
        legacyAgents.contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func set(_ enabled: Bool) throws {
        removeLegacyAgents()
        if enabled {
            guard SMAppService.mainApp.status != .enabled else { return }
            try SMAppService.mainApp.register()
        } else if SMAppService.mainApp.status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }

    private static var legacyAgents: [URL] {
        let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/LaunchAgents")
        return legacyLabels.map { dir.appendingPathComponent("\($0).plist") }
    }

    private static func removeLegacyAgents() {
        for agent in legacyAgents where FileManager.default.fileExists(atPath: agent.path) {
            let label = agent.deletingPathExtension().lastPathComponent
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["bootout", "gui/\(getuid())/\(label)"]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
            try? FileManager.default.removeItem(at: agent)
        }
    }
}

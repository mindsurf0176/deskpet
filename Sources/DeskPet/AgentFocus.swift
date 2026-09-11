import AppKit

enum AgentFocus {
    static func activate(source: String) {
        let apps = NSWorkspace.shared.runningApplications
        for bundle in bundles(for: source) {
            if let app = apps.first(where: { $0.bundleIdentifier == bundle }) {
                bring(app)
                return
            }
        }
        for name in names(for: source) {
            if let app = apps.first(where: {
                ($0.localizedName ?? "").localizedCaseInsensitiveContains(name)
            }) {
                bring(app)
                return
            }
        }
    }

    private static func bring(_ app: NSRunningApplication) {
        app.activate(options: [.activateIgnoringOtherApps])
    }

    private static func bundles(for source: String) -> [String] {
        switch source {
        case "opencode":
            return ["ai.opencode.desktop"]
        case "orca":
            return ["com.stablyai.orca"]
        case "codex":
            return [
                "com.openai.codex",
                "com.openai.chat",
                "ai.opencode.desktop",
                "com.stablyai.orca",
            ]
        default:
            return [
                "ai.opencode.desktop",
                "com.stablyai.orca",
                "com.openai.codex",
                "com.openai.chat",
            ]
        }
    }

    private static func names(for source: String) -> [String] {
        switch source {
        case "opencode":
            return ["OpenCode"]
        case "orca":
            return ["Orca"]
        case "codex":
            return ["Codex", "ChatGPT", "OpenCodex", "OpenCode", "Orca"]
        default:
            return ["OpenCode", "Orca", "Codex", "ChatGPT"]
        }
    }
}


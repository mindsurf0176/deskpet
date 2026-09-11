import AppKit
import Foundation

enum AgentFocus {
    static func activate(source: String, paneKey: String = "", tabId: String = "", worktreeId: String = "") {
        DispatchQueue.global(qos: .userInitiated).async {
            let orcaHint = source == "orca" || !paneKey.isEmpty || !tabId.isEmpty || !worktreeId.isEmpty
            if orcaHint {
                _ = focusOrcaTerminal(paneKey: paneKey, tabId: tabId, worktreeId: worktreeId)
            }
            DispatchQueue.main.async {
                bringApp(source: orcaHint ? "orca" : source)
            }
        }
    }

    private static func bringApp(source: String) {
        let apps = NSWorkspace.shared.runningApplications
        for bundle in bundles(for: source) {
            if let app = apps.first(where: { $0.bundleIdentifier == bundle }) {
                app.activate(options: [.activateIgnoringOtherApps])
                return
            }
        }
        for name in names(for: source) {
            if let app = apps.first(where: {
                ($0.localizedName ?? "").localizedCaseInsensitiveContains(name)
            }) {
                app.activate(options: [.activateIgnoringOtherApps])
                return
            }
        }
    }

    @discardableResult
    private static func focusOrcaTerminal(paneKey: String, tabId: String, worktreeId: String) -> Bool {
        guard let handle = resolveHandle(paneKey: paneKey, tabId: tabId, worktreeId: worktreeId) else {
            return false
        }
        return runOrca(["terminal", "switch", "--terminal", handle]) != nil
    }

    private static func resolveHandle(paneKey: String, tabId: String, worktreeId: String) -> String? {
        if paneKey.hasPrefix("term_") { return paneKey }
        guard let data = runOrca(["terminal", "list", "--json", "--include-visual-layouts"]),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let result = json["result"] as? [String: Any] ?? json
        let terminals = result["terminals"] as? [[String: Any]] ?? []
        let needles = tokens(paneKey) + [tabId, worktreeId, paneKey].filter { !$0.isEmpty }

        for term in terminals {
            let handle = term["handle"] as? String ?? ""
            let fields = [
                handle,
                term["tabId"] as? String ?? "",
                term["leafId"] as? String ?? "",
                term["worktreeId"] as? String ?? "",
                term["ptyId"] as? String ?? "",
            ]
            if needles.contains(where: { needle in fields.contains(where: { field in
                !needle.isEmpty && (field == needle || field.contains(needle) || needle.contains(field))
            }) }) {
                return handle.isEmpty ? nil : handle
            }
        }

        if !worktreeId.isEmpty {
            let hits = terminals.filter { ($0["worktreeId"] as? String) == worktreeId }
            if hits.count == 1 { return hits[0]["handle"] as? String }
        }
        if !tabId.isEmpty {
            let hits = terminals.filter { ($0["tabId"] as? String) == tabId }
            if let handle = hits.first?["handle"] as? String, !handle.isEmpty { return handle }
        }
        return nil
    }

    private static func tokens(_ raw: String) -> [String] {
        raw.split { $0 == "\0" || $0 == "|" || $0 == "/" || $0 == ":" }
            .map(String.init)
            .filter { $0.count >= 8 }
    }

    @discardableResult
    private static func runOrca(_ args: [String]) -> Data? {
        let bin = orcaBin()
        guard FileManager.default.isExecutableFile(atPath: bin) else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = args
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        proc.standardInput = FileHandle.nullDevice
        do { try proc.run() } catch { return nil }

        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            proc.waitUntilExit()
            group.leave()
        }
        if group.wait(timeout: .now() + 2.5) == .timedOut {
            proc.terminate()
            return nil
        }
        guard proc.terminationStatus == 0 else { return nil }
        return out.fileHandleForReading.readDataToEndOfFile()
    }

    private static func orcaBin() -> String {
        let candidates = [
            "/usr/local/bin/orca",
            "/opt/homebrew/bin/orca",
            "/Applications/Orca.app/Contents/Resources/bin/orca",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? candidates[0]
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


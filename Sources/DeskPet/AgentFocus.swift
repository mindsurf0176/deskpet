import AppKit
import Foundation
import ApplicationServices
import Darwin

enum AgentFocus {
    static func activate(
        source: String,
        paneKey: String = "",
        tabId: String = "",
        worktreeId: String = "",
        cwd: String = ""
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let orcaHint = source == "orca"
                || cwd.hasPrefix(NSHomeDirectory() + "/orca/")
                || !paneKey.isEmpty || !tabId.isEmpty || !worktreeId.isEmpty
            var focusedTerminal = false
            if orcaHint {
                focusedTerminal = focusOrcaTerminal(
                    paneKey: paneKey,
                    tabId: tabId,
                    worktreeId: worktreeId,
                    cwd: cwd
                )
            } else {
                focusedTerminal = focusExternalTerminal(cwd: cwd)
            }
            DispatchQueue.main.async {
                if focusedTerminal, orcaHint {
                    bringApp(source: "orca")
                } else if !focusedTerminal {
                    bringApp(source: source)
                }
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
    private static func focusOrcaTerminal(
        paneKey: String,
        tabId: String,
        worktreeId: String,
        cwd: String
    ) -> Bool {
        guard let handle = resolveHandle(
            paneKey: paneKey,
            tabId: tabId,
            worktreeId: worktreeId,
            cwd: cwd
        ) else {
            return false
        }
        return runOrca(["terminal", "switch", "--terminal", handle]) != nil
    }

    private static func resolveHandle(
        paneKey: String,
        tabId: String,
        worktreeId: String,
        cwd: String
    ) -> String? {
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
                term["cwd"] as? String ?? "",
                term["path"] as? String ?? "",
            ]
            if needles.contains(where: { needle in fields.contains(where: { field in
                !needle.isEmpty && (field == needle || field.contains(needle) || needle.contains(field))
            }) }) {
                return handle.isEmpty ? nil : handle
            }
        }

        let wantedCWD = normalize(cwd)
        if !wantedCWD.isEmpty {
            let hits = terminals.filter {
                let candidate = normalize(($0["cwd"] as? String) ?? ($0["path"] as? String) ?? "")
                return candidate == wantedCWD || candidate.hasPrefix(wantedCWD + "/")
            }
            if hits.count == 1, let handle = hits[0]["handle"] as? String, !handle.isEmpty {
                return handle
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

    @discardableResult
    private static func focusExternalTerminal(cwd: String) -> Bool {
        let wanted = normalize(cwd)
        if let pid = terminalAppPID(matching: wanted), raiseTerminalWindow(pid: pid, cwd: wanted) {
            return true
        }
        return false
    }

    private static let terminalBundles: Set<String> = [
        "com.mitchellh.ghostty",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "net.kovidgoyal.kitty",
        "io.alacritty",
        "org.alacritty",
        "com.github.wez.wezterm",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "co.zeit.hyper",
        "com.apple.Terminal",
    ]

    private static let terminalNames: Set<String> = [
        "ghostty", "terminal", "iterm", "iterm2", "kitty", "alacritty",
        "wezterm", "warp", "hyper", "xterm", "x11", "xquartz",
    ]

    private static func terminalAppPID(matching cwd: String) -> pid_t? {
        if let pid = agentTerminalParent(cwd: cwd) { return pid }
        let apps = NSWorkspace.shared.runningApplications
        let terms = apps.filter { app in
            if let bid = app.bundleIdentifier, terminalBundles.contains(bid) { return true }
            let name = (app.localizedName ?? "").lowercased()
            return terminalNames.contains(where: { name.contains($0) })
        }
        if terms.count == 1 { return terms[0].processIdentifier }
        return terms.first(where: { $0.bundleIdentifier == "com.mitchellh.ghostty" })?.processIdentifier
            ?? terms.first?.processIdentifier
    }

    private static func agentTerminalParent(cwd: String) -> pid_t? {
        let bytesNeeded = proc_listallpids(nil, 0)
        guard bytesNeeded > 0 else { return nil }
        let capacity = Int(bytesNeeded) / MemoryLayout<pid_t>.stride + 32
        var pids = [pid_t](repeating: 0, count: capacity)
        let filled = proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.stride))
        guard filled > 0 else { return nil }
        let count = Int(filled) / MemoryLayout<pid_t>.stride
        let agents: Set<String> = ["codex", "opencode", "claude", "gemini"]
        for i in 0..<count {
            let pid = pids[i]
            if pid <= 0 { continue }
            var nameBuf = [CChar](repeating: 0, count: 64)
            guard proc_name(pid, &nameBuf, UInt32(nameBuf.count)) > 0 else { continue }
            let name = String(cString: nameBuf)
            guard agents.contains(name) else { continue }
            var pathBuf = [CChar](repeating: 0, count: 512)
            _ = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
            let path = String(cString: pathBuf)
            if path.contains("codex-code-mode-host") || path.contains("codex app-server") { continue }
            if !cwd.isEmpty {
                let procCwd = processCWD(pid) ?? ""
                if !procCwd.isEmpty, normalize(procCwd) != normalize(cwd), !normalize(procCwd).hasPrefix(normalize(cwd)) {
                    continue
                }
            }
            if let term = walkToTerminal(from: pid) { return term }
        }
        return nil
    }

    private static func walkToTerminal(from pid: pid_t) -> pid_t? {
        var current = pid
        for _ in 0..<12 {
            if let app = NSRunningApplication(processIdentifier: current) {
                if let bid = app.bundleIdentifier, terminalBundles.contains(bid) { return current }
                let name = (app.localizedName ?? "").lowercased()
                if terminalNames.contains(where: { name.contains($0) }) { return current }
            }
            var nameBuf = [CChar](repeating: 0, count: 64)
            if proc_name(current, &nameBuf, UInt32(nameBuf.count)) > 0 {
                let name = String(cString: nameBuf).lowercased()
                if terminalNames.contains(name) { return current }
            }
            let parent = parentPID(current)
            if parent <= 1 || parent == current { break }
            current = parent
        }
        return nil
    }

    private static func parentPID(_ pid: pid_t) -> pid_t {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return 0 }
        return pid_t(info.pbi_ppid)
    }

    private static func processCWD(_ pid: pid_t) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments = ["-a", "-p", String(pid), "-d", "cwd", "-Fn"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") {
            if line.hasPrefix("n") { return String(line.dropFirst()) }
        }
        return nil
    }

    @discardableResult
    private static func raiseTerminalWindow(pid: pid_t, cwd: String) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateIgnoringOtherApps])
        let app = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard err == .success, let windows = value as? [AXUIElement], !windows.isEmpty else {
            return NSRunningApplication(processIdentifier: pid) != nil
        }
        var best: AXUIElement?
        var bestScore = -1
        for window in windows {
            var titleRef: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""
            let score = titleScore(title, cwd: cwd)
            if score > bestScore {
                bestScore = score
                best = window
            }
        }
        let target = (bestScore > 0 ? best : windows.first) ?? windows[0]
        AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        return true
    }

    private static func titleScore(_ title: String, cwd: String) -> Int {
        let t = title as NSString
        let path = normalize(cwd) as NSString
        if path.length == 0 { return 0 }
        if t.contains(path as String) { return 100 }
        let last = path.lastPathComponent
        if last.count >= 3, t.localizedCaseInsensitiveContains(last) { return 60 }
        let parent = (path.deletingLastPathComponent as NSString).lastPathComponent
        if parent.count >= 3, t.localizedCaseInsensitiveContains(parent) { return 30 }
        return 0
    }

    private static func normalize(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath).standardizedFileURL.path
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

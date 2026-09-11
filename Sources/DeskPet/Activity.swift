import Foundation
import AppKit
import Darwin

struct PluginState: Equatable {
    var kind: ActivityKind
    var source: String
    var updatedAt: TimeInterval
}

enum ActivityReader {
    static var stateURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/pets/deskpet-state.json")
    }

    static var positionURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/pets/deskpet-position.json")
    }

    static var orcaStatusURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/orca/agent-hooks/last-status.json")
    }

    static func readPlugin() -> PluginState? {
        guard let data = try? Data(contentsOf: stateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let raw = (json["state"] as? String ?? "idle").lowercased()
        let kind: ActivityKind
        switch raw {
        case "running", "busy", "working": kind = .running
        case "waiting", "ask", "permission": kind = .waiting
        case "failed", "error": kind = .failed
        case "review", "ready": kind = .review
        default: kind = .idle
        }
        let updated: TimeInterval
        if let n = json["updatedAt"] as? Double {
            updated = n > 1_000_000_000_000 ? n / 1000 : n
        } else {
            updated = 0
        }
        return PluginState(
            kind: kind,
            source: json["source"] as? String ?? "opencode",
            updatedAt: updated
        )
    }

    static func scanProcesses() -> ActivityKind {
        ProcScanner.scan()
    }

    static func readOrca() -> PluginState? {
        guard let data = try? Data(contentsOf: orcaStatusURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["entries"] as? [String: Any]
        else { return nil }

        let rank: [ActivityKind: Int] = [
            .waiting: 4, .running: 3, .failed: 2, .review: 1, .idle: 0
        ]
        var best: PluginState?
        for value in entries.values {
            guard let rec = value as? [String: Any] else { continue }
            let payload = rec["payload"] as? [String: Any] ?? [:]
            let raw = (payload["state"] as? String ?? "").lowercased()
            let hook = (rec["hookEventName"] as? String ?? "").lowercased()
            let kind: ActivityKind
            switch raw {
            case "working", "running", "busy", "in_progress":
                kind = .running
            case "waiting", "ask", "permission":
                kind = .waiting
            case "error", "failed":
                kind = .failed
            case "done", "idle", "stop":
                kind = .review
            default:
                if hook.contains("ask") || hook.contains("permission") {
                    kind = .waiting
                } else if hook == "stop" {
                    kind = .review
                } else if hook.contains("tool") || hook.contains("prompt") {
                    kind = .running
                } else {
                    continue
                }
            }
            var updated: TimeInterval = 0
            if let n = rec["receivedAt"] as? Double {
                updated = n > 1_000_000_000_000 ? n / 1000 : n
            }
            let candidate = PluginState(kind: kind, source: rec["source"] as? String ?? "orca", updatedAt: updated)
            if let current = best {
                let betterRank = (rank[kind] ?? 0) > (rank[current.kind] ?? 0)
                let newerSame = kind == current.kind && updated > current.updatedAt
                if betterRank || newerSame { best = candidate }
            } else {
                best = candidate
            }
        }
        return best
    }

    static func resolve(now: TimeInterval, plugin: PluginState?, process: ActivityKind) -> ActivityKind {
        let signals = [plugin, readOrca()].compactMap { $0 }.filter { isFresh($0, now: now) }
        if signals.contains(where: { $0.kind == .waiting }) { return .waiting }
        if signals.contains(where: { $0.kind == .running }) { return .running }
        if signals.contains(where: { $0.kind == .failed }) { return .failed }
        if signals.contains(where: { $0.kind == .review }) {
            return process == .running ? .running : .review
        }
        if process == .running { return .running }
        if signals.contains(where: { $0.kind == .idle }) { return .idle }
        return process
    }

    private static func isFresh(_ state: PluginState, now: TimeInterval) -> Bool {
        let age = now - state.updatedAt
        if age < 0 { return false }
        let orca = state.source != "opencode"
        switch state.kind {
        case .running: return age < (orca ? 180 : 12)
        case .waiting: return age < (orca ? 120 : 12)
        case .failed: return age < 6
        case .review: return age < 10
        case .idle: return age < 12
        }
    }

}

private let PROC_PIDTASKINFO: Int32 = 4

private struct ProcTaskInfo {
    var pti_virtual_size: UInt64 = 0
    var pti_resident_size: UInt64 = 0
    var pti_total_user: UInt64 = 0
    var pti_total_system: UInt64 = 0
    var pti_threads_user: UInt64 = 0
    var pti_threads_system: UInt64 = 0
    var pti_policy: Int32 = 0
    var pti_faults: Int32 = 0
    var pti_pageins: Int32 = 0
    var pti_cow_faults: Int32 = 0
    var pti_messages_sent: Int32 = 0
    var pti_messages_received: Int32 = 0
    var pti_syscalls_mach: Int32 = 0
    var pti_syscalls_unix: Int32 = 0
    var pti_csw: Int32 = 0
    var pti_threadnum: Int32 = 0
    var pti_numrunning: Int32 = 0
    var pti_priority: Int32 = 0
}

private struct CPUSample {
    var user: UInt64
    var system: UInt64
    var at: CFTimeInterval
}

private enum ProcScanner {
    private static let selfPID = getpid()
    private static var prev: [pid_t: CPUSample] = [:]
    private static let agents: Set<String> = ["opencode", "codex", "claude", "gemini"]

    static func scan() -> ActivityKind {
        let bytesNeeded = proc_listallpids(nil, 0)
        guard bytesNeeded > 0 else { return .idle }
        let capacity = Int(bytesNeeded) / MemoryLayout<pid_t>.stride + 64
        var pids = [pid_t](repeating: 0, count: capacity)
        let filled = proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.stride))
        guard filled > 0 else { return .idle }
        let count = Int(filled) / MemoryLayout<pid_t>.stride
        let now = CFAbsoluteTimeGetCurrent()
        var nextPrev: [pid_t: CPUSample] = [:]
        var rendererBusy = false
        var agentBusy = false

        for i in 0..<count {
            let pid = pids[i]
            if pid <= 0 || pid == selfPID { continue }

            var nameBuf = [CChar](repeating: 0, count: 64)
            guard proc_name(pid, &nameBuf, UInt32(nameBuf.count)) > 0 else { continue }
            let name = String(cString: nameBuf)
            if !isCandidate(name) { continue }

            var pathBuf = [CChar](repeating: 0, count: 512)
            _ = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
            let path = String(cString: pathBuf)
            if path.contains("codex-code-mode-host") || path.contains("codex app-server") { continue }
            if name == "deskpet" || path.hasSuffix("/deskpet") { continue }

            let cpu = cpuPercent(pid: pid, now: now, into: &nextPrev)
            if (name.contains("OpenCode") || path.contains("OpenCode.app")),
               (name.contains("Renderer") || path.contains("Renderer")),
               cpu >= 6 {
                rendererBusy = true
            }
            let base = (path as NSString).lastPathComponent
            if agents.contains(name) || agents.contains(base) {
                if !name.contains("Helper"), !path.contains("OpenCode.app"), cpu >= 3 {
                    agentBusy = true
                }
            }
        }

        prev = nextPrev
        if rendererBusy || agentBusy { return .running }
        return .idle
    }

    private static func isCandidate(_ name: String) -> Bool {
        if name.contains("OpenCode") || name.contains("Orca") { return true }
        if agents.contains(name) { return true }
        return false
    }

    private static func cpuPercent(pid: pid_t, now: CFTimeInterval, into next: inout [pid_t: CPUSample]) -> Double {
        var info = ProcTaskInfo()
        let size = Int32(MemoryLayout<ProcTaskInfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { return 0 }
        let sample = CPUSample(user: info.pti_total_user, system: info.pti_total_system, at: now)
        next[pid] = sample
        guard let old = prev[pid] else { return 0 }
        let dt = now - old.at
        guard dt > 0.2 else { return 0 }
        let delta = Double((sample.user &- old.user) &+ (sample.system &- old.system)) / 1_000_000_000.0
        return (delta / dt) * 100.0
    }
}

enum PositionStore {
    static func load() -> NSPoint? {
        guard let data = try? Data(contentsOf: ActivityReader.positionURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let x = json["x"] as? Double,
              let y = json["y"] as? Double
        else { return nil }
        return NSPoint(x: x, y: y)
    }

    static func save(_ point: NSPoint) {
        let url = ActivityReader.positionURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload: [String: Double] = ["x": point.x, "y": point.y]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

import Foundation

enum L10n {
    static var korean: Bool {
        Locale.preferredLanguages.contains { $0.hasPrefix("ko") }
    }

    static func t(_ en: String, ko: String) -> String {
        korean ? ko : en
    }

    static var settings: String { t("Settings…", ko: "설정…") }
    static var wave: String { t("Wave", ko: "인사") }
    static var hide: String { t("Hide", ko: "숨기기") }
    static var show: String { t("Show", ko: "보이기") }
    static var resetPosition: String { t("Reset Position", ko: "위치 리셋") }
    static var quit: String { t("Quit", ko: "종료") }
    static var pet: String { t("Pet", ko: "펫") }
    static var size: String { t("Size", ko: "크기") }
    static var smaller: String { t("Smaller", ko: "작게") }
    static var larger: String { t("Larger", ko: "크게") }
    static var noPets: String { t("No pets found", ko: "펫 없음") }
    static var clickThrough: String { t("Click-through", ko: "클릭 통과") }
    static var captions: String { t("Captions", ko: "말풍선") }
    static var perch: String { t("Sit on windows", ko: "창에 앉기") }
    static var captionWaiting: String { t("Needs you", ko: "허락해줘") }
    static var captionFailed: String { t("Ouch", ko: "앗") }
    static var captionReview: String { t("Done", ko: "끝") }
    static var working: String { t("Working", ko: "작업 중") }

    static func tool(_ raw: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "" }
        let last = (name as NSString).lastPathComponent
        let compact = last.lowercased().replacingOccurrences(of: "_", with: "")
        switch compact {
        case "bash", "execcommand", "shell":
            return t("shell", ko: "명령")
        case "applypatch", "edit", "write":
            return t("edit", ko: "수정")
        case "permission", "ask":
            return captionWaiting
        default:
            if last.hasPrefix("mcp__") {
                return last.split(separator: "_").last.map(String.init) ?? last
            }
            return last.count > 18 ? String(last.prefix(17)) + "…" : last
        }
    }
}

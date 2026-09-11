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
}

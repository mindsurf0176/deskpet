import Foundation

enum AppLanguage: String, CaseIterable {
    case auto
    case ko
    case en
    case ja
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    var menuTitle: String {
        switch self {
        case .auto: return L10n.languageAuto
        case .ko: return "한국어"
        case .en: return "English"
        case .ja: return "日本語"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }
}

enum SpeechTone: String, CaseIterable {
    case casual
    case polite
    case cute

    var menuTitle: String {
        switch self {
        case .casual: return L10n.toneCasual
        case .polite: return L10n.tonePolite
        case .cute: return L10n.toneCute
        }
    }
}

enum ResolvedLanguage: Equatable {
    case en, ko, ja, zhHans, zhHant
}

enum L10n {
    static var language: AppLanguage = .auto
    static var tone: SpeechTone = .casual

    static var resolved: ResolvedLanguage {
        switch language {
        case .auto: return detect()
        case .ko: return .ko
        case .en: return .en
        case .ja: return .ja
        case .zhHans: return .zhHans
        case .zhHant: return .zhHant
        }
    }

    static func detect(from tags: [String] = Locale.preferredLanguages) -> ResolvedLanguage {
        for tag in tags {
            if let match = match(tag) { return match }
        }
        return .en
    }

    static func match(_ tag: String) -> ResolvedLanguage? {
        let lower = tag.lowercased().replacingOccurrences(of: "_", with: "-")
        if lower.hasPrefix("ko") { return .ko }
        if lower.hasPrefix("ja") { return .ja }
        if lower.contains("hant")
            || lower.hasPrefix("zh-tw")
            || lower.hasPrefix("zh-hk")
            || lower.hasPrefix("zh-mo") {
            return .zhHant
        }
        if lower.hasPrefix("zh") || lower.hasPrefix("yue") { return .zhHans }
        if lower.hasPrefix("en") { return .en }
        return nil
    }

    static func t(en: String, ko: String, ja: String, zhHans: String, zhHant: String) -> String {
        switch resolved {
        case .en: return en
        case .ko: return ko
        case .ja: return ja
        case .zhHans: return zhHans
        case .zhHant: return zhHant
        }
    }

    static func speak(
        en: (String, String, String),
        ko: (String, String, String),
        ja: (String, String, String),
        zhHans: (String, String, String),
        zhHant: (String, String, String)
    ) -> String {
        let pack: (String, String, String)
        switch resolved {
        case .en: pack = en
        case .ko: pack = ko
        case .ja: pack = ja
        case .zhHans: pack = zhHans
        case .zhHant: pack = zhHant
        }
        switch tone {
        case .casual: return pack.0
        case .polite: return pack.1
        case .cute: return pack.2
        }
    }

    static var settings: String { t(en: "Settings…", ko: "설정…", ja: "設定…", zhHans: "设置…", zhHant: "設定…") }
    static var options: String { t(en: "Options", ko: "옵션", ja: "オプション", zhHans: "选项", zhHant: "選項") }
    static var speech: String { t(en: "Speech", ko: "대화", ja: "セリフ", zhHans: "对话", zhHant: "對話") }
    static var languageLabel: String { t(en: "Language", ko: "언어", ja: "言語", zhHans: "语言", zhHant: "語言") }
    static var toneLabel: String { t(en: "Tone", ko: "말투", ja: "口調", zhHans: "语气", zhHant: "語氣") }
    static var toneCasual: String { t(en: "Casual", ko: "반말", ja: "ため口", zhHans: "随便", zhHant: "隨便") }
    static var tonePolite: String { t(en: "Polite", ko: "존댓말", ja: "丁寧", zhHans: "敬语", zhHant: "敬語") }
    static var toneCute: String { t(en: "Cute", ko: "귀엽게", ja: "かわいい", zhHans: "可爱", zhHant: "可愛") }
    static var wave: String { t(en: "Wave", ko: "인사", ja: "あいさつ", zhHans: "打招呼", zhHant: "打招呼") }
    static var hide: String { t(en: "Hide", ko: "숨기기", ja: "隠す", zhHans: "隐藏", zhHant: "隱藏") }
    static var show: String { t(en: "Show", ko: "보이기", ja: "表示", zhHans: "显示", zhHant: "顯示") }
    static var resetPosition: String { t(en: "Reset Position", ko: "위치 리셋", ja: "位置をリセット", zhHans: "重置位置", zhHant: "重設位置") }
    static var quit: String { t(en: "Quit", ko: "종료", ja: "終了", zhHans: "退出", zhHant: "結束") }
    static var pet: String { t(en: "Pet", ko: "펫", ja: "ペット", zhHans: "宠物", zhHant: "寵物") }
    static var size: String { t(en: "Size", ko: "크기", ja: "サイズ", zhHans: "大小", zhHant: "大小") }
    static var smaller: String { t(en: "Smaller", ko: "작게", ja: "小さく", zhHans: "小", zhHant: "小") }
    static var larger: String { t(en: "Larger", ko: "크게", ja: "大きく", zhHans: "大", zhHant: "大") }
    static var noPets: String { t(en: "No pets found", ko: "펫 없음", ja: "ペットがありません", zhHans: "没有宠物", zhHant: "沒有寵物") }
    static var clickThrough: String { t(en: "Click-through", ko: "클릭 통과", ja: "クリック透過", zhHans: "点击穿透", zhHant: "點擊穿透") }
    static var captions: String { t(en: "Captions", ko: "말풍선", ja: "吹き出し", zhHans: "气泡", zhHant: "氣泡") }
    static var perch: String { t(en: "Sit on windows", ko: "창에 앉기", ja: "ウィンドウに座る", zhHans: "坐在窗口上", zhHant: "坐在視窗上") }
    static var gravity: String { t(en: "Gravity", ko: "중력", ja: "重力", zhHans: "重力", zhHant: "重力") }
    static var sound: String { t(en: "Alert sound", ko: "알림 소리", ja: "通知音", zhHans: "提示音", zhHant: "提示音") }

    static var languageAuto: String {
        let name: String
        switch detect() {
        case .ko: name = "한국어"
        case .en: name = "English"
        case .ja: name = "日本語"
        case .zhHans: name = "简体中文"
        case .zhHant: name = "繁體中文"
        }
        return t(
            en: "Automatic (\(name))",
            ko: "자동 (\(name))",
            ja: "自動（\(name)）",
            zhHans: "自动（\(name)）",
            zhHant: "自動（\(name)）"
        )
    }

    static var captionWaiting: String {
        speak(
            en: ("Needs you", "Please check", "Over here!"),
            ko: ("허락해줘", "허락해 주세요", "눌러줘~"),
            ja: ("見て", "お願いします", "みてみて"),
            zhHans: ("求确认", "请确认", "拜托啦"),
            zhHant: ("求確認", "請確認", "拜託啦")
        )
    }

    static var captionFailed: String {
        speak(
            en: ("Ouch", "Something broke", "Ow!"),
            ko: ("앗", "문제가 생겼어요", "아야"),
            ja: ("痛い", "失敗しました", "いたっ"),
            zhHans: ("哎呀", "出错了", "呜哇"),
            zhHant: ("哎呀", "出錯了", "嗚哇")
        )
    }

    static var captionReview: String {
        speak(
            en: ("Done", "Finished", "All done!"),
            ko: ("끝", "끝났어요", "다 했어!"),
            ja: ("できた", "完了です", "できたよ"),
            zhHans: ("好了", "完成了", "好啦"),
            zhHant: ("好了", "完成了", "好啦")
        )
    }

    static var captionHi: String {
        speak(
            en: ("Hi", "Hello", "Hey!"),
            ko: ("안녕", "안녕하세요", "안녕!"),
            ja: ("やあ", "こんにちは", "やっほ"),
            zhHans: ("嗨", "你好", "嗨嗨"),
            zhHant: ("嗨", "你好", "嗨嗨")
        )
    }

    static var working: String {
        speak(
            en: ("Working", "Working", "Busy"),
            ko: ("작업 중", "작업 중", "일하는 중"),
            ja: ("作業中", "作業中", "がんばる"),
            zhHans: ("工作中", "工作中", "干活中"),
            zhHant: ("工作中", "工作中", "幹活中")
        )
    }

    static var doneNotify: String {
        speak(
            en: ("A turn finished.", "A turn finished.", "I finished!"),
            ko: ("작업이 끝났어", "작업이 끝났어요", "다 했어!"),
            ja: ("終わったよ", "作業が終わりました", "おわったよ"),
            zhHans: ("做完了", "任务已完成", "搞定啦"),
            zhHant: ("做完了", "任務已完成", "搞定啦")
        )
    }

    static func tool(_ raw: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "" }
        let last = (name as NSString).lastPathComponent
        let compact = last.lowercased().replacingOccurrences(of: "_", with: "")
        switch compact {
        case "bash", "execcommand", "shell":
            return t(en: "shell", ko: "명령", ja: "コマンド", zhHans: "命令", zhHant: "命令")
        case "applypatch", "edit", "write":
            return t(en: "edit", ko: "수정", ja: "編集", zhHans: "修改", zhHant: "修改")
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

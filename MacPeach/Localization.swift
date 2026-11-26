import SwiftUI

enum Lang: String, CaseIterable, Identifiable, Sendable {
    case pl, en

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pl: return "Polski"
        case .en: return "English"
        }
    }

    nonisolated static var systemDefault: Lang {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("pl") == true ? .pl : .en
    }

    nonisolated static var current: Lang {
        UserDefaults.standard.string(forKey: SettingsKey.language).flatMap(Lang.init(rawValue:)) ?? systemDefault
    }
}

nonisolated struct BiText: Hashable, Sendable {
    let en: String
    let pl: String

    nonisolated init(en: String, pl: String? = nil) {
        self.en = en
        self.pl = pl ?? en
    }

    nonisolated func resolve(_ lang: Lang) -> String {
        lang == .pl ? pl : en
    }
}

nonisolated struct Loc: Sendable {
    let lang: Lang

    func callAsFunction(_ pl: String, _ en: String) -> String {
        lang == .pl ? pl : en
    }

    func callAsFunction(_ text: BiText) -> String {
        text.resolve(lang)
    }

    var locale: Locale {
        Locale(identifier: lang == .pl ? "pl_PL" : "en_US")
    }

    func count(_ n: Int, pl one: String, _ few: String, _ many: String, en singular: String, _ plural: String) -> String {
        if lang == .en { return "\(n) \(n == 1 ? singular : plural)" }
        if n == 1 { return "\(n) \(one)" }
        let lastTwo = n % 100, last = n % 10
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "\(n) \(few)" }
        return "\(n) \(many)"
    }
}

extension EnvironmentValues {
    @Entry var loc = Loc(lang: .en)
}

nonisolated enum SettingsKey {
    static let language = "language"
    static let appearance = "appearance"
    static let selectedTab = "selectedTab"
    static let completedSteps = "completedExtraSteps"
}

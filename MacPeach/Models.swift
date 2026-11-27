import Foundation

enum Tab: String, CaseIterable, Identifiable {
    case install, sysconfig, extras, presets

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .install: return "arrow.down.circle.fill"
        case .sysconfig: return "gearshape.2.fill"
        case .extras: return "puzzlepiece.extension.fill"
        case .presets: return "square.and.arrow.down.fill"
        }
    }

    func title(_ t: Loc) -> String {
        switch self {
        case .install: return t("Aplikacje", "Applications")
        case .sysconfig: return t("Konfiguracja systemu", "System Configuration")
        case .extras: return t("Dodatki", "Add-ons")
        case .presets: return t("Presety", "Presets")
        }
    }

    func subtitle(_ t: Loc) -> String {
        switch self {
        case .install: return t("Programy z Homebrew", "Apps from Homebrew")
        case .sysconfig: return t("Ustawienia dla programisty", "Developer settings")
        case .extras: return t("To, czego brakuje w macOS", "What macOS is missing")
        case .presets: return t("Przenieś swój zestaw", "Reuse your setup")
        }
    }
}

enum InstallState: Equatable {
    case unknown, missing, viaBrew, manual

    var isInstalled: Bool { self == .viaBrew || self == .manual }
}

struct InstallItem: Identifiable, Equatable {
    let brewName: String
    let isCask: Bool
    let name: String
    let category: BiText
    let icon: String
    var summary: BiText?
    var isChecked = false
    var state: InstallState = .unknown

    var id: String { (isCask ? "cask:" : "formula:") + brewName }

    var command: String { isCask ? "brew install --cask \(brewName)" : "brew install \(brewName)" }
}

nonisolated struct TweakOption: Hashable, Sendable {
    let value: String
    let label: BiText
}

/// Effect of a setting on system security, from a `# @security lowers|raises` line in MacSetup.sh.
nonisolated enum TweakSecurity: String, Sendable {
    case lowers, raises
}

nonisolated struct TweakItem: Identifiable, Equatable {
    let key: String
    let title: BiText
    let category: BiText
    let commands: [String]
    let icon: String
    var options: [TweakOption] = []
    var currentCommand: String?
    var security: TweakSecurity?
    var isOn = false
    var isApplied: Bool?
    var selectedValue: String?
    var currentValue: String?
    var isAvailable = true

    var id: String { key }

    var isChoice: Bool { !options.isEmpty }

    var needsAdmin: Bool { commands.contains { $0.hasPrefix("sudo ") } }

    static let placeholder = try! NSRegularExpression(pattern: #"\$\{VALUE:-([^}]*)\}"#)

    var defaultValue: String? {
        for command in commands {
            let range = NSRange(command.startIndex..., in: command)
            if let match = Self.placeholder.firstMatch(in: command, range: range),
               let r = Range(match.range(at: 1), in: command) {
                return String(command[r])
            }
        }
        return options.first?.value
    }

    var resolvedCommands: [String] {
        guard isChoice, let value = selectedValue ?? defaultValue else { return commands }
        let safe = value.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil ? value : (defaultValue ?? "")
        return commands.map {
            Self.placeholder.stringByReplacingMatches(in: $0, range: NSRange($0.startIndex..., in: $0),
                                                      withTemplate: NSRegularExpression.escapedTemplate(for: safe))
        }
    }

    func label(for value: String?) -> BiText? {
        guard let value else { return nil }
        return options.first { $0.value == value }?.label ?? BiText(en: value)
    }

    var presetEntry: String {
        isChoice ? "\(key)=\(selectedValue ?? defaultValue ?? "")" : key
    }
}

enum InstallGroup: String, CaseIterable, Identifiable {
    case apps, tools
    var id: String { rawValue }
}

struct Preset: Codable, Identifiable, Hashable {
    var name: String
    var createdAt: Date
    var formulae: [String]
    var casks: [String]
    var tweaks: [String]

    var id: String { name }

    var itemCount: Int { formulae.count + casks.count + tweaks.count }

    enum CodingKeys: String, CodingKey {
        case name, createdAt
        case formulae = "selectedBrewTools"
        case casks = "selectedAppCasks"
        case tweaks = "selectedSysConfig"
    }

    init(name: String, createdAt: Date, formulae: [String], casks: [String], tweaks: [String]) {
        self.name = name
        self.createdAt = createdAt
        self.formulae = formulae
        self.casks = casks
        self.tweaks = tweaks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        formulae = (try? c.decode([String].self, forKey: .formulae)) ?? []
        casks = (try? c.decode([String].self, forKey: .casks)) ?? []
        tweaks = (try? c.decode([String].self, forKey: .tweaks)) ?? []
    }
}

struct Extra: Identifiable {
    let id: String
    let icon: String
    let title: BiText
    let summary: BiText
    let note: BiText?
    let steps: [ExtraStep]
    let undo: ExtraAction?
}

struct ExtraStep: Identifiable {
    let id: String
    let title: BiText
    let script: (Lang) -> String
    let requiresBrew: Bool
    let check: String?
}

struct ExtraAction {
    let title: BiText
    let script: (Lang) -> String
}

enum BrewStatus: Equatable {
    case checking
    case missing
    case installed(version: String, prefix: String)

    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }
}

struct ScriptJob: Identifiable {
    enum Kind: Equatable {
        case install, tweaks, homebrew, maintenance
        case extraStep(String)
        case extraUndo(String)
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let script: String
    let requiresBrew: Bool
}

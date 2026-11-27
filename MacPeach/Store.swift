import Foundation
import Combine
import AppKit

@MainActor
final class AppStore: ObservableObject {
    @Published var formulae: [InstallItem] = []
    @Published var casks: [InstallItem] = []
    @Published var tweaks: [TweakItem] = []
    @Published var presets: [Preset] = []
    @Published var brew: BrewStatus = .checking
    @Published var device: DeviceInfo = .placeholder
    @Published var isScanning = false
    @Published var extraStates: [String: Bool] = [:]
    @Published var activeJob: ScriptJob?

    let extras: [Extra] = ExtrasCatalog.all

    private var completedSteps: Set<String> {
        didSet { UserDefaults.standard.set(Array(completedSteps), forKey: SettingsKey.completedSteps) }
    }

    nonisolated static var presetsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/macpeach/presets.json")
    }

    init() {
        completedSteps = Set(UserDefaults.standard.stringArray(forKey: SettingsKey.completedSteps) ?? [])
        reloadCatalog()
        loadPresets()
        refreshDevice()
        refreshBrew()
        refreshTweakStates()
        refreshExtraStates()
        scanInstalled()
    }

    var selectedFormulae: [InstallItem] { formulae.filter(\.isChecked) }
    var selectedCasks: [InstallItem] { casks.filter(\.isChecked) }
    var selectedTweaks: [TweakItem] { tweaks.filter { $0.isOn && $0.isAvailable } }
    var visibleTweaks: [TweakItem] { tweaks.filter(\.isAvailable) }
    var selectedInstallCount: Int { selectedFormulae.count + selectedCasks.count }

    func reloadCatalog() {
        do {
            let catalog = ShParser.parse(try CatalogSource.load())
            let checkedIDs = Set((formulae + casks).filter(\.isChecked).map(\.id))
            let states = Dictionary((formulae + casks).map { ($0.id, $0.state) }, uniquingKeysWith: { a, _ in a })
            let onTweaks = Set(tweaks.filter(\.isOn).map(\.key))
            let chosen = Dictionary(tweaks.compactMap { t in t.selectedValue.map { (t.key, $0) } }, uniquingKeysWith: { a, _ in a })
            formulae = catalog.formulae.map { restore($0, checked: checkedIDs, states: states) }
            casks = catalog.casks.map { restore($0, checked: checkedIDs, states: states) }
            tweaks = catalog.tweaks.map { var t = $0; t.isOn = onTweaks.contains(t.key); t.selectedValue = chosen[t.key]; return t }
            AppLog.shared.info("Catalog loaded from \(CatalogSource.usesCustomFile ? CatalogSource.customURL.path : "app bundle"): \(formulae.count) formulae, \(casks.count) casks, \(tweaks.count) settings")
            if formulae.isEmpty && casks.isEmpty && tweaks.isEmpty {
                let t = Loc(lang: Lang.current)
                ErrorCenter.shared.report(
                    title: t("Pusta lista pakietów", "Empty package list"),
                    message: t("W pliku MacSetup.sh nie znaleziono żadnych pozycji. Sprawdź znaczniki PIPELINE 1–3.",
                               "No entries were found in MacSetup.sh. Check the PIPELINE 1–3 markers."),
                    fileURL: CatalogSource.usesCustomFile ? CatalogSource.customURL : nil
                )
            }
        } catch {
            ErrorCenter.shared.report(error, context: Loc(lang: Lang.current)("Nie udało się wczytać pliku MacSetup.sh.", "Could not read MacSetup.sh."))
        }
        refreshTweakStates()
    }

    private func restore(_ item: InstallItem, checked: Set<String>, states: [String: InstallState]) -> InstallItem {
        var copy = item
        copy.isChecked = checked.contains(item.id)
        copy.state = states[item.id] ?? .unknown
        return copy
    }

    func refreshDevice() {
        Task.detached(priority: .utility) {
            let info = SystemInfo.read()
            await MainActor.run { [weak self] in
                if self?.device != info { self?.device = info }
            }
        }
    }

    func refreshStorage() {
        Task.detached(priority: .utility) {
            let storage = SystemInfo.storageCapacity()
            await MainActor.run { [weak self] in
                guard let self, self.device.storageFree != storage.free || self.device.storageTotal != storage.total else { return }
                self.device.storageFree = storage.free
                self.device.storageTotal = storage.total
            }
        }
    }

    func refreshBrew() {
        brew = .checking
        Task.detached(priority: .userInitiated) {
            let status = Shell.brewStatus()
            await MainActor.run { [weak self] in self?.brew = status }
        }
    }

    func scanInstalled() {
        guard !isScanning else { return }
        isScanning = true
        let caskNames = casks.map(\.brewName)
        let lookup = casks.map { ($0.brewName, $0.name) }
        Task {
            let metadata = await BrewMetadata.casks(caskNames)
            let result = await Task.detached(priority: .userInitiated) {
                InstalledScanner.scan(casks: lookup, metadata: metadata)
            }.value
            apply(scan: result)
            isScanning = false
        }
    }

    private func apply(scan: InstalledScanner.Result) {
        var viaBrew = 0, manual = 0
        for i in formulae.indices {
            let installed = scan.formulae.contains(formulae[i].brewName)
            formulae[i].state = installed ? .viaBrew : .missing
            if installed { viaBrew += 1 }
        }
        for i in casks.indices {
            let name = casks[i].brewName
            if scan.casks.contains(name) {
                casks[i].state = .viaBrew
                viaBrew += 1
            } else if scan.manualCasks.contains(name) {
                casks[i].state = .manual
                manual += 1
            } else {
                casks[i].state = .missing
            }
        }
        AppLog.shared.info("Installed scan: \(viaBrew) via Homebrew, \(manual) installed manually, brew available: \(scan.brewAvailable)")
    }

    /// `@current` commands from a custom MacSetup.sh that the user has not approved yet are never run.
    /// Commands identical to the ones shipped in the app bundle are trusted.
    private var declinedCurrentCommands: Set<String> = []
    private var isAskingAboutCurrentCommands = false

    private var approvedCurrentCommands: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: SettingsKey.approvedCurrentCommands) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: SettingsKey.approvedCurrentCommands) }
    }

    private func allowedCurrentCommands() -> Set<String> {
        let all = Set(tweaks.compactMap(\.currentCommand))
        guard CatalogSource.usesCustomFile else { return all }
        let trusted = CatalogSource.bundledCurrentCommands.union(approvedCurrentCommands)
        let unknown = all.subtracting(trusted).subtracting(declinedCurrentCommands)
        if !unknown.isEmpty && !isAskingAboutCurrentCommands {
            isAskingAboutCurrentCommands = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.confirmCurrentCommands(unknown)
                self.isAskingAboutCurrentCommands = false
                self.refreshTweakStates()
            }
        }
        return all.intersection(trusted)
    }

    private func confirmCurrentCommands(_ commands: Set<String>) {
        let t = Loc(lang: Lang.current)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = t("Uruchomić polecenia z własnego MacSetup.sh?", "Run commands from your custom MacSetup.sh?")
        alert.informativeText = t(
            "Twój plik \(CatalogSource.customURL.path) zawiera polecenia @current, których nie ma w wersji dołączonej do aplikacji. MacPeach uruchamia je przy starcie, aby odczytać bieżące wartości ustawień. Uruchom je tylko, jeśli wiesz, co robią:",
            "Your file \(CatalogSource.customURL.path) contains @current commands that are not in the version shipped with the app. MacPeach runs them on launch to read current setting values. Only run them if you know what they do:"
        ) + "\n\n" + commands.sorted().joined(separator: "\n\n")
        alert.addButton(withTitle: t("Nie uruchamiaj", "Don't run"))
        alert.addButton(withTitle: t("Uruchom i zapamiętaj", "Run and remember"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            approvedCurrentCommands = approvedCurrentCommands.union(commands)
            AppLog.shared.info("Approved \(commands.count) @current command(s) from the custom MacSetup.sh")
        } else {
            declinedCurrentCommands.formUnion(commands)
            AppLog.shared.warning("Skipped \(commands.count) unapproved @current command(s) from the custom MacSetup.sh")
        }
    }

    func refreshTweakStates() {
        let allowed = allowedCurrentCommands()
        let snapshot = tweaks.map { ($0.key, $0.commands, $0.currentCommand.flatMap { allowed.contains($0) ? $0 : "" }) }
        Task.detached(priority: .utility) {
            var states: [String: Bool?] = [:]
            var currents: [String: String] = [:]
            for (key, commands, current) in snapshot {
                if let current {
                    guard !current.isEmpty else { currents[key] = ""; continue }
                    currents[key] = Shell.output("/bin/bash", ["-c", current], timeout: 10)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                } else {
                    states[key] = TweakState.isApplied(commands)
                }
            }
            let applied = states
            let values = currents
            await MainActor.run { [weak self] in
                guard let self else { return }
                for i in self.tweaks.indices {
                    let key = self.tweaks[i].key
                    if self.tweaks[i].isChoice {
                        let value = values[key] ?? ""
                        self.tweaks[i].currentValue = value.isEmpty ? nil : value
                        self.tweaks[i].isAvailable = !value.isEmpty
                        if self.tweaks[i].selectedValue == nil || !self.tweaks[i].isOn {
                            self.tweaks[i].selectedValue = value.isEmpty ? self.tweaks[i].defaultValue : value
                        }
                        if !self.tweaks[i].isAvailable { self.tweaks[i].isOn = false }
                    } else {
                        let value = applied[key] ?? nil
                        if self.tweaks[i].isApplied != value { self.tweaks[i].isApplied = value }
                    }
                }
            }
        }
    }

    func refreshExtraStates() {
        let checks = extras.flatMap { $0.steps }.compactMap { step in step.check.map { (step.id, $0) } }
        let completed = completedSteps
        Task.detached(priority: .utility) {
            let states = Dictionary(uniqueKeysWithValues: checks.map { ($0.0, Shell.succeeds($0.1)) })
            await MainActor.run { [weak self] in
                guard let self else { return }
                var merged = states
                for id in completed where merged[id] == nil { merged[id] = true }
                self.extraStates = merged
            }
        }
    }

    func isStepDone(_ step: ExtraStep) -> Bool {
        extraStates[step.id] ?? false
    }

    func run(_ job: ScriptJob) {
        activeJob = job
    }

    func finished(_ job: ScriptJob, success: Bool) {
        switch job.kind {
        case .install:
            refreshStorage()
            scanInstalled()
        case .tweaks:
            refreshTweakStates()
        case .homebrew, .maintenance:
            refreshBrew()
            refreshStorage()
        case .extraStep(let id):
            if success { completedSteps.insert(id) }
            refreshExtraStates()
        case .extraUndo(let extraID):
            if success, let extra = extras.first(where: { $0.id == extraID }) {
                for step in extra.steps { completedSteps.remove(step.id) }
            }
            refreshExtraStates()
        }
    }

    func setAll(_ group: InstallGroup, category: BiText, to value: Bool) {
        switch group {
        case .apps:
            for i in casks.indices where casks[i].category == category { casks[i].isChecked = value }
        case .tools:
            for i in formulae.indices where formulae[i].category == category { formulae[i].isChecked = value }
        }
    }

    func setAllTweaks(category: BiText, to value: Bool) {
        for i in tweaks.indices where tweaks[i].category == category && tweaks[i].isAvailable {
            tweaks[i].isOn = value && !(tweaks[i].isChoice && tweaks[i].selectedValue == tweaks[i].currentValue)
        }
    }

    func clearInstallSelection() {
        for i in formulae.indices { formulae[i].isChecked = false }
        for i in casks.indices { casks[i].isChecked = false }
    }

    func clearTweakSelection() {
        for i in tweaks.indices { tweaks[i].isOn = false }
    }

    func selectUnappliedTweaks() {
        for i in tweaks.indices where !tweaks[i].isChoice {
            tweaks[i].isOn = tweaks[i].isApplied != true
        }
    }

    func makePreset(named name: String) -> Preset {
        Preset(
            name: name,
            createdAt: Date(),
            formulae: selectedFormulae.map(\.brewName),
            casks: selectedCasks.map(\.brewName),
            tweaks: selectedTweaks.map(\.presetEntry)
        )
    }

    func savePreset(named name: String) {
        let preset = makePreset(named: name)
        presets.removeAll { $0.name == name }
        presets.insert(preset, at: 0)
        persistPresets()
    }

    func apply(_ preset: Preset) {
        let f = Set(preset.formulae), c = Set(preset.casks)
        var chosen: [String: String?] = [:]
        for entry in preset.tweaks {
            if let eq = entry.lastIndex(of: "="), tweaks.contains(where: { $0.key == String(entry[..<eq]) && $0.isChoice }) {
                chosen[String(entry[..<eq])] = String(entry[entry.index(after: eq)...])
            } else {
                chosen[entry] = .some(nil)
            }
        }
        for i in formulae.indices { formulae[i].isChecked = f.contains(formulae[i].brewName) }
        for i in casks.indices { casks[i].isChecked = c.contains(casks[i].brewName) }
        for i in tweaks.indices {
            guard let value = chosen[tweaks[i].key] else { tweaks[i].isOn = false; continue }
            tweaks[i].isOn = tweaks[i].isAvailable
            if tweaks[i].isChoice, let value, tweaks[i].options.contains(where: { $0.value == value }) {
                tweaks[i].selectedValue = value
            }
        }
    }

    func unknownEntries(in preset: Preset) -> Int {
        let f = Set(formulae.map(\.brewName)), c = Set(casks.map(\.brewName)), t = Set(tweaks.map(\.key))
        return preset.formulae.filter { !f.contains($0) }.count
            + preset.casks.filter { !c.contains($0) }.count
            + preset.tweaks.filter { entry in
                let key = entry.lastIndex(of: "=").map { String(entry[..<$0]) } ?? entry
                return !t.contains(key) && !t.contains(entry)
            }.count
    }

    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.name == preset.name }
        persistPresets()
    }

    func importPreset(from url: URL) throws -> Preset {
        let data = try SafeFile.read(url, limit: 1_000_000)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var preset: Preset
        if let single = try? decoder.decode(Preset.self, from: data) {
            preset = single
        } else {
            let list = try decoder.decode([Preset].self, from: data)
            guard let first = list.first else { throw CocoaError(.fileReadCorruptFile) }
            preset = first
        }
        preset.name = String(preset.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        if preset.name.isEmpty { preset.name = url.deletingPathExtension().lastPathComponent }
        preset.formulae = preset.formulae.filter(ShParser.isSafePackageName)
        preset.casks = preset.casks.filter(ShParser.isSafePackageName)
        presets.removeAll { $0.name == preset.name }
        presets.insert(preset, at: 0)
        persistPresets()
        return preset
    }

    func export(_ preset: Preset, to url: URL) throws {
        try encoder().encode(preset).write(to: url, options: .atomic)
    }

    private func loadPresets() {
        let url = Self.presetsURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            presets = try decoder.decode([Preset].self, from: SafeFile.read(url, limit: 5_000_000))
        } catch {
            let backup = url.deletingLastPathComponent().appendingPathComponent("presets.broken.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
            let t = Loc(lang: Lang.current)
            ErrorCenter.shared.report(
                title: t("Nie udało się wczytać presetów", "Could not load presets"),
                message: t("Plik presets.json jest uszkodzony. Jego kopię zapisano jako presets.broken.json.",
                           "presets.json is damaged. A copy was saved as presets.broken.json."),
                details: error.localizedDescription,
                fileURL: backup
            )
        }
    }

    func persistPresets() {
        let url = Self.presetsURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder().encode(presets).write(to: url, options: .atomic)
        } catch {
            ErrorCenter.shared.report(error, context: Loc(lang: Lang.current)("Nie udało się zapisać presetów.", "Could not save presets."))
        }
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

nonisolated enum InstalledScanner {
    struct Result: Sendable {
        var formulae: Set<String> = []
        var casks: Set<String> = []
        var manualCasks: Set<String> = []
        var brewAvailable = false
    }

    static func scan(casks: [(String, String)], metadata: [String: CaskMetadata]) -> Result {
        var result = Result()
        if let brew = Shell.brewPath() {
            result.brewAvailable = true
            result.formulae = Set(Shell.output(brew, ["list", "--formula", "-1"])?.split(separator: "\n").map(String.init) ?? [])
            result.casks = Set(Shell.output(brew, ["list", "--cask", "-1"])?.split(separator: "\n").map(String.init) ?? [])
        }
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let appFolders = ["/Applications", "\(home)/Applications", "/Applications/Utilities"]
        let binFolders = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin"]
        for (name, label) in casks where !result.casks.contains(name) {
            let meta = metadata[name]
            let apps = meta?.apps.isEmpty == false ? meta!.apps : (meta?.binaries.isEmpty == false ? [] : ["\(label).app"])
            let foundApp = apps.contains { app in appFolders.contains { fm.fileExists(atPath: "\($0)/\(app)") } }
            let foundBinary = (meta?.binaries ?? []).contains { bin in binFolders.contains { fm.isExecutableFile(atPath: "\($0)/\(bin)") } }
            if foundApp || foundBinary { result.manualCasks.insert(name) }
        }
        return result
    }
}

nonisolated enum TweakState {
    static func isApplied(_ commands: [String]) -> Bool? {
        guard !commands.isEmpty else { return nil }
        for command in commands {
            guard let applied = check(command) else { return nil }
            if !applied { return false }
        }
        return true
    }

    private static func check(_ command: String) -> Bool? {
        let tokens = ShellWords.split(command)
        guard let first = tokens.first else { return nil }
        let fm = FileManager.default
        switch first {
        case "defaults":
            return checkDefaults(Array(tokens.dropFirst()))
        case "mkdir":
            guard let path = tokens.last, path != "-p" else { return nil }
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        case "touch":
            guard tokens.count == 2 else { return nil }
            return fm.fileExists(atPath: tokens[1])
        case "chflags":
            guard tokens.count == 3, tokens[1] == "nohidden" else { return nil }
            let values = try? URL(fileURLWithPath: tokens[2]).resourceValues(forKeys: [.isHiddenKey])
            return values?.isHidden == false
        default:
            return nil
        }
    }

    private static func checkDefaults(_ args: [String]) -> Bool? {
        var args = args
        var host = kCFPreferencesAnyHost
        if args.first == "-currentHost" {
            host = kCFPreferencesCurrentHost
            args.removeFirst()
        }
        guard args.count >= 5, args[0] == "write" else { return nil }
        let domain = args[1] == "NSGlobalDomain" || args[1] == "-g" ? kCFPreferencesAnyApplication : args[1] as CFString
        let key = args[2] as CFString
        let type = args[3]
        let expected = args[4]
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, host)
        let value = CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, host)
        guard let value else { return false }
        switch type {
        case "-bool", "-boolean":
            let want = ["true", "yes", "1"].contains(expected.lowercased())
            if let number = value as? NSNumber { return number.boolValue == want }
            if let string = value as? String { return ["true", "yes", "1"].contains(string.lowercased()) == want }
            return false
        case "-int", "-integer":
            guard let want = Int(expected) else { return nil }
            if let number = value as? NSNumber { return number.intValue == want }
            if let string = value as? String { return Int(string) == want }
            return false
        case "-float":
            guard let want = Double(expected) else { return nil }
            if let number = value as? NSNumber { return abs(number.doubleValue - want) < 0.0001 }
            if let string = value as? String, let d = Double(string) { return abs(d - want) < 0.0001 }
            return false
        case "-string":
            return (value as? String) == expected
        default:
            return nil
        }
    }
}

nonisolated enum ShellWords {
    static func split(_ line: String) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var tokens: [String] = []
        var current = ""
        var hasToken = false
        var quote: Character?
        for char in line {
            if let q = quote {
                if char == q { quote = nil } else { current.append(char) }
            } else if char == "\"" || char == "'" {
                quote = char
                hasToken = true
            } else if char == " " || char == "\t" {
                if hasToken { tokens.append(current); current = ""; hasToken = false }
            } else {
                current.append(char)
                hasToken = true
            }
        }
        if hasToken { tokens.append(current) }
        return tokens.map {
            $0.replacingOccurrences(of: "${HOME}", with: home).replacingOccurrences(of: "$HOME", with: home)
        }
    }
}

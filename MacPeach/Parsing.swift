import Foundation

struct Catalog {
    var formulae: [InstallItem]
    var casks: [InstallItem]
    var tweaks: [TweakItem]

    static let empty = Catalog(formulae: [], casks: [], tweaks: [])
}

nonisolated enum CatalogSource {
    static var customURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/macpeach/MacSetup.sh")
    }

    static var bundledURL: URL? {
        Bundle.main.url(forResource: "MacSetup", withExtension: "sh")
    }

    static var usesCustomFile: Bool {
        FileManager.default.fileExists(atPath: customURL.path)
    }

    /// `@current` commands from the MacSetup.sh shipped inside the (signed) app bundle.
    static let bundledCurrentCommands: Set<String> = {
        guard let url = bundledURL, let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return Set(ShParser.parse(text).tweaks.compactMap(\.currentCommand))
    }()

    static func load() throws -> String {
        if usesCustomFile {
            return String(decoding: try SafeFile.read(customURL, limit: 2_000_000), as: UTF8.self)
        }
        guard let url = bundledURL else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "MacSetup.sh"])
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func createCustomCopy() throws -> URL {
        let fm = FileManager.default
        let target = customURL
        if !fm.fileExists(atPath: target.path) {
            guard let source = bundledURL else { throw CocoaError(.fileNoSuchFile) }
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: target)
        }
        return target
    }
}

/// Reads only regular files up to a size limit, checked before any bytes are loaded.
nonisolated enum SafeFile {
    static func read(_ url: URL, limit: Int) throws -> Data {
        let values = try url.resolvingSymlinksInPath().resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else {
            throw CocoaError(.fileReadInvalidFileName, userInfo: [NSFilePathErrorKey: url.path])
        }
        guard (values.fileSize ?? .max) <= limit else {
            throw CocoaError(.fileReadTooLarge, userInfo: [NSFilePathErrorKey: url.path])
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw CocoaError(.fileReadTooLarge, userInfo: [NSFilePathErrorKey: url.path]) }
        return data
    }
}

nonisolated enum ShParser {
    private enum Pipeline { case formulae, casks, tweaks }

    static func parse(_ script: String) -> Catalog {
        var segments: [Pipeline: [String]] = [:]
        var active: Pipeline?
        for line in script.components(separatedBy: .newlines) {
            let upper = line.uppercased()
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("#"), upper.contains("PIPELINE") {
                if upper.contains("PIPELINE 1") { active = .formulae; continue }
                if upper.contains("PIPELINE 2") { active = .casks; continue }
                if upper.contains("PIPELINE 3") { active = .tweaks; continue }
            }
            if let active { segments[active, default: []].append(line) }
        }
        return Catalog(
            formulae: parseInstalls(segments[.formulae] ?? [], isCask: false),
            casks: parseInstalls(segments[.casks] ?? [], isCask: true),
            tweaks: parseTweaks(segments[.tweaks] ?? [])
        )
    }

    static func bilingual(_ text: String) -> BiText {
        let parts = text.components(separatedBy: " | ")
        let en = parts[0].trimmingCharacters(in: .whitespaces)
        let pl = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil
        return BiText(en: en, pl: pl)
    }

    private static func sectionTitle(_ comment: String) -> BiText? {
        guard comment.hasPrefix("---") else { return nil }
        let inner = comment.trimmingCharacters(in: CharacterSet(charactersIn: "- "))
        return inner.isEmpty ? nil : bilingual(inner)
    }

    private static func parseInstalls(_ lines: [String], isCask: Bool) -> [InstallItem] {
        var items: [InstallItem] = []
        var seen = Set<String>()
        var category = BiText(en: isCask ? "Applications" : "Tools", pl: isCask ? "Aplikacje" : "Narzędzia")
        var label: String?
        var summary: BiText?

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#") {
                let comment = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                if comment.isEmpty || comment.hasPrefix("===") { continue }
                if let section = sectionTitle(comment) {
                    category = section
                } else {
                    summary = bilingual(comment)
                }
                label = nil
                continue
            }
            if line.hasPrefix("echo ") {
                label = echoLabel(line)
                continue
            }
            guard let name = brewName(in: line, isCask: isCask), seen.insert(name).inserted else { continue }
            items.append(InstallItem(
                brewName: name,
                isCask: isCask,
                name: label ?? prettify(name),
                category: category,
                icon: Icons.package[name] ?? (isCask ? "app.dashed" : "terminal"),
                summary: summary
            ))
            label = nil
            summary = nil
        }
        return items
    }

    private static func parseTweaks(_ lines: [String]) -> [TweakItem] {
        var items: [TweakItem] = []
        var category = BiText(en: "System")
        var title: BiText?
        var commands: [String] = []
        var options: [TweakOption] = []
        var current: String?
        var security: TweakSecurity?

        func flush() {
            defer { title = nil; commands = []; options = []; current = nil; security = nil }
            guard !commands.isEmpty else { return }
            let resolved = title ?? BiText(en: commands[0])
            guard !items.contains(where: { $0.key == resolved.en }) else { return }
            items.append(TweakItem(
                key: resolved.en,
                title: resolved,
                category: category,
                commands: commands,
                icon: Icons.tweak(for: commands.joined(separator: " ")),
                options: options,
                currentCommand: options.isEmpty ? nil : current,
                security: security
            ))
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("#") {
                let comment = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                if comment.hasPrefix("@options ") {
                    options = parseOptions(String(comment.dropFirst(9)))
                    continue
                }
                if comment.hasPrefix("@security ") {
                    security = TweakSecurity(rawValue: String(comment.dropFirst(10)).trimmingCharacters(in: .whitespaces).lowercased())
                    continue
                }
                if comment.hasPrefix("@current ") {
                    current = String(comment.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                    continue
                }
                flush()
                if comment.isEmpty || comment.hasPrefix("===") { continue }
                if let section = sectionTitle(comment) {
                    category = section
                } else {
                    title = bilingual(comment)
                }
                continue
            }
            if line.hasPrefix("echo ") || line.hasPrefix("killall ") || line.hasPrefix("set ") { continue }
            commands.append(line)
        }
        flush()
        return items
    }

    private static func parseOptions(_ text: String) -> [TweakOption] {
        text.split(separator: ";").compactMap { part in
            let pieces = part.split(separator: "=", maxSplits: 1)
            guard pieces.count == 2 else { return nil }
            let value = pieces[0].trimmingCharacters(in: .whitespaces)
            let labels = pieces[1].split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard !value.isEmpty, let en = labels.first else { return nil }
            return TweakOption(value: value, label: BiText(en: en, pl: labels.count > 1 ? labels[1] : nil))
        }
    }

    private static func echoLabel(_ line: String) -> String? {
        let cleaned = line.dropFirst(5)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            .replacingOccurrences(of: "Installing ", with: "", options: [.caseInsensitive, .anchored])
            .replacingOccurrences(of: "...", with: "")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static let formulaPattern = try? NSRegularExpression(pattern: #"^brew install (?!--cask\b)([A-Za-z0-9@._+-]+(?:/[A-Za-z0-9@._+-]+){0,2})(?:\s|$)"#)
    private static let caskPattern = try? NSRegularExpression(pattern: #"^brew install --cask ([A-Za-z0-9@._+-]+(?:/[A-Za-z0-9@._+-]+){0,2})(?:\s|$)"#)

    static func brewName(in line: String, isCask: Bool) -> String? {
        guard let regex = isCask ? caskPattern : formulaPattern,
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }

    static func isSafePackageName(_ name: String) -> Bool {
        name.range(of: #"^[A-Za-z0-9@._+-]+(/[A-Za-z0-9@._+-]+){0,2}$"#, options: .regularExpression) != nil
    }

    private static func prettify(_ name: String) -> String {
        name.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

nonisolated enum Icons {
    static let package: [String: String] = [
        "git": "arrow.triangle.branch",
        "gh": "chevron.left.forwardslash.chevron.right",
        "wget": "arrow.down.circle",
        "jq": "curlybraces",
        "yq": "doc.text",
        "tree": "list.bullet.indent",
        "tlrc": "questionmark.circle",
        "sevenzip": "archivebox",
        "mas": "app.badge",
        "coreutils": "wrench.and.screwdriver",
        "ripgrep": "magnifyingglass",
        "fd": "folder.badge.questionmark",
        "fzf": "line.3.horizontal.decrease.circle",
        "bat": "doc.plaintext",
        "eza": "list.bullet.rectangle",
        "zoxide": "arrow.uturn.right.circle",
        "git-delta": "plusminus",
        "lazygit": "point.3.connected.trianglepath.dotted",
        "httpie": "network",
        "starship": "sparkles",
        "tmux": "rectangle.split.3x1",
        "neovim": "pencil.and.outline",
        "fastfetch": "info.circle",
        "onefetch": "info.square",
        "htop": "list.number",
        "btop": "chart.bar.fill",
        "ncdu": "internaldrive",
        "dust": "chart.pie",
        "hyperfine": "timer",
        "node": "hexagon",
        "uv": "shippingbox",
        "go": "hare",
        "rustup": "gearshape.2",
        "shellcheck": "checkmark.shield",
        "gnupg": "key",
        "nmap": "dot.radiowaves.left.and.right",
        "brave-browser": "shield.lefthalf.filled",
        "arc": "globe",
        "firefox": "flame",
        "google-chrome": "globe.europe.africa",
        "claude-code": "sparkle",
        "visual-studio-code": "chevron.left.forwardslash.chevron.right",
        "sublime-text": "doc.text.fill",
        "zed": "bolt.horizontal",
        "ghostty": "terminal.fill",
        "iterm2": "apple.terminal",
        "orbstack": "circle.hexagongrid",
        "docker-desktop": "shippingbox.fill",
        "bruno": "paperplane",
        "jetbrains-toolbox": "hammer",
        "db-browser-for-sqlite": "cylinder.split.1x2",
        "wireshark-app": "waveform.path.ecg",
        "utm": "cpu",
        "raycast": "command",
        "rectangle": "rectangle.split.2x1",
        "alt-tab": "rectangle.on.rectangle",
        "maccy": "doc.on.clipboard",
        "shottr": "camera.viewfinder",
        "obsidian": "books.vertical",
        "jordanbaird-ice": "menubar.rectangle",
        "stats": "gauge.with.dots.needle.67percent",
        "monitorcontrol": "sun.max",
        "karabiner-elements": "keyboard",
        "linearmouse": "computermouse",
        "keka": "archivebox.fill",
        "the-unarchiver": "doc.zipper",
        "find-any-file": "doc.text.magnifyingglass",
        "grandperspective": "square.grid.3x3.square",
        "appcleaner": "trash",
        "balenaetcher": "externaldrive.fill",
        "qlmarkdown": "doc.richtext",
        "syntax-highlight": "highlighter",
        "iina": "play.rectangle.fill",
        "spotify": "music.note",
        "discord": "bubble.left.and.bubble.right.fill",
        "telegram": "paperplane.fill",
        "slack": "number",
        "switch": "waveform",
        "geekbench": "speedometer",
        "wine-stable": "wineglass",
    ]

    private static let tweakKeywords: [(String, String)] = [
        ("screencapture target", "doc.on.clipboard"),
        ("screencapture location", "folder.badge.plus"),
        ("disable-shadow", "shadow"),
        ("show-thumbnail", "photo"),
        ("ShowPathbar", "point.topleft.down.to.point.bottomright.curvepath"),
        ("ShowStatusBar", "menubar.rectangle"),
        ("AppleShowAllFiles", "eye"),
        ("AppleShowAllExtensions", "doc.badge.ellipsis"),
        ("PosixPath", "terminal"),
        ("SortFoldersFirstOnDesktop", "menubar.dock.rectangle"),
        ("SortFoldersFirst", "folder"),
        ("FXDefaultSearchScope", "magnifyingglass"),
        ("FXPreferredViewStyle", "rectangle.split.3x1"),
        ("NewWindowTarget", "house"),
        ("ExtensionChangeWarning", "exclamationmark.triangle"),
        ("ShowExternalHardDrives", "externaldrive"),
        ("ShowRemovableMedia", "sdcard"),
        ("ShowHardDrives", "internaldrive"),
        ("DSDontWriteNetwork", "network.slash"),
        ("DSDontWriteUSB", "externaldrive.badge.xmark"),
        ("chflags", "books.vertical"),
        ("autohide-delay", "timer"),
        ("autohide", "dock.arrow.down.rectangle"),
        ("show-recents", "clock.arrow.circlepath"),
        ("minimize-to-application", "arrow.down.right.and.arrow.up.left"),
        ("expose-group-apps", "rectangle.3.group"),
        ("mru-spaces", "square.stack.3d.up"),
        ("expose-animation", "hare"),
        ("spring-load", "arrow.up.bin"),
        ("ApplePressAndHold", "character.cursor.ibeam"),
        ("KeyRepeat", "repeat"),
        ("AppleKeyboardUIMode", "keyboard"),
        ("SpellingCorrection", "textformat.abc.dottedunderline"),
        ("QuoteSubstitution", "quote.opening"),
        ("Capitalization", "textformat.size"),
        ("PeriodSubstitution", "circle.fill"),
        ("Clicking", "hand.tap"),
        ("ThreeFingerDrag", "hand.draw"),
        ("NSNavPanel", "square.and.arrow.down.on.square"),
        ("PMPrinting", "printer"),
        ("SaveNewDocumentsToCloud", "icloud.slash"),
        ("ShowSeconds", "clock"),
        ("TimeMachine", "externaldrive.badge.timemachine"),
        ("ImageCapture", "photo.on.rectangle"),
        ("BrowseAllInterfaces", "wifi"),
        ("LSQuarantine", "lock.open"),
        ("Developer", "hammer"),
        ("hushlogin", "text.bubble"),
        ("FocusFollowsMouse", "cursorarrow.motionlines"),
        ("RichText", "doc.plaintext"),
        ("ActivityMonitor", "waveform.path.ecg"),
        ("DiskUtility", "internaldrive.fill"),
        ("defaultBranch", "arrow.triangle.branch"),
        ("autoSetupRemote", "arrow.up.circle"),
        ("excludesfile", "eye.slash"),
        ("setstealthmode", "eye.slash.circle"),
        ("displaysleep", "display"),
        ("pmset", "moon.zzz"),
        ("socketfilterfw", "flame"),
    ]

    static func tweak(for command: String) -> String {
        tweakKeywords.first { command.contains($0.0) }?.1 ?? "gearshape"
    }
}

struct CaskMetadata: Codable, Sendable {
    var apps: [String]
    var binaries: [String]
    var fetchedAt: Date
}

nonisolated enum BrewMetadata {
    private static let ttl: TimeInterval = 7 * 24 * 3600

    private static var cacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("MacPeach/casks.json")
    }

    static func casks(_ names: [String]) async -> [String: CaskMetadata] {
        var cache = loadCache()
        let now = Date()
        let missing = names.filter { name in
            guard let entry = cache[name] else { return true }
            return now.timeIntervalSince(entry.fetchedAt) > ttl
        }
        if !missing.isEmpty {
            let fetched = await fetchAll(missing)
            for (name, meta) in fetched { cache[name] = meta }
            saveCache(cache)
        }
        return cache
    }

    private static func fetchAll(_ names: [String]) async -> [String: CaskMetadata] {
        await withTaskGroup(of: (String, CaskMetadata?).self) { group in
            var result: [String: CaskMetadata] = [:]
            var iterator = names.makeIterator()
            let width = 8
            for _ in 0..<width {
                guard let name = iterator.next() else { break }
                group.addTask { (name, await fetch(name)) }
            }
            while let (name, meta) = await group.next() {
                if let meta { result[name] = meta }
                if let next = iterator.next() {
                    group.addTask { (next, await fetch(next)) }
                }
            }
            return result
        }
    }

    private static func fetch(_ name: String) async -> CaskMetadata? {
        guard ShParser.isSafePackageName(name),
              let url = URL(string: "https://formulae.brew.sh/api/cask/\(name).json") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            var apps: [String] = []
            var binaries: [String] = []
            for artifact in json["artifacts"] as? [[String: Any]] ?? [] {
                for entry in artifact["app"] as? [Any] ?? [] {
                    if let app = entry as? String { apps.append(app) }
                }
                for entry in artifact["binary"] as? [Any] ?? [] {
                    if let path = entry as? String { binaries.append((path as NSString).lastPathComponent) }
                }
            }
            return CaskMetadata(apps: apps, binaries: binaries, fetchedAt: Date())
        } catch {
            AppLog.shared.warning("Homebrew API request for \(name) failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func loadCache() -> [String: CaskMetadata] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: CaskMetadata].self, from: data)) ?? [:]
    }

    private static func saveCache(_ cache: [String: CaskMetadata]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cache) else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }
}

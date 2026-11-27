import Foundation
import Combine
import AppKit
@preconcurrency import UserNotifications

nonisolated enum Shell {
    static let searchPath = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

    static func brewPath() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func brewStatus() -> BrewStatus {
        guard let brew = brewPath() else { return .missing }
        let prefix = (brew as NSString).deletingLastPathComponent.replacingOccurrences(of: "/bin", with: "")
        guard let output = output(brew, ["--version"]),
              let first = output.split(separator: "\n").first else {
            return .installed(version: "?", prefix: prefix)
        }
        let version = first.replacingOccurrences(of: "Homebrew ", with: "").trimmingCharacters(in: .whitespaces)
        return .installed(version: version, prefix: prefix)
    }

    private static let passThrough = [
        "USER", "LOGNAME", "SHELL", "TMPDIR", "SSH_AUTH_SOCK", "__CF_USER_TEXT_ENCODING",
        "http_proxy", "https_proxy", "all_proxy", "no_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
    ]

    static func environment() -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]
        for key in passThrough {
            if let value = inherited[key] { env[key] = value }
        }
        env["PATH"] = searchPath
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        env["HOMEBREW_NO_COLOR"] = "1"
        env["NONINTERACTIVE"] = "1"
        env["LC_ALL"] = "en_US.UTF-8"
        return env
    }

    static func output(_ executable: String, _ arguments: [String], timeout: TimeInterval = 60) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            AppLog.shared.warning("Could not run \(executable): \(error.localizedDescription)")
            return nil
        }
        let deadline = DispatchTime.now() + timeout
        let group = DispatchGroup()
        group.enter()
        var data = Data()
        DispatchQueue.global(qos: .userInitiated).async {
            data = pipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        if group.wait(timeout: deadline) == .timedOut {
            process.terminate()
            AppLog.shared.warning("\(executable) \(arguments.joined(separator: " ")) timed out")
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func succeeds(_ script: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        process.environment = environment()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptString(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

enum RunState: Equatable {
    case idle, running, success, failed(String), cancelled

    var isFinished: Bool {
        switch self {
        case .success, .failed, .cancelled: return true
        default: return false
        }
    }
}

@MainActor
final class ScriptRunner: ObservableObject {
    @Published private(set) var output = ""
    @Published private(set) var state: RunState = .idle
    @Published private(set) var logURL: URL?

    private var process: Process?
    private var runDirectory: URL?
    private var logHandle: FileHandle?
    private var pending = ""
    private var lines: [Substring] = []
    private var flushScheduled = false
    private var startedAt = Date()
    private let maxLines = 2_000
    private static let ansi = try? NSRegularExpression(pattern: #"\u001B\[[0-9;?]*[ -/]*[@-~]|\r"#)

    func run(_ job: ScriptJob, lang: Lang) {
        guard state == .idle || state.isFinished else { return }
        let t = Loc(lang: lang)
        output = ""
        lines = []
        pending = ""

        if job.requiresBrew && Shell.brewPath() == nil {
            append(t("Homebrew nie jest zainstalowany. Zainstaluj go na karcie Homebrew w zakładce Aplikacje.\n",
                     "Homebrew is not installed. Install it from the Homebrew card on the Applications tab.\n"))
            flush()
            state = .failed(t("Brak Homebrew", "Homebrew is missing"))
            return
        }

        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("MacPeach-\(UUID().uuidString)", isDirectory: true)
        let scriptURL = directory.appendingPathComponent("script.sh")
        let askpassURL = directory.appendingPathComponent("askpass.sh")
        let logURL = AppLog.shared.newRunLogURL()
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try ScriptGenerator.wrap(job.script).write(to: scriptURL, atomically: true, encoding: .utf8)
            try ScriptGenerator.askpass(lang: lang).write(to: askpassURL, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: askpassURL.path)
            fm.createFile(atPath: logURL.path, contents: Data("# \(job.title)\n# \(Date())\n\n".utf8), attributes: [.posixPermissions: 0o600])
            logHandle = try FileHandle(forWritingTo: logURL)
            _ = try logHandle?.seekToEnd()
        } catch {
            try? fm.removeItem(at: directory)
            state = .failed(t("Nie można przygotować skryptu", "Could not prepare the script"))
            ErrorCenter.shared.report(error, context: t("Nie można przygotować skryptu „\(job.title)”.", "Could not prepare the script “\(job.title)”."))
            return
        }
        runDirectory = directory
        self.logURL = logURL

        var env = Shell.environment()
        env["SUDO_ASKPASS"] = askpassURL.path
        env["MACPEACH_RUN_DIR"] = directory.path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = fm.homeDirectoryForCurrentUser
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        weak let weakSelf = self
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in weakSelf?.receive(data: data, text: text) }
        }

        process.terminationHandler = { proc in
            let status = proc.terminationStatus
            let reason = proc.terminationReason
            Task { @MainActor in
                pipe.fileHandleForReading.readabilityHandler = nil
                if let rest = try? pipe.fileHandleForReading.readToEnd(), !rest.isEmpty {
                    weakSelf?.receive(data: rest, text: String(decoding: rest, as: UTF8.self))
                }
                weakSelf?.finish(status: status, reason: reason, job: job, lang: lang)
            }
        }

        do {
            startedAt = Date()
            try process.run()
            self.process = process
            state = .running
            AppLog.shared.info("Script started: \(job.title) (log: \(logURL.lastPathComponent))")
        } catch {
            cleanup()
            state = .failed(t("Nie można uruchomić skryptu", "Could not start the script"))
            ErrorCenter.shared.report(error, context: t("Nie można uruchomić „\(job.title)”.", "Could not start “\(job.title)”."))
        }
    }

    func cancel() {
        guard let process, process.isRunning else { return }
        state = .cancelled
        process.terminate()
        AppLog.shared.warning("Script cancelled by user")
    }

    private func receive(data: Data, text: String) {
        try? logHandle?.write(contentsOf: data)
        append(text)
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.flushScheduled = false
            self?.flush()
        }
    }

    private func append(_ text: String) {
        let cleaned: String
        if let regex = Self.ansi {
            cleaned = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        } else {
            cleaned = text
        }
        pending += cleaned
    }

    private func flush() {
        guard !pending.isEmpty else { return }
        let joined = (lines.last.map(String.init) ?? "") + pending
        if !lines.isEmpty { lines.removeLast() }
        lines.append(contentsOf: joined.split(separator: "\n", omittingEmptySubsequences: false))
        pending = ""
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
        output = lines.joined(separator: "\n")
    }

    private func finish(status: Int32, reason: Process.TerminationReason, job: ScriptJob, lang: Lang) {
        flush()
        let t = Loc(lang: lang)
        let seconds = Int(Date().timeIntervalSince(startedAt))
        if state == .cancelled {
            AppLog.shared.warning("Script \(job.title) cancelled after \(seconds) s")
        } else if status == 0 && reason == .exit {
            state = .success
            AppLog.shared.info("Script finished: \(job.title) in \(seconds) s")
            notify(title: t("Gotowe", "Done"), body: job.title)
        } else {
            let message = reason == .uncaughtSignal
                ? t("Skrypt został przerwany (sygnał \(status))", "Script was interrupted (signal \(status))")
                : t("Skrypt zakończył się kodem \(status)", "Script exited with code \(status)")
            state = .failed(message)
            AppLog.shared.error("Script failed: \(job.title), status \(status), log \(logURL?.path ?? "-")")
            notify(title: t("Błąd", "Failed"), body: "\(job.title): \(message)")
        }
        cleanup()
    }

    private func cleanup() {
        try? logHandle?.close()
        logHandle = nil
        if let runDirectory { try? FileManager.default.removeItem(at: runDirectory) }
        runDirectory = nil
        process = nil
    }

    private func notify(title: String, body: String) {
        guard !NSApp.isActive else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "MacPeach – \(title)"
            content.body = body
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

nonisolated enum ScriptGenerator {
    static func wrap(_ body: String) -> String {
        """
        #!/bin/bash
        set -uo pipefail
        sudo() { PATH=/usr/bin:/bin:/usr/sbin:/sbin /usr/bin/sudo -A "$@"; }
        for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
          if [ -x "$brew_bin" ]; then eval "$("$brew_bin" shellenv)"; break; fi
        done
        trap 'pkill -TERM -P $$ 2>/dev/null; exit 143' TERM INT

        \(body)
        """
    }

    static func askpass(lang: Lang) -> String {
        let t = Loc(lang: lang)
        let admin = Shell.appleScriptString(t("MacPeach potrzebuje hasła administratora, aby kontynuować.",
                                              "MacPeach needs your administrator password to continue."))
        let cancel = Shell.appleScriptString(t("Anuluj", "Cancel"))
        return """
        #!/bin/bash
        /usr/bin/osascript - "${1:-}" <<'APPLESCRIPT'
        on run argv
            set promptText to item 1 of argv
            if promptText is "" or promptText contains "assword" then set promptText to \(admin)
            activate
            set answer to display dialog promptText default answer "" with hidden answer with title "MacPeach" with icon caution buttons {\(cancel), "OK"} default button "OK" cancel button \(cancel)
            return text returned of answer
        end run
        APPLESCRIPT
        """
    }

    static func install(formulae: [InstallItem], casks: [InstallItem], lang: Lang) -> String {
        let t = Loc(lang: lang)
        var lines: [String] = ["failed=()", ""]
        func add(_ item: InstallItem) {
            guard ShParser.isSafePackageName(item.brewName) else { return }
            let name = Shell.quote(item.brewName)
            let flag = item.isCask ? "--cask " : ""
            lines.append("echo \(Shell.quote("==> " + t("Instaluję", "Installing") + " " + item.name))")
            lines.append("brew install \(flag)\(name) || failed+=(\(name))")
            lines.append("")
        }
        if !formulae.isEmpty || !casks.isEmpty {
            lines.append("brew update || true")
            lines.append("")
        }
        formulae.forEach(add)
        casks.forEach(add)
        if casks.contains(where: { ["qlmarkdown", "syntax-highlight"].contains($0.brewName) }) {
            lines.append("qlmanage -r >/dev/null 2>&1 || true")
            lines.append("")
        }
        lines.append("""
        if [ ${#failed[@]} -gt 0 ]; then
          echo
          echo \(Shell.quote(t("Nie udało się zainstalować:", "Could not install:"))) "${failed[*]}"
          exit 1
        fi
        echo
        echo \(Shell.quote(t("Wszystkie wybrane pakiety są zainstalowane.", "All selected packages are installed.")))
        """)
        return lines.joined(separator: "\n")
    }

    static func tweaks(_ tweaks: [TweakItem], lang: Lang) -> String {
        let t = Loc(lang: lang)
        var lines: [String] = ["failed=()", ""]
        for tweak in tweaks {
            let name = t(tweak.title) + (tweak.isChoice ? ": " + (tweak.label(for: tweak.selectedValue ?? tweak.defaultValue).map { t($0) } ?? "") : "")
            let title = Shell.quote(name)
            lines.append("echo \(Shell.quote("==> " + name))")
            let chain = tweak.resolvedCommands.map { "{ \($0); }" }.joined(separator: " && \\\n   ")
            lines.append("if ! { \(chain); }; then")
            lines.append("  failed+=(\(title)); echo \(Shell.quote("    " + t("nie powiodło się", "failed")))")
            lines.append("fi")
            lines.append("")
        }
        lines.append("killall Dock Finder SystemUIServer cfprefsd 2>/dev/null || true")
        lines.append("""
        echo
        echo \(Shell.quote(t("Niektóre ustawienia (klawiatura, gładzik) zadziałają po ponownym zalogowaniu.",
                              "Some settings (keyboard, trackpad) take effect after logging out and back in.")))
        if [ ${#failed[@]} -gt 0 ]; then
          echo \(Shell.quote(t("Nie udało się zastosować:", "Could not apply:")))
          printf '  - %s\\n' "${failed[@]}"
          exit 1
        fi
        echo \(Shell.quote(t("Konfiguracja zakończona.", "Configuration finished.")))
        """)
        return lines.joined(separator: "\n")
    }

    static let homebrewTeamID = "927JGANW46"

    static func installHomebrew(lang: Lang) -> String {
        let t = Loc(lang: lang)
        func q(_ pl: String, _ en: String) -> String { Shell.quote(t(pl, en)) }
        return """
        set -e
        PKG="$MACPEACH_RUN_DIR/Homebrew.pkg"
        echo \(q("Pobieram podpisany instalator Homebrew (.pkg, ok. 150 MB) z GitHub Releases…",
                  "Downloading the signed Homebrew installer (.pkg, about 150 MB) from GitHub Releases…"))
        /usr/bin/curl -fsSL --proto '=https' --tlsv1.2 -o "$PKG" https://github.com/Homebrew/brew/releases/latest/download/Homebrew.pkg
        SIG="$(/usr/sbin/pkgutil --check-signature "$PKG" 2>&1 || true)"
        echo "$SIG"
        if ! echo "$SIG" | /usr/bin/grep -q 'Status: signed by a developer certificate issued by Apple for distribution' || \
           ! echo "$SIG" | /usr/bin/grep -qE '^ *1\\. Developer ID Installer: .*\\(\(homebrewTeamID)\\)$'; then
          echo \(q("Podpis instalatora nie należy do Homebrew (\(homebrewTeamID)). Przerywam.",
                    "The installer is not signed by Homebrew (\(homebrewTeamID)). Aborting."))
          exit 1
        fi
        if ! /usr/sbin/spctl --assess --type install "$PKG"; then
          echo \(q("Gatekeeper odrzucił instalator (brak notaryzacji). Przerywam.", "Gatekeeper rejected the installer (not notarized). Aborting."))
          exit 1
        fi
        sudo /usr/sbin/installer -pkg "$PKG" -target /
        rm -f "$PKG"
        if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
          echo \(q("Homebrew potrzebuje Command Line Tools. Otwieram instalator Apple – po jego zakończeniu Homebrew jest gotowy.",
                    "Homebrew needs the Command Line Tools. Opening Apple's installer – Homebrew is ready once it finishes."))
          /usr/bin/xcode-select --install || true
        fi
        """
    }

    static func maintenance() -> String {
        """
        brew update
        brew upgrade
        brew upgrade --cask --greedy-auto-updates || true
        brew cleanup --prune=30
        brew doctor || true
        """
    }
}

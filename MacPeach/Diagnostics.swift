import Foundation
import Darwin
import Combine

nonisolated final class AppLog: @unchecked Sendable {
    static let shared = AppLog()

    enum Level: String {
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    let directory: URL
    let fileURL: URL
    let runsDirectory: URL

    private let queue = DispatchQueue(label: "MacPeach.log", qos: .utility)
    private let formatter: DateFormatter
    private let maxSize = 2 * 1024 * 1024
    private let keptRuns = 30

    private init() {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        directory = library.appendingPathComponent("Logs/MacPeach", isDirectory: true)
        fileURL = directory.appendingPathComponent("MacPeach.log")
        runsDirectory = directory.appendingPathComponent("Runs", isDirectory: true)
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        try? FileManager.default.createDirectory(at: runsDirectory, withIntermediateDirectories: true)
    }

    func info(_ message: String) { write(.info, message) }
    func warning(_ message: String) { write(.warning, message) }
    func error(_ message: String) { write(.error, message) }

    func write(_ level: Level, _ message: String) {
        let stamp = formatter.string(from: Date())
        let line = "\(stamp) [\(level.rawValue)] \(message)\n"
        queue.async { [self] in
            rotateIfNeeded()
            append(Data(line.utf8))
        }
    }

    func flush() {
        queue.sync {}
    }

    func tail(lines count: Int) -> String {
        flush()
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return "" }
        return text.split(separator: "\n", omittingEmptySubsequences: false).suffix(count).joined(separator: "\n")
    }

    func newRunLogURL() -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        pruneRuns()
        return runsDirectory.appendingPathComponent("run_\(f.string(from: Date())).log")
    }

    func clear() {
        queue.sync {
            let fm = FileManager.default
            try? fm.removeItem(at: runsDirectory)
            try? fm.createDirectory(at: runsDirectory, withIntermediateDirectories: true)
            if let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                for file in files where file.lastPathComponent.hasPrefix("Crash-") || file.lastPathComponent.hasPrefix("MacPeach.log.") {
                    try? fm.removeItem(at: file)
                }
            }
            try? Data().write(to: fileURL)
        }
    }

    func totalSize() -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    private func append(_ data: Data) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }

    private func rotateIfNeeded() {
        let fm = FileManager.default
        guard let size = (try? fm.attributesOfItem(atPath: fileURL.path)[.size]) as? Int, size > maxSize else { return }
        let rotated = directory.appendingPathComponent("MacPeach.log.1")
        try? fm.removeItem(at: rotated)
        try? fm.moveItem(at: fileURL, to: rotated)
    }

    private func pruneRuns() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: runsDirectory, includingPropertiesForKeys: nil) else { return }
        let sorted = files.filter { $0.pathExtension == "log" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for file in sorted.dropFirst(keptRuns - 1) {
            try? fm.removeItem(at: file)
        }
    }
}

nonisolated(unsafe) private var crashDescriptor: Int32 = -1
nonisolated(unsafe) private var crashSignalMessages: [Int32: [UInt8]] = [:]

nonisolated private func writeCrashBytes(_ bytes: [UInt8]) {
    guard crashDescriptor >= 0 else { return }
    bytes.withUnsafeBufferPointer { buffer in
        _ = Darwin.write(crashDescriptor, buffer.baseAddress, buffer.count)
    }
}

nonisolated private func crashSignalHandler(_ signal: Int32) {
    if let message = crashSignalMessages[signal] {
        writeCrashBytes(message)
    }
    if crashDescriptor >= 0 {
        withUnsafeTemporaryAllocation(of: UnsafeMutableRawPointer?.self, capacity: 128) { frames in
            let count = backtrace(frames.baseAddress, 128)
            backtrace_symbols_fd(frames.baseAddress, count, crashDescriptor)
        }
        fsync(crashDescriptor)
    }
    Darwin.signal(signal, SIG_DFL)
    raise(signal)
}

nonisolated enum CrashReporter {
    struct PreviousSession {
        let crashed: Bool
        let details: String
        let archivedURL: URL?
    }

    static var crashFileURL: URL { AppLog.shared.directory.appendingPathComponent("LastCrash.log") }
    private static var sessionMarkerURL: URL { AppLog.shared.directory.appendingPathComponent(".session") }

    static func start() -> PreviousSession? {
        let fm = FileManager.default
        let log = AppLog.shared
        let hadMarker = fm.fileExists(atPath: sessionMarkerURL.path)
        let crashText = (try? String(contentsOf: crashFileURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var previous: PreviousSession?
        if hadMarker || !crashText.isEmpty {
            let modified = (try? fm.attributesOfItem(atPath: crashFileURL.path)[.modificationDate]) as? Date
            var details = ""
            if crashText.isEmpty {
                details = "No crash signal was captured. The previous session ended without a clean exit (force quit, hang, logout or power loss)."
            } else {
                if let modified { details += "Time: \(modified)\n" }
                details += crashText
            }
            let recent = log.tail(lines: 30)
            if !recent.isEmpty {
                details += "\n\n--- Last log entries ---\n" + recent
            }
            var archived: URL?
            if !crashText.isEmpty {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let target = log.directory.appendingPathComponent("Crash-\(f.string(from: modified ?? Date())).log")
                try? details.write(to: target, atomically: true, encoding: .utf8)
                archived = target
            }
            previous = PreviousSession(crashed: !crashText.isEmpty, details: details, archivedURL: archived)
            log.error("Previous session ended unexpectedly. \(crashText.isEmpty ? "No signal captured." : crashText.components(separatedBy: "\n").first ?? "")")
        }

        fm.createFile(atPath: sessionMarkerURL.path, contents: Data(), attributes: nil)
        install()
        log.info("MacPeach \(AppInfo.version) started on macOS \(ProcessInfo.processInfo.operatingSystemVersionString), \(AppInfo.architecture)")
        return previous
    }

    static func markCleanExit() {
        AppLog.shared.info("MacPeach closed normally")
        AppLog.shared.flush()
        if crashDescriptor >= 0 {
            close(crashDescriptor)
            crashDescriptor = -1
        }
        try? FileManager.default.removeItem(at: crashFileURL)
        try? FileManager.default.removeItem(at: sessionMarkerURL)
    }

    private static func install() {
        crashDescriptor = open(crashFileURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
        let names: [Int32: String] = [
            SIGABRT: "SIGABRT (abort)",
            SIGSEGV: "SIGSEGV (invalid memory access)",
            SIGBUS: "SIGBUS (bus error)",
            SIGILL: "SIGILL (illegal instruction / Swift runtime trap)",
            SIGTRAP: "SIGTRAP (Swift runtime trap)",
            SIGFPE: "SIGFPE (arithmetic error)",
        ]
        for (signal, name) in names {
            crashSignalMessages[signal] = Array("MacPeach crashed: \(name)\nVersion: \(AppInfo.version) \(AppInfo.architecture)\n\nBacktrace:\n".utf8)
            Darwin.signal(signal, crashSignalHandler)
        }
        NSSetUncaughtExceptionHandler { exception in
            var text = "MacPeach crashed: uncaught exception \(exception.name.rawValue)\n"
            text += "Reason: \(exception.reason ?? "-")\nVersion: \(AppInfo.version) \(AppInfo.architecture)\n\nBacktrace:\n"
            text += exception.callStackSymbols.joined(separator: "\n") + "\n"
            writeCrashBytes(Array(text.utf8))
        }
    }
}

nonisolated final class HangWatchdog: @unchecked Sendable {
    static let shared = HangWatchdog()

    private let lock = NSLock()
    private var lastBeat = Date()
    private var hangStarted: Date?
    private var started = false
    private let threshold: TimeInterval = 4
    var onRecovered: (@Sendable (TimeInterval) -> Void)?

    func start() {
        lock.lock()
        guard !started else { lock.unlock(); return }
        started = true
        lock.unlock()

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.beat() }
        RunLoop.main.add(timer, forMode: .common)

        let thread = Thread { [weak self] in
            while true {
                Thread.sleep(forTimeInterval: 1)
                self?.check()
            }
        }
        thread.name = "MacPeach.watchdog"
        thread.qualityOfService = .utility
        thread.start()
    }

    private func beat() {
        lock.lock()
        lastBeat = Date()
        let started = hangStarted
        hangStarted = nil
        lock.unlock()
        if let started {
            let duration = Date().timeIntervalSince(started) + threshold
            AppLog.shared.warning(String(format: "Interface was unresponsive for about %.1f s", duration))
            onRecovered?(duration)
        }
    }

    private func check() {
        lock.lock()
        let elapsed = Date().timeIntervalSince(lastBeat)
        var report = false
        if elapsed > threshold && hangStarted == nil {
            hangStarted = Date()
            report = true
        }
        lock.unlock()
        if report {
            AppLog.shared.warning(String(format: "Main thread blocked for over %.0f s", threshold))
        }
    }
}

struct AppIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let details: String
    let fileURL: URL?
}

@MainActor
final class ErrorCenter: ObservableObject {
    static let shared = ErrorCenter()

    @Published var issue: AppIssue?

    func report(title: String, message: String, details: String = "", fileURL: URL? = nil) {
        let summary = details.split(separator: "\n").first.map { " | \($0.prefix(300))" } ?? ""
        AppLog.shared.error("\(title): \(message)\(summary)")
        guard issue == nil else { return }
        issue = AppIssue(title: title, message: message, details: details, fileURL: fileURL)
    }

    func report(_ error: Error, context: String) {
        let t = Loc(lang: Lang.current)
        let nsError = error as NSError
        report(
            title: t("Wystąpił błąd", "Something went wrong"),
            message: context,
            details: "\(nsError.localizedDescription)\n\(nsError.domain) (\(nsError.code))"
        )
    }
}

nonisolated enum AppInfo {
    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return "v\(short)"
    }

    static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return isTranslated ? "x86_64 (Rosetta)" : "x86_64"
        #endif
    }

    static var isTranslated: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("sysctl.proc_translated", &value, &size, nil, 0) == 0 && value == 1
    }
}

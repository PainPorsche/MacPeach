import SwiftUI
import AppKit

@main
struct MacPeachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()
    @AppStorage(SettingsKey.language) private var language = Lang.systemDefault.rawValue
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue

    private var loc: Loc { Loc(lang: Lang(rawValue: language) ?? .en) }

    var body: some Scene {
        Window("MacPeach", id: "main") {
            ContentView()
                .environmentObject(store)
                .environment(\.loc, loc)
                .onAppear { AppearanceMode.apply(AppearanceMode(rawValue: appearance) ?? .system) }
                .onChange(of: appearance) { _, value in AppearanceMode.apply(AppearanceMode(rawValue: value) ?? .system) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1120, height: 820)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(loc("O programie MacPeach", "About MacPeach")) { AboutText.showAlert() }
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .sidebar) {
                Picker(loc("Język", "Language"), selection: $language) {
                    ForEach(Lang.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Picker(loc("Wygląd", "Appearance"), selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label(loc)).tag($0.rawValue) }
                }
                Divider()
            }
            CommandGroup(replacing: .help) {
                Button(loc("Pokaż logi", "Show Logs")) {
                    NSWorkspace.shared.activateFileViewerSelecting([AppLog.shared.fileURL])
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminationSource: DispatchSourceSignal?
    private var appearanceObservation: NSKeyValueObservation?

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppearanceMode.apply(AppearanceMode.current)
        updateDockIcon()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            Task { @MainActor in AppDelegate.updateDockIcon() }
        }
    }

    private func updateDockIcon() {
        AppDelegate.updateDockIcon()
    }

    private static func updateDockIcon() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        NSApp.applicationIconImage = isDark ? NSImage(named: "AppIconDark") : nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            AppLog.shared.info("SIGTERM received, closing")
            CrashReporter.markCleanExit()
            exit(0)
        }
        source.resume()
        terminationSource = source
        AppearanceMode.apply(AppearanceMode.current)
        let previous = CrashReporter.start()
        HangWatchdog.shared.onRecovered = { duration in
            guard duration >= 8 else { return }
            Task { @MainActor in
                let t = Loc(lang: Lang.current)
                ErrorCenter.shared.report(
                    title: t("MacPeach przestał odpowiadać", "MacPeach stopped responding"),
                    message: t(String(format: "Interfejs był zablokowany przez około %.0f s. Informację zapisano w logu.", duration),
                               String(format: "The interface was blocked for about %.0f s. This was recorded in the log.", duration))
                )
            }
        }
        HangWatchdog.shared.start()
        if let previous {
            let t = Loc(lang: Lang.current)
            ErrorCenter.shared.report(
                title: previous.crashed
                    ? t("MacPeach został nieoczekiwanie zamknięty", "MacPeach quit unexpectedly")
                    : t("Poprzednia sesja nie zakończyła się poprawnie", "The previous session did not end cleanly"),
                message: t("Poniżej jest raport z poprzedniego uruchomienia. Zapisano go również w folderze logów.",
                           "Below is the report from the previous run. It was also saved in the log folder."),
                details: previous.details,
                fileURL: previous.archivedURL
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        CrashReporter.markCleanExit()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

import SwiftUI
import AppKit

enum AboutText {
    static func description(_ t: Loc) -> String {
        t("Konfiguruje nowego Maca w kilka minut: instaluje aplikacje i narzędzia z Homebrew, ustawia macOS pod pracę programisty i dodaje to, czego w systemie brakuje.",
          "Sets up a new Mac in minutes: installs apps and tools with Homebrew, tunes macOS for development work and adds what the system is missing.")
    }

    static let author = "PainPorsche"

    static func body(_ t: Loc) -> String {
        description(t) + String(repeating: "\n", count: 7) + author
    }

    @MainActor
    static func showAlert() {
        let t = Loc(lang: Lang.current)
        let alert = NSAlert()
        alert.messageText = "MacPeach \(AppInfo.version)"
        alert.informativeText = body(t)
        if let icon = NSApp.applicationIconImage { alert.icon = icon }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKey.language) private var language = Lang.systemDefault.rawValue

    var body: some View {
        let t = Loc(lang: Lang(rawValue: language) ?? .en)
        TabView {
            GeneralSettings()
                .tabItem { Label(t("Ogólne", "General"), systemImage: "gearshape") }
            DiagnosticsSettings()
                .tabItem { Label(t("Diagnostyka", "Diagnostics"), systemImage: "stethoscope") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .environment(\.loc, t)
        .tint(Palette.light.accent)
        .frame(width: 500)
    }
}

private struct GeneralSettings: View {
    @AppStorage(SettingsKey.language) private var language = Lang.systemDefault.rawValue
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue
    @Environment(\.loc) private var t
    @EnvironmentObject private var store: AppStore
    @State private var custom = CatalogSource.usesCustomFile

    var body: some View {
        Form {
            Section {
                Picker(t("Język", "Language"), selection: $language) {
                    ForEach(Lang.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Picker(t("Wygląd", "Appearance"), selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label(t)).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                LabeledContent(t("Źródło", "Source")) {
                    Text(custom ? CatalogSource.customURL.path.abbreviatingHome : t("Wbudowany MacSetup.sh", "Built-in MacSetup.sh"))
                        .font(.system(size: 12, design: custom ? .monospaced : .default))
                        .textSelection(.enabled)
                }
                HStack {
                    Button(custom ? t("Otwórz plik", "Open file") : t("Utwórz własną kopię…", "Create editable copy…")) {
                        do {
                            let url = try CatalogSource.createCustomCopy()
                            custom = true
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                            store.reloadCatalog()
                        } catch {
                            ErrorCenter.shared.report(error, context: t("Nie udało się utworzyć kopii MacSetup.sh.", "Could not create a copy of MacSetup.sh."))
                        }
                    }
                    Button(t("Wczytaj ponownie", "Reload")) {
                        custom = CatalogSource.usesCustomFile
                        store.reloadCatalog()
                    }
                    if custom {
                        Spacer()
                        Button(t("Przywróć wbudowany", "Use built-in"), role: .destructive) {
                            try? FileManager.default.trashItem(at: CatalogSource.customURL, resultingItemURL: nil)
                            custom = CatalogSource.usesCustomFile
                            store.reloadCatalog()
                        }
                    }
                }
            } header: {
                Text(t("Lista pakietów i ustawień", "Package and settings list"))
            } footer: {
                Text(t("Własny plik ~/.config/macpeach/MacSetup.sh zastępuje wbudowaną listę. Komentarz „# English | Polski” nad poleceniem to jego opis.",
                       "A custom ~/.config/macpeach/MacSetup.sh replaces the built-in list. A “# English | Polski” comment above a command becomes its description."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 330)
    }
}

private struct DiagnosticsSettings: View {
    @Environment(\.loc) private var t
    @State private var size = AppLog.shared.totalSize()
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section {
                LabeledContent(t("Folder logów", "Log folder")) {
                    Text(AppLog.shared.directory.path.abbreviatingHome)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                }
                LabeledContent(t("Rozmiar", "Size"), value: ByteFormat.file(size))
                HStack {
                    Button(t("Pokaż w Finderze", "Show in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([AppLog.shared.fileURL])
                    }
                    Button(t("Otwórz w Konsoli", "Open in Console")) {
                        AppLog.shared.flush()
                        NSWorkspace.shared.open([AppLog.shared.fileURL],
                                                withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"),
                                                configuration: NSWorkspace.OpenConfiguration())
                    }
                    Spacer()
                    Button(t("Wyczyść…", "Clear…"), role: .destructive) { confirmClear = true }
                }
            } footer: {
                Text(t("MacPeach zapisuje tu przebieg każdego skryptu, błędy oraz informacje o awariach i zawieszeniach. Po nieoczekiwanym zamknięciu raport pojawi się przy następnym uruchomieniu. Nic nie jest nigdzie wysyłane.",
                       "MacPeach keeps the output of every script, errors and crash or hang reports here. After an unexpected quit the report is shown on next launch. Nothing is sent anywhere."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 230)
        .onAppear { size = AppLog.shared.totalSize() }
        .confirmationDialog(t("Usunąć wszystkie logi?", "Delete all logs?"), isPresented: $confirmClear) {
            Button(t("Usuń", "Delete"), role: .destructive) {
                AppLog.shared.clear()
                size = AppLog.shared.totalSize()
            }
        }
    }
}

private struct AboutSettings: View {
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            VStack(spacing: 10) {
                LogoMark(width: 64)
                    .padding(.top, 8)
                Text("MacPeach \(AppInfo.version)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(p.text)
                Text(AboutText.body(t))
                    .font(.system(size: 13))
                    .foregroundStyle(p.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
    }
}

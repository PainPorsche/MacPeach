import SwiftUI
import AppKit

private struct ActionBar: View {
    let tab: Tab
    @EnvironmentObject private var store: AppStore
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            if let config {
                HStack(spacing: 14) {
                    Text(config.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(p.accent)
                        .contentTransition(.numericText())
                    Spacer(minLength: 12)
                    Button(t("Wyczyść", "Clear"), action: config.clear)
                        .buttonStyle(PeachButtonStyle(kind: .quiet))
                    Button(action: config.run) {
                        Label(config.action, systemImage: "play.fill")
                    }
                    .buttonStyle(PeachButtonStyle(kind: .primary))
                    .disabled(config.disabled)
                    .help(config.disabled ? t("Najpierw zainstaluj Homebrew", "Install Homebrew first") : "")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.bubble.opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(p.accent.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(p.shadow * 2), radius: 14, y: 6)
                .padding(.horizontal, 36)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private struct Config {
        let label: String
        let action: String
        let disabled: Bool
        let run: () -> Void
        let clear: () -> Void
    }

    private var config: Config? {
        switch tab {
        case .install:
            let count = store.selectedInstallCount
            guard count > 0 else { return nil }
            return Config(
                label: t("Zaznaczono: \(count)", "\(count) selected"),
                action: t("Zainstaluj zaznaczone", "Install selected"),
                disabled: store.brew == .missing,
                run: {
                    store.run(ScriptJob(
                        kind: .install,
                        title: t("Instalacja pakietów (\(count))", "Install packages (\(count))"),
                        script: ScriptGenerator.install(formulae: store.selectedFormulae, casks: store.selectedCasks, lang: t.lang),
                        requiresBrew: true))
                },
                clear: { store.clearInstallSelection() }
            )
        case .sysconfig:
            let count = store.selectedTweaks.count
            guard count > 0 else { return nil }
            return Config(
                label: t("Zaznaczono: \(count)", "\(count) selected"),
                action: t("Zastosuj ustawienia", "Apply settings"),
                disabled: false,
                run: {
                    store.run(ScriptJob(
                        kind: .tweaks,
                        title: t("Konfiguracja systemu (\(count))", "Apply settings (\(count))"),
                        script: ScriptGenerator.tweaks(store.selectedTweaks, lang: t.lang),
                        requiresBrew: false))
                },
                clear: { store.clearTweakSelection() }
            )
        default:
            return nil
        }
    }
}

private struct TopBar: View {
    @AppStorage(SettingsKey.language) private var language = Lang.systemDefault.rawValue
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var t

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            SegmentedPill(options: Lang.allCases.map { .init(value: $0.rawValue, title: $0.rawValue.uppercased()) },
                          selection: $language, height: 32)
            ToolbarIconButton(icon: scheme == .dark ? "sun.max.fill" : "moon.fill",
                              help: scheme == .dark ? t("Tryb jasny", "Light mode") : t("Tryb ciemny", "Dark mode")) {
                appearance = (scheme == .dark ? AppearanceMode.light : .dark).rawValue
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }
}

private struct MainPanel: View {
    let tab: Tab
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.resolve(scheme)
        VStack(spacing: 0) {
            TopBar()
            ScrollView {
                Group {
                    switch tab {
                    case .install: InstallView()
                    case .sysconfig: SystemConfigView()
                    case .extras: ExtrasView()
                    case .presets: PresetView()
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 8)
                .padding(.bottom, 110)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(tab)
            .scrollIndicators(.automatic)
        }
        .overlay(alignment: .bottom) {
            ActionBar(tab: tab)
        }
        .background(p.canvas)
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var errors = ErrorCenter.shared
    @AppStorage(SettingsKey.selectedTab) private var tabRaw = Tab.install.rawValue
    @Environment(\.loc) private var t

    private var tab: Binding<Tab> {
        Binding(get: { Tab(rawValue: tabRaw) ?? .install }, set: { tabRaw = $0.rawValue })
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedTab: tab)
            MainPanel(tab: tab.wrappedValue)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 1000, minHeight: 780)
        .animation(.easeOut(duration: 0.2), value: store.selectedInstallCount)
        .animation(.easeOut(duration: 0.2), value: store.selectedTweaks.count)
        .sheet(item: $store.activeJob) { job in
            ScriptSheet(job: job) { success in
                store.finished(job, success: success)
            }
            .environment(\.loc, t)
        }
        .sheet(item: $errors.issue) { issue in
            IssueSheet(issue: issue)
                .environment(\.loc, t)
        }
    }
}

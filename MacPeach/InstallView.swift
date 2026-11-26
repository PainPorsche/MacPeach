import SwiftUI

private struct HomebrewCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            HStack(spacing: 14) {
                IconBubble(icon: "mug.fill")
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Homebrew")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(p.text)
                        status(p)
                    }
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(p.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                actions
            }
            .padding(16)
            .card()
        }
    }

    @ViewBuilder
    private func status(_ p: Palette) -> some View {
        switch store.brew {
        case .checking:
            ProgressView().controlSize(.mini)
        case .missing:
            Badge(text: t("Nie zainstalowano", "Not installed"), icon: "exclamationmark", tone: .warning)
        case .installed(let version, _):
            Badge(text: version, icon: "checkmark", tone: .success)
        }
    }

    private var detail: String {
        switch store.brew {
        case .checking:
            return t("Sprawdzam instalację…", "Checking installation…")
        case .missing:
            return t("Menedżer pakietów wymagany do instalacji aplikacji i narzędzi.", "Package manager required to install apps and tools.")
        case .installed(_, let prefix):
            return t("Zainstalowano w \(prefix) · menedżer pakietów macOS", "Installed in \(prefix) · the macOS package manager")
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch store.brew {
        case .checking:
            EmptyView()
        case .missing:
            Button {
                store.run(ScriptJob(kind: .homebrew, title: t("Instalacja Homebrew", "Install Homebrew"),
                                    script: ScriptGenerator.installHomebrew(lang: t.lang), requiresBrew: false))
            } label: {
                Label(t("Zainstaluj Homebrew", "Install Homebrew"), systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(PeachButtonStyle(kind: .primary, compact: true))
        case .installed:
            HStack(spacing: 8) {
                Button {
                    store.run(ScriptJob(kind: .maintenance, title: t("Aktualizacja pakietów", "Update packages"),
                                        script: ScriptGenerator.maintenance(), requiresBrew: true))
                } label: {
                    Label(t("Aktualizuj wszystko", "Update all"), systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(PeachButtonStyle(kind: .secondary, compact: true))
                .help("brew update && brew upgrade && brew cleanup")
                Button {
                    store.refreshBrew()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(PeachButtonStyle(kind: .quiet, compact: true))
                .help(t("Sprawdź ponownie", "Check again"))
            }
        }
    }
}

private struct InstallRow: View {
    @Binding var item: InstallItem
    @State private var hovering = false
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            HStack(spacing: 14) {
                CheckBox(isOn: item.isChecked)
                IconBubble(icon: item.icon, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(p.text)
                        .lineLimit(1)
                    Text(item.summary.map { t($0) } ?? item.brewName)
                        .font(.system(size: 12))
                        .foregroundStyle(p.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.brewName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(p.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .help(item.command)
                stateBadge
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.isChecked ? p.bubble.opacity(p.shadow > 0.1 ? 0.55 : 0.6) : (hovering ? p.card.opacity(0.85) : p.card))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(item.isChecked ? p.accent.opacity(0.25) : p.cardStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(p.shadow * 0.6), radius: 4, y: 2)
            .contentShape(Rectangle())
            .onTapGesture { item.isChecked.toggle() }
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: item.isChecked)
        }
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch item.state {
        case .viaBrew:
            Badge(text: t("Zainstalowano", "Installed"), icon: "checkmark", tone: .success)
                .help(t("Zainstalowano przez Homebrew", "Installed with Homebrew"))
        case .manual:
            Badge(text: t("Zainstalowano ręcznie", "Installed manually"), icon: "checkmark", tone: .success)
                .help(t("Aplikacja jest w systemie, ale nie zarządza nią Homebrew", "The app is present but not managed by Homebrew"))
        default:
            EmptyView()
        }
    }
}

struct InstallView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.loc) private var t
    @State private var group: InstallGroup = .apps
    @State private var query = ""

    private var items: [InstallItem] { group == .apps ? store.casks : store.formulae }

    private var categories: [BiText] {
        var seen = Set<BiText>()
        return items.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            TabHeader(plain: t("Instalacja", "Install"), accent: t("aplikacji", "Essentials"),
                      subtitle: t("Zaznacz programy i narzędzia, a MacPeach zainstaluje je przez Homebrew.",
                                  "Pick apps and tools and MacPeach installs them with Homebrew."))
            HomebrewCard()
            summaryCard
            toolbar
            let visible = filtered
            if visible.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: t("Brak wyników", "No results"),
                               message: t("Żadna pozycja nie pasuje do „\(query)”.", "Nothing matches “\(query)”."))
                    .card()
            } else {
                ForEach(categories, id: \.self) { category in
                    let indices = visible.filter { items[$0].category == category }
                    if !indices.isEmpty {
                        section(category: category, indices: indices)
                    }
                }
            }
        }
    }

    private var filtered: [Int] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return items.indices.filter { i in
            guard !q.isEmpty else { return true }
            let item = items[i]
            return item.name.lowercased().contains(q)
                || item.brewName.lowercased().contains(q)
                || (item.summary.map { t($0).lowercased().contains(q) } ?? false)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            SegmentedPill(options: [
                .init(value: InstallGroup.apps, title: t("Aplikacje", "Applications"), count: store.casks.count),
                .init(value: InstallGroup.tools, title: t("Narzędzia CLI", "CLI Tools"), count: store.formulae.count),
            ], selection: $group, height: 34)
            SearchField(text: $query, prompt: t("Szukaj…", "Search…"))
        }
    }

    private var summaryCard: some View {
        Themed { p in
            let all = store.casks + store.formulae
            let installed = all.filter { $0.state.isInstalled }.count
            HStack(spacing: 14) {
                IconBubble(icon: "checklist.checked")
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Zainstalowane na tym Macu: \(installed) z \(all.count)", "Installed on this Mac: \(installed) of \(all.count)"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(p.text)
                        .contentTransition(.numericText())
                    Text(t("MacPeach sprawdza, co już masz – przez Homebrew i w folderze Aplikacje – i oznacza to na liście.",
                           "MacPeach checks what you already have – via Homebrew and in the Applications folder – and marks it in the list."))
                        .font(.system(size: 12))
                        .foregroundStyle(p.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button {
                    store.scanInstalled()
                } label: {
                    HStack(spacing: 6) {
                        if store.isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(t("Odśwież", "Refresh"))
                    }
                }
                .buttonStyle(PeachButtonStyle(kind: .secondary, compact: true))
                .disabled(store.isScanning)
            }
            .padding(16)
            .card()
        }
    }

    private func section(category: BiText, indices: [Int]) -> some View {
        let selected = indices.filter { items[$0].isChecked }.count
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: t(category)) {
                SelectAllControl(selected: selected, total: indices.count) { value in
                    for i in indices { binding(i).wrappedValue.isChecked = value }
                }
            }
            LazyVStack(spacing: 6) {
                ForEach(indices.map { (index: $0, id: items[$0].id) }, id: \.id) { entry in
                    InstallRow(item: binding(entry.index))
                }
            }
        }
    }

    private func binding(_ index: Int) -> Binding<InstallItem> {
        group == .apps ? $store.casks[index] : $store.formulae[index]
    }
}

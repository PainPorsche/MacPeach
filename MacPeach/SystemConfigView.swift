import SwiftUI

private struct TweakRow: View {
    @Binding var item: TweakItem
    @State private var hovering = false
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            HStack(spacing: 14) {
                CheckBox(isOn: item.isOn)
                IconBubble(icon: item.icon, size: 36, rounded: true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(t(item.title))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(p.text)
                            .lineLimit(1)
                        if item.needsAdmin {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(p.textSecondary)
                                .help(t("Wymaga hasła administratora", "Requires the administrator password"))
                        }
                    }
                    Text(item.resolvedCommands.joined(separator: "  ·  "))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(p.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(item.resolvedCommands.joined(separator: "\n"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if item.isChoice {
                    choiceControls(p)
                } else if item.isApplied == true {
                    Badge(text: t("Ustawione", "Applied"), icon: "checkmark", tone: .success)
                        .help(t("To ustawienie jest już aktywne na tym Macu", "This setting is already active on this Mac"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.isOn ? p.bubble.opacity(0.6) : (hovering ? p.card.opacity(0.85) : p.card))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(item.isOn ? p.accent.opacity(0.25) : p.cardStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(p.shadow * 0.6), radius: 4, y: 2)
            .contentShape(Rectangle())
            .onTapGesture {
                if item.isChoice && !item.isOn && item.selectedValue == item.currentValue { return }
                item.isOn.toggle()
            }
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: item.isOn)
        }
    }
}

extension TweakRow {
    private var selection: Binding<String> {
        Binding(
            get: { item.selectedValue ?? item.defaultValue ?? "" },
            set: { value in
                item.selectedValue = value
                item.isOn = value != item.currentValue
            }
        )
    }

    @ViewBuilder
    fileprivate func choiceControls(_ p: Palette) -> some View {
        Picker("", selection: selection) {
            ForEach(item.options, id: \.value) { option in
                Text(t(option.label)).tag(option.value)
            }
            if let current = item.currentValue, !item.options.contains(where: { $0.value == current }) {
                Text(t(item.label(for: current) ?? BiText(en: current))).tag(current)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
        .help(t("Wybierz nową wartość", "Choose a new value"))
        HStack(spacing: 4) {
            Text(t("Teraz:", "Now:"))
                .foregroundStyle(p.textSecondary)
            Text(item.currentValue.flatMap { item.label(for: $0) }.map { t($0) } ?? "–")
                .foregroundStyle(p.success)
                .fontWeight(.semibold)
        }
        .font(.system(size: 12))
        .frame(minWidth: 104, alignment: .trailing)
        .help(t("Wartość ustawiona obecnie w systemie", "The value currently set in macOS"))
    }
}

struct SystemConfigView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.loc) private var t

    private var categories: [BiText] {
        var seen = Set<BiText>()
        return store.visibleTweaks.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            TabHeader(plain: t("Konfiguracja", "System"), accent: t("systemu", "Configuration"),
                      subtitle: t("Ustawienia, które programiści zwykle zmieniają ręcznie po instalacji macOS.",
                                  "Settings developers usually change by hand on a fresh macOS install."))
            summaryCard
            ForEach(categories, id: \.self) { category in
                let indices = store.tweaks.indices.filter { store.tweaks[$0].category == category && store.tweaks[$0].isAvailable }
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: t(category)) {
                        SelectAllControl(selected: indices.filter { store.tweaks[$0].isOn }.count, total: indices.count) { value in
                            store.setAllTweaks(category: category, to: value)
                        }
                    }
                    LazyVStack(spacing: 6) {
                        ForEach(indices.map { (index: $0, id: store.tweaks[$0].id) }, id: \.id) { entry in
                            TweakRow(item: $store.tweaks[entry.index])
                        }
                    }
                }
            }
        }
        .onAppear { store.refreshTweakStates() }
    }

    private var summaryCard: some View {
        Themed { p in
            let checkable = store.visibleTweaks.filter { !$0.isChoice }
            let applied = checkable.filter { $0.isApplied == true }.count
            HStack(spacing: 14) {
                IconBubble(icon: "slider.horizontal.3")
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Aktywne na tym Macu: \(applied) z \(checkable.count)", "Active on this Mac: \(applied) of \(checkable.count)"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(p.text)
                    Text(t("MacPeach odczytuje bieżące ustawienia, oznacza te, które już obowiązują, i pokazuje obecne wartości (np. czas uśpienia).",
                           "MacPeach reads your current settings, marks the ones already in effect and shows current values (e.g. sleep time)."))
                        .font(.system(size: 12))
                        .foregroundStyle(p.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button {
                    store.selectUnappliedTweaks()
                } label: {
                    Label(t("Zaznacz brakujące", "Select missing"), systemImage: "checklist")
                }
                .buttonStyle(PeachButtonStyle(kind: .secondary, compact: true))
            }
            .padding(16)
            .card()
        }
    }
}

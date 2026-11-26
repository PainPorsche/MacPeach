import SwiftUI
import AppKit
import UniformTypeIdentifiers

private struct CountTile: View {
    let label: String
    let count: Int

    var body: some View {
        Themed { p in
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(count > 0 ? p.accent : p.textSecondary.opacity(0.5))
                    .contentTransition(.numericText())
                Text(label)
                    .font(.system(size: 10.5))
                    .foregroundStyle(p.textSecondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 86)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(count > 0 ? p.bubble : p.line.opacity(0.35)))
        }
    }
}

private struct PresetRow: View {
    let preset: Preset
    let unknown: Int
    let onLoad: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            HStack(spacing: 14) {
                IconBubble(icon: "archivebox.fill")
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(p.text)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(p.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                Button(action: onLoad) {
                    Label(t("Wczytaj", "Load"), systemImage: "square.and.arrow.up.on.square")
                }
                .buttonStyle(PeachButtonStyle(kind: .secondary, compact: true))
                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(PeachButtonStyle(kind: .quiet, compact: true))
                .help(t("Eksportuj do pliku", "Export to a file"))
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(PeachButtonStyle(kind: .quiet, compact: true))
                .help(t("Usuń", "Delete"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(hovering ? p.bubble.opacity(0.45) : p.canvas))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }

    private var subtitle: String {
        let date = preset.createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(t.locale))
        let items = t.count(preset.itemCount, pl: "pozycja", "pozycje", "pozycji", en: "item", "items")
        let extra = unknown > 0 ? t(" · \(unknown) spoza listy", " · \(unknown) not in list") : ""
        return "\(items) · \(date)\(extra)"
    }
}

struct PresetView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.loc) private var t
    @State private var name = ""
    @State private var toast: String?
    @State private var toDelete: Preset?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            TabHeader(plain: t("Zapisane", "Saved"), accent: t("presety", "Presets"),
                      subtitle: t("Zapisz zaznaczone aplikacje i ustawienia, a potem odtwórz je na innym Macu.",
                                  "Save your selected apps and settings, then recreate them on another Mac."))
            saveCard
            listCard
        }
        .overlay(alignment: .top) {
            if let toast {
                Themed { p in
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(p.accent))
                        .shadow(color: p.accent.opacity(0.3), radius: 8, y: 4)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .confirmationDialog(t("Usunąć preset „\(toDelete?.name ?? "")”?", "Delete preset “\(toDelete?.name ?? "")”?"),
                            isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button(t("Usuń", "Delete"), role: .destructive) {
                if let toDelete { store.deletePreset(toDelete) }
                toDelete = nil
            }
        } message: {
            Text(t("Tej operacji nie można cofnąć.", "This cannot be undone."))
        }
    }

    private var saveCard: some View {
        Themed { p in
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: t("Zapisz bieżące zaznaczenie", "Save current selection"))
                    .padding(.horizontal, -4)
                HStack(spacing: 10) {
                    TextField(t("Nazwa presetu, np. Nowy MacBook", "Preset name, e.g. New MacBook"), text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(p.canvas))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(p.line, lineWidth: 1))
                        .onSubmit(save)
                    Button(action: save) {
                        Label(t("Zapisz", "Save"), systemImage: "square.and.arrow.down")
                            .frame(height: 20)
                    }
                    .buttonStyle(PeachButtonStyle(kind: .primary))
                    .disabled(trimmedName.isEmpty || totalSelected == 0)
                    .keyboardShortcut("s", modifiers: .command)
                }
                HStack(spacing: 10) {
                    CountTile(label: t("Aplikacje", "Applications"), count: store.selectedCasks.count)
                    CountTile(label: t("Narzędzia CLI", "CLI Tools"), count: store.selectedFormulae.count)
                    CountTile(label: t("Ustawienia", "Settings"), count: store.selectedTweaks.count)
                    Spacer(minLength: 0)
                    if totalSelected == 0 {
                        Text(t("Najpierw zaznacz coś w innych zakładkach.", "Select something in other tabs first."))
                            .font(.system(size: 12))
                            .foregroundStyle(p.textSecondary)
                    }
                }
            }
            .padding(18)
            .card()
        }
    }

    private var listCard: some View {
        Themed { p in
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: t("Twoje presety", "Your presets")) {
                    Text(AppStore.presetsURL.path.abbreviatingHome)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(p.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button(action: importPreset) {
                        Label(t("Importuj…", "Import…"), systemImage: "square.and.arrow.down.on.square")
                    }
                    .buttonStyle(LinkButtonStyle())
                }
                .padding(.horizontal, -4)
                if store.presets.isEmpty {
                    EmptyStateView(icon: "tray", title: t("Brak zapisanych presetów", "No saved presets"),
                                   message: t("Zapisany preset możesz wyeksportować i wczytać na nowym Macu.",
                                              "Export a saved preset and load it on your next Mac."))
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(store.presets) { preset in
                            PresetRow(preset: preset, unknown: store.unknownEntries(in: preset)) {
                                store.apply(preset)
                                show(t("Wczytano „\(preset.name)”", "Loaded “\(preset.name)”"))
                            } onExport: {
                                export(preset)
                            } onDelete: {
                                toDelete = preset
                            }
                        }
                    }
                }
            }
            .padding(18)
            .card()
        }
    }

    private var totalSelected: Int {
        store.selectedInstallCount + store.selectedTweaks.count
    }

    private func save() {
        guard !trimmedName.isEmpty, totalSelected > 0 else { return }
        let presetName = String(trimmedName.prefix(60))
        store.savePreset(named: presetName)
        name = ""
        show(t("Zapisano „\(presetName)”", "Saved “\(presetName)”"))
    }

    private func export(_ preset: Preset) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(preset.name).macpeach.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.export(preset, to: url)
            show(t("Wyeksportowano", "Exported"))
        } catch {
            ErrorCenter.shared.report(error, context: t("Nie udało się wyeksportować presetu.", "Could not export the preset."))
        }
    }

    private func importPreset() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let preset = try store.importPreset(from: url)
            show(t("Zaimportowano „\(preset.name)”", "Imported “\(preset.name)”"))
        } catch {
            ErrorCenter.shared.report(error, context: t("Ten plik nie jest poprawnym presetem MacPeach.", "This file is not a valid MacPeach preset."))
        }
    }

    private func show(_ message: String) {
        withAnimation(.spring(response: 0.3)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut) { if toast == message { toast = nil } }
        }
    }
}

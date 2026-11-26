import SwiftUI

private struct ExtraCard: View {
    let extra: Extra
    @EnvironmentObject private var store: AppStore
    @Environment(\.loc) private var t
    @State private var confirmUndo = false

    var body: some View {
        Themed { p in
            let done = extra.steps.map { store.isStepDone($0) }
            let allDone = !done.contains(false)
            let next = done.firstIndex(of: false)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    IconBubble(icon: extra.icon)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(t(extra.title))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(p.text)
                            if allDone {
                                Badge(text: t("Gotowe", "Done"), icon: "checkmark", tone: .success)
                            }
                        }
                        Text(t(extra.summary))
                            .font(.system(size: 12))
                            .foregroundStyle(p.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                if extra.steps.count > 1 {
                    StepIndicator(titles: extra.steps.map { t($0.title) }, done: done)
                }

                HStack(spacing: 8) {
                    ForEach(Array(extra.steps.enumerated()), id: \.element.id) { index, step in
                        Button {
                            run(step)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: done[index] ? "arrow.clockwise" : (index == next ? "play.fill" : "terminal"))
                                Text(extra.steps.count > 1 ? "\(index + 1). \(t(step.title))" : t(step.title))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PeachButtonStyle(kind: index == next ? .primary : .secondary, compact: true))
                        .help(done[index] ? t("Uruchom ponownie", "Run again") : t(step.title))
                    }
                    if let undo = extra.undo {
                        Button(t(undo.title)) { confirmUndo = true }
                            .buttonStyle(PeachButtonStyle(kind: .quiet, compact: true))
                            .disabled(!done.contains(true))
                    }
                }

                if let note = extra.note {
                    Label {
                        Text(t(note)).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(p.textSecondary)
                }
            }
            .padding(18)
            .card()
            .confirmationDialog(undoTitle, isPresented: $confirmUndo) {
                Button(extra.undo.map { t($0.title) } ?? "", role: .destructive) {
                    guard let undo = extra.undo else { return }
                    store.run(ScriptJob(kind: .extraUndo(extra.id), title: undoTitle,
                                        script: undo.script(t.lang), requiresBrew: false))
                }
            }
        }
    }

    private var undoTitle: String {
        "\(extra.undo.map { t($0.title) } ?? ""): \(t(extra.title))"
    }

    private func run(_ step: ExtraStep) {
        store.run(ScriptJob(kind: .extraStep(step.id), title: "\(t(extra.title)) – \(t(step.title))",
                            script: step.script(t.lang), requiresBrew: step.requiresBrew))
    }
}

struct ExtrasView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.loc) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            TabHeader(plain: t("Dodatki do", "macOS"), accent: t("macOS", "Add-ons"),
                      subtitle: t("Funkcje, których brakuje w systemie, a których włączenie wymaga kilku poleceń. Każdy krok pokazuje skrypt przed uruchomieniem.",
                                  "Features macOS lacks that take several commands to set up. Every step shows its script before it runs."))
            ForEach(store.extras) { extra in
                ExtraCard(extra: extra)
            }
        }
        .onAppear { store.refreshExtraStates() }
    }
}

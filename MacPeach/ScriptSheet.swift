import SwiftUI
import AppKit

struct ScriptSheet: View {
    let job: ScriptJob
    let onFinish: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) private var t
    @StateObject private var runner = ScriptRunner()
    @State private var copied = false
    @State private var confirmCancel = false

    var body: some View {
        Themed { p in
            VStack(spacing: 0) {
                header(p)
                Divider().opacity(0.5)
                content(p)
                if let banner = banner(p) { banner }
                Divider().opacity(0.5)
                toolbar(p)
            }
            .frame(minWidth: 720, idealWidth: 760, minHeight: 540, idealHeight: 600)
            .background(p.terminal)
        }
        .interactiveDismissDisabled(runner.state == .running)
        .onChange(of: runner.state) { _, state in
            if state.isFinished { onFinish(state == .success) }
        }
        .confirmationDialog(t("Przerwać działający skrypt?", "Stop the running script?"), isPresented: $confirmCancel) {
            Button(t("Przerwij", "Stop"), role: .destructive) { runner.cancel() }
        } message: {
            Text(t("Część zmian mogła już zostać wprowadzona.", "Some changes may already have been made."))
        }
    }

    private func header(_ p: Palette) -> some View {
        HStack(spacing: 12) {
            IconBubble(icon: statusIcon, tint: statusColor(p), background: statusColor(p).opacity(0.14))
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(p.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .background(p.card)
        .overlay(alignment: .bottom) {
            if runner.state == .running {
                ProgressView().progressViewStyle(.linear).tint(p.accent).padding(.horizontal, 24).offset(y: -4)
            }
        }
    }

    private func content(_ p: Palette) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(runner.state == .idle ? job.script : (runner.output.isEmpty ? t("Uruchamianie…", "Starting…") : runner.output))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(runner.state == .idle ? p.text.opacity(0.85) : p.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(20)
                    Color.clear.frame(height: 1).id("end")
                }
            }
            .background(p.terminal)
            .onChange(of: runner.output) { _, _ in
                proxy.scrollTo("end", anchor: .bottom)
            }
        }
    }

    private func banner(_ p: Palette) -> AnyView? {
        switch runner.state {
        case .idle:
            return AnyView(
                Label(t("Sprawdź skrypt. Polecenia z sudo poproszą o hasło administratora w osobnym oknie.",
                        "Review the script. Commands using sudo will ask for your administrator password in a separate window."),
                      systemImage: "eye")
                    .font(.system(size: 12))
                    .foregroundStyle(p.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(p.card)
            )
        case .success:
            return AnyView(resultBanner(icon: "checkmark.circle.fill", text: t("Zakończono pomyślnie", "Completed successfully"), color: p.success))
        case .failed(let message):
            return AnyView(resultBanner(icon: "xmark.octagon.fill", text: message + " · " + t("szczegóły w logu", "details in the log"), color: p.danger))
        case .cancelled:
            return AnyView(resultBanner(icon: "stop.circle.fill", text: t("Przerwano", "Stopped"), color: .orange))
        case .running:
            return nil
        }
    }

    private func resultBanner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text).lineLimit(2)
        }
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(color.opacity(0.10))
    }

    private func toolbar(_ p: Palette) -> some View {
        HStack(spacing: 10) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(runner.state == .idle ? job.script : runner.output, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    copied = false
                }
            } label: {
                Label(copied ? t("Skopiowano", "Copied") : t("Kopiuj", "Copy"), systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(PeachButtonStyle(kind: .quiet, compact: true))

            if let logURL = runner.logURL, runner.state != .idle {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([logURL])
                } label: {
                    Label(t("Pokaż log", "Show log"), systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(PeachButtonStyle(kind: .quiet, compact: true))
            }

            Spacer()

            switch runner.state {
            case .idle:
                Button(t("Anuluj", "Cancel")) { dismiss() }
                    .buttonStyle(PeachButtonStyle(kind: .quiet))
                    .keyboardShortcut(.cancelAction)
                Button {
                    runner.run(job, lang: t.lang)
                } label: {
                    Label(t("Uruchom", "Run"), systemImage: "play.fill")
                }
                .buttonStyle(PeachButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
            case .running:
                Button {
                    confirmCancel = true
                } label: {
                    Label(t("Przerwij", "Stop"), systemImage: "stop.fill")
                }
                .buttonStyle(PeachButtonStyle(kind: .danger))
            default:
                Button(t("Zamknij", "Close")) { dismiss() }
                    .buttonStyle(PeachButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(p.card)
    }

    private var statusIcon: String {
        switch runner.state {
        case .idle: return "doc.text.magnifyingglass"
        case .running: return "terminal.fill"
        case .success: return "checkmark"
        case .failed: return "xmark"
        case .cancelled: return "stop.fill"
        }
    }

    private func statusColor(_ p: Palette) -> Color {
        switch runner.state {
        case .idle, .running: return p.accentStrong
        case .success: return p.success
        case .failed: return p.danger
        case .cancelled: return .orange
        }
    }

    private var statusText: String {
        switch runner.state {
        case .idle: return t("Podgląd skryptu – nic nie zostało jeszcze wykonane", "Script preview – nothing has run yet")
        case .running: return t("Trwa wykonywanie…", "Running…")
        case .success: return t("Gotowe", "Done")
        case .failed(let message): return message
        case .cancelled: return t("Przerwano przez użytkownika", "Stopped by the user")
        }
    }
}

struct IssueSheet: View {
    let issue: AppIssue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    IconBubble(icon: "exclamationmark.triangle.fill", tint: p.danger, background: p.danger.opacity(0.13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(issue.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(p.text)
                        Text(issue.message)
                            .font(.system(size: 12.5))
                            .foregroundStyle(p.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !issue.details.isEmpty {
                    ScrollView {
                        Text(issue.details)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(p.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .frame(maxHeight: 260)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(p.terminal))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(p.line, lineWidth: 1))
                }
                Text(t("Szczegóły zapisano w: ", "Details were saved to: ") + AppLog.shared.fileURL.path.abbreviatingHome)
                    .font(.system(size: 11))
                    .foregroundStyle(p.textSecondary)
                    .textSelection(.enabled)
                HStack(spacing: 10) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("\(issue.title)\n\(issue.message)\n\n\(issue.details)", forType: .string)
                    } label: {
                        Label(t("Kopiuj szczegóły", "Copy details"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(PeachButtonStyle(kind: .quiet, compact: true))
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([issue.fileURL ?? AppLog.shared.fileURL])
                    } label: {
                        Label(t("Pokaż w Finderze", "Show in Finder"), systemImage: "folder")
                    }
                    .buttonStyle(PeachButtonStyle(kind: .quiet, compact: true))
                    Spacer()
                    Button("OK") { dismiss() }
                        .buttonStyle(PeachButtonStyle(kind: .primary))
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 560)
            .background(p.card)
        }
    }
}

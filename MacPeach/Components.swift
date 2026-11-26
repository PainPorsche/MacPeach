import SwiftUI

struct Themed<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: (Palette) -> Content

    init(@ViewBuilder _ content: @escaping (Palette) -> Content) {
        self.content = content
    }

    var body: some View {
        content(Palette.resolve(scheme))
    }
}

struct CardBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat = 16
    var fill: Color?

    func body(content: Content) -> some View {
        let p = Palette.resolve(scheme)
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill ?? p.card))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(p.cardStroke, lineWidth: 1))
            .shadow(color: .black.opacity(p.shadow), radius: 8, y: 4)
    }
}

extension View {
    func card(radius: CGFloat = 16, fill: Color? = nil) -> some View {
        modifier(CardBackground(radius: radius, fill: fill))
    }
}

struct IconBubble: View {
    let icon: String
    var size: CGFloat = 40
    var rounded = false
    var tint: Color?
    var background: Color?

    var body: some View {
        Themed { p in
            ZStack {
                if rounded {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(background ?? p.bubble)
                } else {
                    Circle().fill(background ?? p.bubble)
                }
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(tint ?? p.accentStrong)
                    .symbolRenderingMode(.monochrome)
            }
            .frame(width: size, height: size)
        }
    }
}

struct CheckBox: View {
    let isOn: Bool

    var body: some View {
        Themed { p in
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? p.accent : Color.clear)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isOn ? p.accent : p.textSecondary.opacity(0.45), lineWidth: 1.5)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 22, height: 22)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isOn)
        }
    }
}

struct Badge: View {
    enum Tone { case accent, success, neutral, warning }
    let text: String
    var icon: String?
    var tone: Tone = .accent

    var body: some View {
        Themed { p in
            let color: Color = {
                switch tone {
                case .accent: return p.accent
                case .success: return p.success
                case .neutral: return p.textSecondary
                case .warning: return .orange
                }
            }()
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 9, weight: .bold)) }
                Text(text).font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.13)))
            .fixedSize()
        }
    }
}

struct PeachButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, danger }
    var kind: Kind = .primary
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, kind: kind, compact: compact)
    }

    private struct StyledButton: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        let compact: Bool
        @Environment(\.colorScheme) private var scheme
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            let p = Palette.resolve(scheme)
            configuration.label
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(foreground(p))
                .padding(.horizontal, compact ? 12 : 16)
                .padding(.vertical, compact ? 6 : 9)
                .background(background(p))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .brightness(hovering && isEnabled && kind == .primary ? 0.04 : 0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { hovering = $0 }
        }

        private func foreground(_ p: Palette) -> Color {
            switch kind {
            case .primary: return .white
            case .secondary: return p.accent
            case .quiet: return hovering ? p.text : p.textSecondary
            case .danger: return p.danger
            }
        }

        @ViewBuilder
        private func background(_ p: Palette) -> some View {
            let shape = RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
            switch kind {
            case .primary:
                shape.fill(LinearGradient(colors: [p.accentStrong, p.accent], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: p.accent.opacity(isEnabled ? 0.28 : 0), radius: 6, y: 3)
            case .secondary:
                shape.fill(p.bubble.opacity(hovering ? 1 : 0.85))
            case .quiet:
                shape.fill(p.line.opacity(hovering ? 0.55 : 0.35))
            case .danger:
                shape.fill(p.danger.opacity(hovering ? 0.16 : 0.10))
            }
        }
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Inner(configuration: configuration)
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.colorScheme) private var scheme
        @State private var hovering = false

        var body: some View {
            let p = Palette.resolve(scheme)
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? p.accent : p.textSecondary)
                .opacity(configuration.isPressed ? 0.6 : 1)
                .onHover { hovering = $0 }
        }
    }
}

struct TabHeader: View {
    let plain: String
    let accent: String
    let subtitle: String

    var body: some View {
        Themed { p in
            VStack(alignment: .leading, spacing: 6) {
                (Text(plain + " ").foregroundStyle(p.text) + Text(accent).foregroundStyle(p.accent))
                    .font(.system(size: 30, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(p.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Themed { p in
            HStack(spacing: 14) {
                Text(title.uppercased(with: .current))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(p.accent)
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.horizontal, 4)
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = { EmptyView() }
    }
}

struct SelectAllControl: View {
    let selected: Int
    let total: Int
    let action: (Bool) -> Void
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            HStack(spacing: 14) {
                if selected > 0 {
                    Text(t("Zaznaczono: \(selected)", "\(selected) selected"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(p.accent)
                        .contentTransition(.numericText())
                }
                Button(selected == total ? t("Odznacz wszystko", "Deselect all") : t("Zaznacz wszystko", "Select all")) {
                    action(selected < total)
                }
                .buttonStyle(LinkButtonStyle())
            }
        }
    }
}

struct SegmentedPill<Value: Hashable>: View {
    struct Option {
        let value: Value
        let title: String
        var count: Int?
    }

    let options: [Option]
    @Binding var selection: Value
    var height: CGFloat = 32
    var minSegmentWidth: CGFloat = 40

    var body: some View {
        Themed { p in
            HStack(spacing: 2) {
                ForEach(options, id: \.value) { option in
                    let active = option.value == selection
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selection = option.value }
                    } label: {
                        HStack(spacing: 6) {
                            Text(option.title)
                                .font(.system(size: 13, weight: .semibold))
                            if let count = option.count {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(active ? Color.white.opacity(0.25) : p.line.opacity(0.6)))
                            }
                        }
                        .foregroundStyle(active ? Color.white : p.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(minWidth: minSegmentWidth, minHeight: height - 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(active ? p.accent : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .card(radius: 9)
        }
    }
}

struct ToolbarIconButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Themed { p in
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(hovering ? p.accent : p.text.opacity(0.75))
                    .frame(width: 38, height: 32)
                    .card(radius: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(help)
            .onHover { hovering = $0 }
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    let prompt: String
    @FocusState private var focused: Bool

    var body: some View {
        Themed { p in
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(focused && !text.isEmpty ? p.accent : p.textSecondary)
                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($focused)
                    .focusEffectDisabled()
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(p.textSecondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .card(radius: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(focused && !text.isEmpty ? p.accent.opacity(0.5) : .clear, lineWidth: 1.5)
            )
        }
    }
}

struct StepIndicator: View {
    let titles: [String]
    let done: [Bool]

    var body: some View {
        Themed { p in
            let next = done.firstIndex(of: false)
            HStack(spacing: 8) {
                ForEach(titles.indices, id: \.self) { index in
                    let isDone = done[index]
                    let isNext = index == next
                    HStack(spacing: 6) {
                        ZStack {
                            Circle().fill(isDone ? p.accent : (isNext ? p.bubble : p.line.opacity(0.7)))
                            if isDone {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isNext ? p.accent : p.textSecondary)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Text(titles[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isDone || isNext ? p.text : p.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    if index < titles.count - 1 {
                        Capsule()
                            .fill(isDone ? p.accent : p.line)
                            .frame(height: 2)
                            .frame(minWidth: 16, maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        Themed { p in
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(p.accentSoft)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(p.text)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(p.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }
}

extension String {
    var abbreviatingHome: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return hasPrefix(home) ? "~" + dropFirst(home.count) : self
    }
}

import SwiftUI
import AppKit

struct LogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.05, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.27, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.95))
        p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.95))
        p.closeSubpath()
        p.move(to: CGPoint(x: w * 0.95, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.73, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.95))
        p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.95))
        p.closeSubpath()
        return p
    }
}

struct LogoMark: View {
    var width: CGFloat = 96

    var body: some View {
        Themed { p in
            LogoShape()
                .fill(LinearGradient(colors: [p.accentSoft, p.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: width, height: width * 0.875)
                .shadow(color: p.accentStrong.opacity(0.35), radius: 12, y: 6)
        }
    }
}

private struct SidebarWaves: View {
    var body: some View {
        Themed { p in
            ZStack {
                LinearGradient(colors: [p.sidebarTop, p.sidebarBottom], startPoint: .top, endPoint: .bottom)
                GeometryReader { geo in
                    let w = geo.size.width
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 60))
                        path.addCurve(to: CGPoint(x: w, y: 110), control1: CGPoint(x: w * 0.35, y: 10), control2: CGPoint(x: w * 0.65, y: 150))
                        path.addLine(to: CGPoint(x: w, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: 0))
                        path.closeSubpath()
                    }
                    .fill(p.wave1)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 150))
                        path.addCurve(to: CGPoint(x: w, y: 200), control1: CGPoint(x: w * 0.4, y: 110), control2: CGPoint(x: w * 0.6, y: 250))
                        path.addLine(to: CGPoint(x: w, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: 0))
                        path.closeSubpath()
                    }
                    .fill(p.wave2)
                }
            }
        }
    }
}

struct DeviceInfoCard: View {
    let info: DeviceInfo
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 12) {
                    Image(systemName: info.symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(p.accentStrong)
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.modelName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(p.text)
                        if !info.modelDetail.isEmpty {
                            Text(info.modelDetail)
                                .font(.system(size: 11.5))
                                .foregroundStyle(p.textSecondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 2)

                row(p, icon: "apple.logo", label: info.osName, value: info.osVersion)
                row(p, icon: "cpu", label: t("Procesor", "Chip"), value: info.chip, help: info.architecture)
                row(p, icon: "memorychip", label: t("Pamięć", "Memory"), value: info.memoryBytes > 0 ? ByteFormat.memory(info.memoryBytes) : "–")
                VStack(spacing: 6) {
                    row(p, icon: "internaldrive", label: t("Wolne miejsce", "Free space"),
                        value: info.storageTotal > 0 ? ByteFormat.storage(info.storageFree) : "–",
                        help: info.storageTotal > 0 ? t("\(ByteFormat.storage(info.storageFree)) wolne z \(ByteFormat.storage(info.storageTotal))",
                                                        "\(ByteFormat.storage(info.storageFree)) free of \(ByteFormat.storage(info.storageTotal))") : nil)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(p.line.opacity(0.8))
                            Capsule()
                                .fill(LinearGradient(colors: [p.accentStrong, p.accent], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(4, geo.size.width * info.storageUsedFraction))
                        }
                    }
                    .frame(height: 4)
                    .padding(.leading, 28)
                    .animation(.easeOut(duration: 0.4), value: info.storageUsedFraction)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.card.opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(p.cardStroke, lineWidth: 1))
            .shadow(color: .black.opacity(p.shadow), radius: 8, y: 4)
        }
    }

    private func row(_ p: Palette, icon: String, label: String, value: String, help: String? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12.5))
                .foregroundStyle(p.textSecondary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(p.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(p.text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .help(help ?? value)
    }
}

private struct MenuItemRow: View {
    let tab: Tab
    let isActive: Bool
    let badge: Int
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            Button(action: action) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isActive ? Color.white.opacity(0.25) : p.bubble)
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isActive ? Color.white : p.accentStrong)
                    }
                    .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tab.title(t))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isActive ? .white : p.text)
                        Text(tab.subtitle(t))
                            .font(.system(size: 11))
                            .foregroundStyle(isActive ? Color.white.opacity(0.85) : p.textSecondary)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isActive ? p.accent : .white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(isActive ? Color.white : p.accent))
                            .contentTransition(.numericText())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isActive ? Color.white.opacity(0.9) : p.textSecondary.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isActive
                              ? AnyShapeStyle(LinearGradient(colors: [p.accentStrong, p.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(hovering ? p.hover : Color.clear))
                )
                .shadow(color: isActive ? p.accentStrong.opacity(0.35) : .clear, radius: 8, y: 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        }
    }
}

private struct SettingsLauncher: View {
    @State private var hovering = false
    @Environment(\.loc) private var t

    var body: some View {
        Themed { p in
            SettingsLink {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(hovering ? p.accentStrong : p.textSecondary)
                        .frame(width: 36)
                    Text(t("Ustawienia", "Settings"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(p.text)
                    Spacer(minLength: 0)
                    Text("⌘,")
                        .font(.system(size: 12))
                        .foregroundStyle(p.textSecondary.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(hovering ? p.hover : Color.clear))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: Tab
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.resolve(scheme)
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                LogoMark(width: 84)
                    .padding(.top, 46)
                Text("MacPeach")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(p.text)
                Text(AppInfo.version)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(p.accentStrong)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .background(SidebarWaves())

            VStack(spacing: 16) {
                DeviceInfoCard(info: store.device)
                VStack(spacing: 4) {
                    ForEach(Tab.allCases) { tab in
                        MenuItemRow(tab: tab, isActive: selectedTab == tab, badge: badge(for: tab)) {
                            withAnimation(.easeOut(duration: 0.18)) { selectedTab = tab }
                        }
                    }
                }
                Spacer(minLength: 0)
                Divider().opacity(scheme == .dark ? 0.2 : 0.4)
                SettingsLauncher()
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .frame(maxHeight: .infinity)
            .background(LinearGradient(
                colors: [p.sidebarBottom.opacity(scheme == .dark ? 1 : 0.55), p.sidebarTop.opacity(scheme == .dark ? 1 : 0.40)],
                startPoint: .top, endPoint: .bottom))
        }
        .frame(width: 300)
        .background(p.sidebarTop)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                store.refreshStorage()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshStorage()
        }
    }

    private func badge(for tab: Tab) -> Int {
        switch tab {
        case .install: return store.selectedInstallCount
        case .sysconfig: return store.selectedTweaks.count
        default: return 0
        }
    }
}

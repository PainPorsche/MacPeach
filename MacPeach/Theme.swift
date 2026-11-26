import SwiftUI
import AppKit

struct Palette {
    let accent: Color
    let accentStrong: Color
    let accentSoft: Color
    let bubble: Color
    let sidebarTop: Color
    let sidebarBottom: Color
    let canvas: Color
    let card: Color
    let text: Color
    let textSecondary: Color
    let line: Color
    let terminal: Color
    let cardStroke: Color
    let wave1: Color
    let wave2: Color
    let hover: Color
    let shadow: Double
    let success: Color
    let danger: Color

    static let light = Palette(
        accent: Color(red: 0.93, green: 0.27, blue: 0.55),
        accentStrong: Color(red: 0.96, green: 0.36, blue: 0.62),
        accentSoft: Color(red: 0.98, green: 0.78, blue: 0.86),
        bubble: Color(red: 0.99, green: 0.89, blue: 0.93),
        sidebarTop: Color(red: 0.99, green: 0.91, blue: 0.94),
        sidebarBottom: Color(red: 0.98, green: 0.80, blue: 0.87),
        canvas: Color(red: 0.98, green: 0.97, blue: 0.98),
        card: .white,
        text: Color(red: 0.10, green: 0.10, blue: 0.12),
        textSecondary: Color(red: 0.45, green: 0.45, blue: 0.50),
        line: Color(red: 0.91, green: 0.91, blue: 0.93),
        terminal: Color(red: 0.97, green: 0.96, blue: 0.97),
        cardStroke: Color(white: 1, opacity: 0.60),
        wave1: Color(white: 1, opacity: 0.35),
        wave2: Color(white: 1, opacity: 0.25),
        hover: Color(white: 1, opacity: 0.50),
        shadow: 0.05,
        success: Color(red: 0.20, green: 0.62, blue: 0.40),
        danger: Color(red: 0.86, green: 0.24, blue: 0.27)
    )

    static let dark = Palette(
        accent: Color(red: 0.97, green: 0.40, blue: 0.67),
        accentStrong: Color(red: 1.00, green: 0.45, blue: 0.72),
        accentSoft: Color(red: 0.72, green: 0.28, blue: 0.48),
        bubble: Color(red: 0.34, green: 0.18, blue: 0.24),
        sidebarTop: Color(red: 0.18, green: 0.17, blue: 0.19),
        sidebarBottom: Color(red: 0.21, green: 0.20, blue: 0.22),
        canvas: Color(red: 0.15, green: 0.15, blue: 0.16),
        card: Color(red: 0.21, green: 0.20, blue: 0.22),
        text: Color(red: 0.95, green: 0.93, blue: 0.96),
        textSecondary: Color(red: 0.60, green: 0.58, blue: 0.64),
        line: Color(red: 0.32, green: 0.31, blue: 0.34),
        terminal: Color(red: 0.12, green: 0.11, blue: 0.13),
        cardStroke: Color(white: 1, opacity: 0.09),
        wave1: Color(white: 1, opacity: 0.07),
        wave2: Color(white: 1, opacity: 0.04),
        hover: Color(white: 1, opacity: 0.08),
        shadow: 0.30,
        success: Color(red: 0.36, green: 0.80, blue: 0.55),
        danger: Color(red: 1.00, green: 0.42, blue: 0.45)
    )

    static func resolve(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? dark : light
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    func label(_ t: Loc) -> String {
        switch self {
        case .system: return t("Systemowy", "System")
        case .light: return t("Jasny", "Light")
        case .dark: return t("Ciemny", "Dark")
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    static var current: AppearanceMode {
        UserDefaults.standard.string(forKey: SettingsKey.appearance).flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    static func apply(_ mode: AppearanceMode) {
        NSApp.appearance = mode.nsAppearance
    }
}

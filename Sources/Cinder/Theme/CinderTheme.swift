import SwiftUI

// MARK: - Cinder Theme System
// 6 themes using color theory: complementary, monochromatic, analogous, 2-color, 3-color.
// ThemeManager is @Observable — inject via .environment() at app root.

// MARK: - Theme Definition

struct CinderTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let description: String

    // Surfaces
    let base: Color       // Window background
    let surface: Color    // Sidebar, panels
    let card: Color       // Cards
    let cardHover: Color
    let border: Color

    // Accents — accent1 is the "fire" role
    let accent1: Color
    let accent2: Color?   // nil for 2-color themes

    // Heat spectrum (nil = use default ember spectrum)
    let heatBlazing: Color
    let heatHot: Color
    let heatWarm: Color
    let heatCooling: Color
    let heatCold: Color
    let heatAsh: Color

    // Actions
    let reignite: Color
    let snooze: Color
    let archive: Color

    // Text — explicit per theme. Phosphor = green text, Parchment = cream text.
    let textPrimary:   Color
    let textSecondary: Color
    let textMuted:     Color

    static func == (lhs: CinderTheme, rhs: CinderTheme) -> Bool { lhs.id == rhs.id }
}

// MARK: - Theme Catalogue

extension CinderTheme {

    // 1. EMBER — default. Warm analogous fire palette.
    static let ember = CinderTheme(
        id: "ember", name: "Ember", emoji: "🔥",
        description: "The original. Ash dark, fire bright.",
        base: Color(hex: "#121014"), surface: Color(hex: "#1A181C"),
        card: Color(hex: "#211E24"), cardHover: Color(hex: "#272429"),
        border: Color(white: 1, opacity: 0.07),
        accent1: Color(hex: "#FF6D1A"), accent2: Color(hex: "#FFB81A"),
        heatBlazing: Color(hex: "#FF4500"), heatHot: Color(hex: "#FF7A1A"),
        heatWarm: Color(hex: "#FFB81A"), heatCooling: Color(hex: "#5B8AC8"),
        heatCold: Color(hex: "#3A5AA0"), heatAsh: Color(hex: "#58535A"),
        reignite: Color(hex: "#33DC72"), snooze: Color(hex: "#4D8CFF"),
        archive: Color(hex: "#7A7580"),
        textPrimary: .white, textSecondary: Color(white: 0.60), textMuted: Color(white: 0.38)
    )

    // 2. DEEP SEA — 2-color. Cool blue on void black.
    static let deepSea = CinderTheme(
        id: "deepSea", name: "Deep Sea", emoji: "🌊",
        description: "2-color. Cool blue on void black.",
        base: Color(hex: "#060C12"), surface: Color(hex: "#0C1622"),
        card: Color(hex: "#101E2E"), cardHover: Color(hex: "#142436"),
        border: Color(white: 1, opacity: 0.06),
        accent1: Color(hex: "#1ABEFF"), accent2: nil,
        heatBlazing: Color(hex: "#00D4FF"), heatHot: Color(hex: "#00AADD"),
        heatWarm: Color(hex: "#0080BB"), heatCooling: Color(hex: "#005A8A"),
        heatCold: Color(hex: "#003D66"), heatAsh: Color(hex: "#2A3540"),
        reignite: Color(hex: "#00E5AA"), snooze: Color(hex: "#1ABEFF"),
        archive: Color(hex: "#3A4550"),
        textPrimary: .white, textSecondary: Color(white: 0.60), textMuted: Color(white: 0.38)
    )

    // 3. VOID — monochromatic purple/violet.
    static let void = CinderTheme(
        id: "void", name: "Void", emoji: "🔮",
        description: "Monochromatic violet. One hue, infinite depth.",
        base: Color(hex: "#0D0A14"), surface: Color(hex: "#160F22"),
        card: Color(hex: "#1E162E"), cardHover: Color(hex: "#251C36"),
        border: Color(white: 1, opacity: 0.07),
        accent1: Color(hex: "#9B6CFF"), accent2: Color(hex: "#CC99FF"),
        heatBlazing: Color(hex: "#BF3FFF"), heatHot: Color(hex: "#9B6CFF"),
        heatWarm: Color(hex: "#7A55CC"), heatCooling: Color(hex: "#5540AA"),
        heatCold: Color(hex: "#3A2E88"), heatAsh: Color(hex: "#3D3550"),
        reignite: Color(hex: "#4DFFB8"), snooze: Color(hex: "#6B99FF"),
        archive: Color(hex: "#5A5070"),
        textPrimary: .white, textSecondary: Color(white: 0.60), textMuted: Color(white: 0.38)
    )

    // 4. MATRIX — 2-color phosphor green on black.
    // Body text is green, not white — every pixel is on-theme.
    static let matrix = CinderTheme(
        id: "matrix", name: "Matrix", emoji: "💻",
        description: "2-color. Phosphor green terminal mode.",
        base: Color(hex: "#020A02"), surface: Color(hex: "#060E06"),
        card: Color(hex: "#091509"), cardHover: Color(hex: "#0C1C0C"),
        border: Color(white: 1, opacity: 0.06),
        accent1: Color(hex: "#00FF41"), accent2: nil,
        heatBlazing: Color(hex: "#00FF41"), heatHot: Color(hex: "#00CC33"),
        heatWarm: Color(hex: "#00AA27"), heatCooling: Color(hex: "#007718"),
        heatCold: Color(hex: "#00440E"), heatAsh: Color(hex: "#1A2A1A"),
        reignite: Color(hex: "#00FF99"), snooze: Color(hex: "#00BBFF"),
        archive: Color(hex: "#2A3D2A"),
        textPrimary: Color(hex: "#00FF41"),                        // green text
        textSecondary: Color(hex: "#00FF41").opacity(0.55),
        textMuted: Color(hex: "#00FF41").opacity(0.30)
    )

    // 5. PARCHMENT — warm analogous. Cream text on aged ink.
    // Parchment breaks the "white text" convention deliberately.
    static let parchment = CinderTheme(
        id: "parchment", name: "Parchment", emoji: "📜",
        description: "3-color analogous. Candlelight gold on aged ink.",
        base: Color(hex: "#100C06"), surface: Color(hex: "#181208"),
        card: Color(hex: "#221A0C"), cardHover: Color(hex: "#2A2010"),
        border: Color(white: 1, opacity: 0.07),
        accent1: Color(hex: "#D4A017"), accent2: Color(hex: "#C47A3A"),
        heatBlazing: Color(hex: "#E8621A"), heatHot: Color(hex: "#D4881A"),
        heatWarm: Color(hex: "#C4AA17"), heatCooling: Color(hex: "#8A7755"),
        heatCold: Color(hex: "#665540"), heatAsh: Color(hex: "#4A4035"),
        reignite: Color(hex: "#88DD55"), snooze: Color(hex: "#5599CC"),
        archive: Color(hex: "#6A6050"),
        textPrimary: Color(hex: "#F0E4C8"),   // warm cream
        textSecondary: Color(hex: "#C8A878"), // amber-tinted
        textMuted: Color(hex: "#8A7060")      // warm brown-grey
    )

    // 6. FORGE — 2-color. Blood red on charcoal. Zero mercy.
    static let forge = CinderTheme(
        id: "forge", name: "Forge", emoji: "⚒️",
        description: "2-color. Blood red on charcoal. Zero mercy.",
        base: Color(hex: "#0A0606"), surface: Color(hex: "#120808"),
        card: Color(hex: "#1A0C0C"), cardHover: Color(hex: "#221010"),
        border: Color(white: 1, opacity: 0.06),
        accent1: Color(hex: "#CC1A1A"), accent2: nil,
        heatBlazing: Color(hex: "#FF2222"), heatHot: Color(hex: "#CC1A1A"),
        heatWarm: Color(hex: "#991414"), heatCooling: Color(hex: "#661010"),
        heatCold: Color(hex: "#440C0C"), heatAsh: Color(hex: "#2E1A1A"),
        reignite: Color(hex: "#FF4444"), snooze: Color(hex: "#AA4444"),
        archive: Color(hex: "#442222"),
        textPrimary: .white, textSecondary: Color(white: 0.60), textMuted: Color(white: 0.38)
    )

    static let all: [CinderTheme] = [.ember, .deepSea, .void, .matrix, .parchment, .forge]
}

// MARK: - Theme Manager

@Observable
final class ThemeManager {
    var current: CinderTheme {
        didSet { AppStorage.themeId = current.id }
    }

    init() {
        let saved = AppStorage.themeId
        self.current = CinderTheme.all.first { $0.id == saved } ?? .ember
    }

    func set(_ theme: CinderTheme) {
        current = theme
    }

    // Convenience accessors — read these everywhere instead of Color.cinderBase etc.
    var base:      Color { current.base }
    var surface:   Color { current.surface }
    var card:      Color { current.card }
    var cardHover: Color { current.cardHover }
    var border:    Color { current.border }
    var accent:    Color { current.accent1 }
    var accent2:   Color { current.accent2 ?? current.accent1 }

    var heatBlazing: Color { current.heatBlazing }
    var heatHot:     Color { current.heatHot }
    var heatWarm:    Color { current.heatWarm }
    var heatCooling: Color { current.heatCooling }
    var heatCold:    Color { current.heatCold }
    var heatAsh:     Color { current.heatAsh }

    var reignite: Color { current.reignite }
    var snooze:   Color { current.snooze }
    var archive:  Color { current.archive }

    // Text — use these instead of .white/.cinderSecondary/.cinderMuted
    // Matrix = green text, Parchment = cream text, others = white family
    var textPrimary:   Color { current.textPrimary }
    var textSecondary: Color { current.textSecondary }
    var textMuted:     Color { current.textMuted }

    private enum AppStorage {
        static var themeId: String {
            get { UserDefaults.standard.string(forKey: "cinderThemeId") ?? "ember" }
            set { UserDefaults.standard.set(newValue, forKey: "cinderThemeId") }
        }
    }
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - Color(hex:) init

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

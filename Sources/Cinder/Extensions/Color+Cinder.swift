import SwiftUI

extension Color {
    // Backgrounds
    static let cinderBase       = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let cinderCard       = Color(red: 0.13, green: 0.12, blue: 0.14)
    static let cinderCardHover  = Color(red: 0.16, green: 0.15, blue: 0.17)
    static let cinderSurface    = Color(red: 0.10, green: 0.09, blue: 0.11)
    static let cinderBorder     = Color(white: 1, opacity: 0.07)

    // Heat spectrum (hottest → coldest)
    static let heatBlazing  = Color(red: 1.00, green: 0.38, blue: 0.10) // <3d — deep ember
    static let heatHot      = Color(red: 1.00, green: 0.55, blue: 0.20) // 3–7d — flame
    static let heatWarm     = Color(red: 1.00, green: 0.72, blue: 0.10) // 7–30d — amber
    static let heatCooling  = Color(red: 0.45, green: 0.60, blue: 0.80) // 30–90d — fading blue
    static let heatCold     = Color(red: 0.35, green: 0.45, blue: 0.65) // 90–180d — cold blue
    static let heatAsh      = Color(red: 0.35, green: 0.33, blue: 0.36) // 180d+ — ash grey

    // Actions
    static let reigniteGreen = Color(red: 0.20, green: 0.85, blue: 0.45)
    static let snoozeBlue    = Color(red: 0.30, green: 0.55, blue: 1.00)
    static let archiveGrey   = Color(red: 0.50, green: 0.47, blue: 0.52)

    // Text
    static let cinderPrimary   = Color.white
    static let cinderSecondary = Color(white: 0.60)
    static let cinderMuted     = Color(white: 0.38)
}

// MARK: - Stack Colors
extension TechStack {
    var color: Color {
        switch self {
        case .swift:      return Color(red: 1.00, green: 0.35, blue: 0.20)
        case .swiftUI:    return Color(red: 0.40, green: 0.75, blue: 1.00)
        case .react:      return Color(red: 0.37, green: 0.81, blue: 0.96)
        case .nextjs:     return Color(white: 0.85)
        case .astro:      return Color(red: 1.00, green: 0.45, blue: 0.80)
        case .python:     return Color(red: 0.25, green: 0.60, blue: 0.95)
        case .typescript: return Color(red: 0.18, green: 0.50, blue: 0.85)
        case .rust:       return Color(red: 0.85, green: 0.37, blue: 0.20)
        case .go:         return Color(red: 0.42, green: 0.82, blue: 0.92)
        case .node:       return Color(red: 0.40, green: 0.72, blue: 0.30)
        case .electron:   return Color(red: 0.55, green: 0.82, blue: 0.98)
        case .bun:        return Color(red: 0.95, green: 0.78, blue: 0.42)
        case .vue:        return Color(red: 0.25, green: 0.75, blue: 0.55)
        case .unknown:    return Color(white: 0.45)
        }
    }
}

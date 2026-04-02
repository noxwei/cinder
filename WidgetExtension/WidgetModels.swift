import WidgetKit
import SwiftUI

// MARK: - API Response Models

struct DigestResponse: Codable {
    let headline: String
    let summary: String
    let mostActive: String?
    let mostUrgent: String?
    let needsAttention: [String]
    let hotProjects: [String]
    let totalActive: Int
    let totalArchived: Int
    let generatedAt: String
}

struct ProjectResponse: Codable {
    let id: String
    let name: String
    let heat: String
    let dormantDays: Int
    let lastCommitDate: String?
    let stacks: [String]
    let commitCountLastMonth: Int
}

struct StatsResponse: Codable {
    let totalProjects: Int
    let archivedProjects: Int
    let totalReignited: Int
    let heatBreakdown: HeatBreakdown
    struct HeatBreakdown: Codable {
        let blazing: Int; let hot: Int; let warm: Int
        let cooling: Int; let cold: Int; let ash: Int
    }
}

// MARK: - Widget Data Bundle

struct CinderWidgetData {
    let digest: DigestResponse
    let projects: [ProjectResponse]   // for large grid
    let fetchedAt: Date

    static let placeholder = CinderWidgetData(
        digest: DigestResponse(
            headline: "Hot: 3 · Cold: 9",
            summary: "Loading your projects…",
            mostActive: "voxlight",
            mostUrgent: "audiobook-extractor",
            needsAttention: ["audiobook-extractor", "flora-quest", "algo-trading"],
            hotProjects: ["voxlight", "fire-my-lawyer", "cinder"],
            totalActive: 39,
            totalArchived: 4,
            generatedAt: Date().ISO8601Format()
        ),
        projects: [
            ProjectResponse(id: "1", name: "Voxlight",           heat: "Blazing", dormantDays: 0,  lastCommitDate: nil, stacks: ["Swift"], commitCountLastMonth: 12),
            ProjectResponse(id: "2", name: "Fire My Lawyer",     heat: "Hot",     dormantDays: 2,  lastCommitDate: nil, stacks: ["Swift"], commitCountLastMonth: 7),
            ProjectResponse(id: "3", name: "Cinder",             heat: "Blazing", dormantDays: 0,  lastCommitDate: nil, stacks: ["Swift"], commitCountLastMonth: 8),
            ProjectResponse(id: "4", name: "Claude Relay",       heat: "Hot",     dormantDays: 4,  lastCommitDate: nil, stacks: ["Bun"],   commitCountLastMonth: 3),
            ProjectResponse(id: "5", name: "Bythewei",           heat: "Warm",    dormantDays: 12, lastCommitDate: nil, stacks: ["Astro"], commitCountLastMonth: 2),
            ProjectResponse(id: "6", name: "Babel MCP",          heat: "Cooling", dormantDays: 45, lastCommitDate: nil, stacks: ["Python"], commitCountLastMonth: 0),
            ProjectResponse(id: "7", name: "FloraQuest",         heat: "Cold",    dormantDays: 95, lastCommitDate: nil, stacks: ["Swift"], commitCountLastMonth: 0),
            ProjectResponse(id: "8", name: "Algo Trading",       heat: "Ash",     dormantDays: 200,lastCommitDate: nil, stacks: ["Python"], commitCountLastMonth: 0),
        ],
        fetchedAt: .now
    )
}

// MARK: - Timeline Entry

struct CinderEntry: TimelineEntry {
    let date: Date
    let data: CinderWidgetData
    var isPlaceholder: Bool = false
}

// MARK: - Heat Colour Map (widget-side, no main app dependency)

extension String {
    // Base heat color — used in full-color rendering modes.
    var heatColor: Color {
        switch self {
        case "Blazing": return Color(hue: 0.043, saturation: 0.90, brightness: 1.00)
        case "Hot":     return Color(hue: 0.068, saturation: 0.80, brightness: 1.00)
        case "Warm":    return Color(hue: 0.117, saturation: 0.90, brightness: 1.00)
        case "Cooling": return Color(hue: 0.597, saturation: 0.44, brightness: 0.80)
        case "Cold":    return Color(hue: 0.619, saturation: 0.46, brightness: 0.65)
        case "Ash":     return Color(hue: 0.820, saturation: 0.03, brightness: 0.33)
        default:        return Color(white: 0.4)
        }
    }

    // Rendering-mode-aware heat color.
    // In .accented mode the system tints the widget; use .primary so accented
    // elements read correctly against the system-provided tint background.
    func heatColor(for renderingMode: WidgetRenderingMode) -> Color {
        renderingMode == .accented ? .primary : heatColor
    }

    var heatIcon: String {
        switch self {
        case "Blazing": return "flame.fill"
        case "Hot":     return "flame"
        case "Warm":    return "sparkle"
        case "Cooling": return "wind"
        case "Cold":    return "snowflake"
        case "Ash":     return "moon.fill"
        default:        return "questionmark"
        }
    }

    var heatRank: Int {
        ["Blazing": 0, "Hot": 1, "Warm": 2, "Cooling": 3, "Cold": 4, "Ash": 5][self] ?? 6
    }
}

// Shared colour palette for widgets
extension Color {
    static let widgetBase    = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let widgetSurface = Color(red: 0.13, green: 0.12, blue: 0.14)
    static let widgetMuted   = Color(white: 0.38)
    static let widgetSecond  = Color(white: 0.60)
    static let emberHot      = Color(hue: 0.068, saturation: 0.80, brightness: 1.00)
    static let ashGrey       = Color(hue: 0.820, saturation: 0.03, brightness: 0.33)
}

import SwiftUI

// MARK: - Project Model

struct CinderProject: Identifiable, Hashable {
    let id: String           // based on path
    let name: String
    let path: URL
    let stacks: [TechStack]
    let lastCommitDate: Date?
    let recentCommits: [GitCommit]
    let isGitRepo: Bool
    let commitCountLastMonth: Int

    init(
        name: String,
        path: URL,
        stacks: [TechStack],
        lastCommitDate: Date?,
        recentCommits: [GitCommit],
        isGitRepo: Bool,
        commitCountLastMonth: Int
    ) {
        self.id = path.path
        self.name = name
        self.path = path
        self.stacks = stacks
        self.lastCommitDate = lastCommitDate
        self.recentCommits = recentCommits
        self.isGitRepo = isGitRepo
        self.commitCountLastMonth = commitCountLastMonth
    }

    var dormantDays: Int {
        guard let last = lastCommitDate else { return 999 }
        return Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
    }

    var heat: HeatLevel {
        HeatLevel(dormantDays: dormantDays)
    }

    var momentumLabel: String {
        switch commitCountLastMonth {
        case 0:       return "no recent activity"
        case 1...3:   return "\(commitCountLastMonth) commits / month"
        case 4...15:  return "\(commitCountLastMonth) commits / month"
        default:      return "\(commitCountLastMonth) commits / month 🔥"
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CinderProject, rhs: CinderProject) -> Bool { lhs.id == rhs.id }
}

// MARK: - Git Commit

struct GitCommit: Identifiable, Hashable {
    let id: String  // short hash
    let hash: String
    let message: String
    let date: Date
    let author: String

    var shortMessage: String {
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.count > 72 ? String(m.prefix(69)) + "…" : m
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

// MARK: - Tech Stack

enum TechStack: String, CaseIterable, Hashable, Codable {
    case swift      = "Swift"
    case swiftUI    = "SwiftUI"
    case react      = "React"
    case nextjs     = "Next.js"
    case astro      = "Astro"
    case python     = "Python"
    case typescript = "TypeScript"
    case rust       = "Rust"
    case go         = "Go"
    case node       = "Node"
    case electron   = "Electron"
    case bun        = "Bun"
    case vue        = "Vue"
    case unknown    = "Unknown"

    var icon: String {
        switch self {
        case .swift:      return "swift"
        case .swiftUI:    return "square.stack.3d.up"
        case .react:      return "atom"
        case .nextjs:     return "triangle.fill"
        case .astro:      return "star.fill"
        case .python:     return "chevron.left.forwardslash.chevron.right"
        case .typescript: return "t.square"
        case .rust:       return "gear"
        case .go:         return "hare.fill"
        case .node:       return "server.rack"
        case .electron:   return "desktopcomputer"
        case .bun:        return "bolt.fill"
        case .vue:        return "v.square"
        case .unknown:    return "questionmark.square"
        }
    }
}

// MARK: - Heat Level

enum HeatLevel: Equatable {
    case blazing  // < 3d
    case hot      // 3–7d
    case warm     // 7–30d
    case cooling  // 30–90d
    case cold     // 90–180d
    case ash      // 180d+

    init(dormantDays: Int) {
        switch dormantDays {
        case ..<3:    self = .blazing
        case 3..<7:   self = .hot
        case 7..<30:  self = .warm
        case 30..<90: self = .cooling
        case 90..<180: self = .cold
        default:      self = .ash
        }
    }

    var color: Color {
        switch self {
        case .blazing: return .heatBlazing
        case .hot:     return .heatHot
        case .warm:    return .heatWarm
        case .cooling: return .heatCooling
        case .cold:    return .heatCold
        case .ash:     return .heatAsh
        }
    }

    var icon: String {
        switch self {
        case .blazing: return "flame.fill"
        case .hot:     return "flame"
        case .warm:    return "sparkle"
        case .cooling: return "wind"
        case .cold:    return "snowflake"
        case .ash:     return "cloud.fill"
        }
    }

    var label: String {
        switch self {
        case .blazing: return "Blazing"
        case .hot:     return "Hot"
        case .warm:    return "Warm"
        case .cooling: return "Cooling"
        case .cold:    return "Cold"
        case .ash:     return "Ash"
        }
    }
}

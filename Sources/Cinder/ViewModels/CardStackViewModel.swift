import SwiftUI
import SwiftData

enum DiscoveryMode: String, CaseIterable {
    case discover  = "Discover"
    case hottest   = "Hottest"
    case coldest   = "Coldest"
    case streaking = "Active"
    case graveyard = "Graveyard"
    case stats     = "Stats"
    case gitTree   = "Git Tree"

    var icon: String {
        switch self {
        case .discover:  return "rectangle.stack.fill"
        case .hottest:   return "flame.fill"
        case .coldest:   return "snowflake"
        case .streaking: return "bolt.fill"
        case .graveyard: return "moon.fill"
        case .stats:     return "chart.bar.fill"
        case .gitTree:   return "arrow.triangle.branch"
        }
    }

    var color: Color {
        switch self {
        case .discover:  return .cinderPrimary
        case .hottest:   return .heatHot
        case .coldest:   return .heatCold
        case .streaking: return .reigniteGreen
        case .graveyard: return .cinderMuted
        case .stats:     return .snoozeBlue
        case .gitTree:   return Color(red: 0.55, green: 0.85, blue: 0.55)
        }
    }
}

@Observable
final class CardStackViewModel {
    var allProjects: [CinderProject] = []
    var archivedProjects: [CinderProject] = []
    var snoozedProjects: [CinderProject] = []
    var deck: [CinderProject] = []
    var mode: DiscoveryMode = .discover
    var isLoading: Bool = false
    var lastReignited: CinderProject? = nil
    var showReignitionSheet: Bool = false
    var reignitionCount: Int = 0

    // API server — starts automatically on first configure()
    let apiServer = CinderAPIServer()

    private var swipeRecords: [SwipeRecord] = []
    private var modelContext: ModelContext?

    // MARK: - Setup

    func configure(modelContext: ModelContext, swipeRecords: [SwipeRecord]) {
        self.modelContext = modelContext
        self.swipeRecords = swipeRecords
        // Start API server bound to all interfaces (localhost + Tailscale)
        apiServer.start(viewModel: self)
    }

    // MARK: - Scanning

    @MainActor
    func loadProjects() async {
        isLoading = true
        let scanned = await ProjectScanner.scan()

        // Filter archived / snoozed based on saved swipe records
        let archivedPaths = Set(swipeRecords.filter { $0.direction == .archive }.map(\.projectPath))
        let snoozedMap = Dictionary(uniqueKeysWithValues:
            swipeRecords
                .filter { $0.direction == .snooze }
                .filter { $0.snoozeUntil.map { $0 > .now } ?? false }
                .map { ($0.projectPath, $0.snoozeUntil!) }
        )

        archivedProjects = scanned.filter { archivedPaths.contains($0.id) }
        snoozedProjects  = scanned.filter { snoozedMap[$0.id] != nil }
        allProjects      = scanned.filter { !archivedPaths.contains($0.id) && snoozedMap[$0.id] == nil }

        buildDeck()
        isLoading = false

        // Broadcast project list so the menu bar extra can update its icon
        NotificationCenter.default.post(
            name: .cinderProjectsUpdated,
            object: nil,
            userInfo: ["projects": allProjects]
        )
    }

    func buildDeck() {
        switch mode {
        case .discover:
            deck = allProjects
        case .hottest:
            deck = allProjects.sorted { ($0.lastCommitDate ?? .distantPast) > ($1.lastCommitDate ?? .distantPast) }
        case .coldest:
            deck = allProjects.sorted { ($0.lastCommitDate ?? .distantPast) < ($1.lastCommitDate ?? .distantPast) }
        case .streaking:
            deck = allProjects.filter { $0.commitCountLastMonth > 0 }
                .sorted { $0.commitCountLastMonth > $1.commitCountLastMonth }
        case .graveyard, .stats, .gitTree:
            deck = []
        }
    }

    // MARK: - Swipe Actions

    func reignite(_ project: CinderProject) {
        record(project, direction: .reignite)
        lastReignited = project
        showReignitionSheet = true
        reignitionCount += 1
        removeFromDeck(project)
    }

    func snooze(_ project: CinderProject, days: Int = 7) {
        let until = Calendar.current.date(byAdding: .day, value: days, to: .now)!
        record(project, direction: .snooze, snoozeUntil: until)
        removeFromDeck(project)
    }

    func archive(_ project: CinderProject) {
        record(project, direction: .archive)
        removeFromDeck(project)
        archivedProjects.append(project)
    }

    func unarchive(_ project: CinderProject) {
        guard let ctx = modelContext else { return }
        let path = project.id
        // Remove archive records for this project
        let toDelete = swipeRecords.filter { $0.projectPath == path && $0.direction == .archive }
        toDelete.forEach { ctx.delete($0) }
        try? ctx.save()
        archivedProjects.removeAll { $0.id == path }
        allProjects.append(project)
        buildDeck()
    }

    // MARK: - Helpers

    private func removeFromDeck(_ project: CinderProject) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            deck.removeAll { $0.id == project.id }
            allProjects.removeAll { $0.id == project.id }
        }
    }

    private func record(_ project: CinderProject, direction: SwipeDirection, snoozeUntil: Date? = nil) {
        guard let ctx = modelContext else { return }
        let record = SwipeRecord(
            projectPath: project.id,
            projectName: project.name,
            direction: direction,
            snoozeUntil: snoozeUntil
        )
        ctx.insert(record)
        swipeRecords.append(record)
        try? ctx.save()
    }

    // MARK: - Stats

    var totalReignited: Int {
        swipeRecords.filter { $0.direction == .reignite }.count
    }

    var totalArchived: Int {
        swipeRecords.filter { $0.direction == .archive }.count
    }

    var hotProjects: [CinderProject] {
        allProjects.filter { $0.heat == .blazing || $0.heat == .hot }
    }

    var coldProjects: [CinderProject] {
        allProjects.filter { $0.heat == .cold || $0.heat == .ash }
    }
}

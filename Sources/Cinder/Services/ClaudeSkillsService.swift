import Foundation
import AppKit

// Known Claude Code skills grouped by relevance to project re-entry
struct CinderSkill: Identifiable, Hashable {
    let id: String
    let slash: String       // e.g. "/load"
    let label: String       // display name
    let description: String
    let icon: String        // SF Symbol
    let category: SkillCategory
    let invocation: String  // what gets typed into claude, e.g. "/load"
}

enum SkillCategory: String, CaseIterable {
    case jumpBack  = "Jump Back In"
    case plan      = "Plan"
    case inspect   = "Inspect"
    case ship      = "Ship"
}

struct ClaudeSkillsService {

    static let skills: [CinderSkill] = [
        // Jump Back In
        CinderSkill(
            id: "load",
            slash: "/load",
            label: "Load Context",
            description: "Load full project context and architecture",
            icon: "arrow.down.circle.fill",
            category: .jumpBack,
            invocation: "/load"
        ),
        CinderSkill(
            id: "status",
            slash: "/status",
            label: "Status Check",
            description: "Quick status across all active tasks",
            icon: "checkmark.circle.fill",
            category: .jumpBack,
            invocation: "/status"
        ),
        CinderSkill(
            id: "git",
            slash: "/git",
            label: "Git Workflow",
            description: "Git checkpoint and branch management",
            icon: "arrow.triangle.branch",
            category: .jumpBack,
            invocation: "/git"
        ),
        // Plan
        CinderSkill(
            id: "sprint-plan",
            slash: "/sprint-plan",
            label: "Sprint Plan",
            description: "Plan a development sprint with prioritized tasks",
            icon: "list.bullet.clipboard.fill",
            category: .plan,
            invocation: "/sprint-plan"
        ),
        CinderSkill(
            id: "estimate",
            slash: "/estimate",
            label: "Estimate",
            description: "Project complexity and time estimation",
            icon: "clock.badge.fill",
            category: .plan,
            invocation: "/estimate"
        ),
        CinderSkill(
            id: "scope-check",
            slash: "/scope-check",
            label: "Scope Check",
            description: "Evaluate if a feature idea is worth building now",
            icon: "checkmark.seal.fill",
            category: .plan,
            invocation: "/scope-check"
        ),
        // Inspect
        CinderSkill(
            id: "analyze",
            slash: "/analyze",
            label: "Analyze",
            description: "Multi-dimensional code and system analysis",
            icon: "magnifyingglass.circle.fill",
            category: .inspect,
            invocation: "/analyze"
        ),
        CinderSkill(
            id: "troubleshoot",
            slash: "/troubleshoot",
            label: "Troubleshoot",
            description: "Professional debugging and issue resolution",
            icon: "wrench.and.screwdriver.fill",
            category: .inspect,
            invocation: "/troubleshoot"
        ),
        CinderSkill(
            id: "scan",
            slash: "/scan",
            label: "Security Scan",
            description: "Security audit and vulnerability check",
            icon: "shield.lefthalf.filled",
            category: .inspect,
            invocation: "/scan"
        ),
        // Ship
        CinderSkill(
            id: "test",
            slash: "/test",
            label: "Run Tests",
            description: "Comprehensive testing framework",
            icon: "testtube.2",
            category: .ship,
            invocation: "/test"
        ),
        CinderSkill(
            id: "ship-check",
            slash: "/ship-check",
            label: "Ship Check",
            description: "Pre-launch checklist before shipping",
            icon: "airplane.departure",
            category: .ship,
            invocation: "/ship-check"
        ),
        CinderSkill(
            id: "end-of-day",
            slash: "/end-of-day",
            label: "End of Day",
            description: "Commit summary, sprint board update, recap",
            icon: "moon.stars.fill",
            category: .ship,
            invocation: "/end-of-day"
        ),
    ]

    static func skillsFor(category: SkillCategory) -> [CinderSkill] {
        skills.filter { $0.category == category }
    }

    // MARK: - Launch in Terminal

    /// Opens a new Terminal window, cds into the project, then types `claude <invocation>`
    static func launch(_ skill: CinderSkill, in project: CinderProject) {
        // Escape path for AppleScript string literal — only double-quotes and backslashes need escaping
        let safePath = project.path.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        // skill.invocation is a static constant from ClaudeSkill enum — safe to interpolate
        let cmd = "claude \(skill.invocation)"
        let script = """
        tell application "Terminal"
            activate
            do script "cd \\\"\(safePath)\\\" && \(cmd)"
        end tell
        """
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    /// Opens a new Terminal window in the project directory (no skill)
    static func openTerminal(in project: CinderProject) {
        let safePath = project.path.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "cd \\\"\(safePath)\\\""
        end tell
        """
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    /// Opens the project in VS Code
    static func openVSCode(in project: CinderProject) {
        let codePaths = ["/opt/homebrew/bin/code", "/usr/local/bin/code"]
        for codePath in codePaths {
            if FileManager.default.fileExists(atPath: codePath) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: codePath)
                p.arguments = [project.path.path]
                try? p.run()
                return
            }
        }
        // Fallback: open in Finder
        NSWorkspace.shared.open(project.path)
    }
}

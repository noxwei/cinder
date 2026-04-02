import SwiftUI

struct ReignitionView: View {
    let project: CinderProject
    @Binding var isPresented: Bool

    @State private var selectedSkillCategory: SkillCategory = .jumpBack

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(28)

            Divider().background(Color.cinderBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    lastStateSection

                    if !project.recentCommits.isEmpty {
                        commitsSection
                    }

                    quickOpenSection

                    Divider().background(Color.cinderBorder)

                    // ── Skills Launcher ──
                    skillsSection
                }
                .padding(28)
            }
        }
        .frame(width: 560, height: 640)
        .background(Color.cinderBase)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.heatHot)
                    Text("Reignited")
                        .font(.title3.bold())
                        .foregroundStyle(.heatHot)
                }
                Text(project.name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.cinderPrimary)
                if !project.stacks.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(project.stacks, id: \.self) { StackBadge(stack: $0) }
                    }
                }
            }
            Spacer()
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.cinderMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
    }

    // MARK: - Last State

    private var lastStateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Where You Left Off")

            InfoRow(icon: "clock.fill", color: .heatWarm, label: "Dormant for") {
                Text(dormantString).foregroundStyle(.cinderPrimary)
            }
            InfoRow(icon: "calendar", color: .snoozeBlue, label: "Last commit") {
                if let date = project.lastCommitDate {
                    Text(date, style: .date).foregroundStyle(.cinderPrimary)
                    + Text(" · ").foregroundStyle(.cinderMuted)
                    + Text(date, style: .time).foregroundStyle(.cinderMuted)
                } else {
                    Text("Unknown").foregroundStyle(.cinderMuted)
                }
            }
            InfoRow(icon: "chart.line.uptrend.xyaxis", color: .reigniteGreen, label: "Momentum") {
                Text(project.momentumLabel).foregroundStyle(.cinderPrimary)
            }
        }
        .padding(16)
        .background(Color.cinderCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Commits

    private var commitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Recent Commits")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(project.recentCommits) { commit in
                    HStack(alignment: .top, spacing: 10) {
                        Text(commit.hash)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.heatWarm)
                            .frame(width: 52, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(commit.shortMessage)
                                .font(.callout)
                                .foregroundStyle(.cinderPrimary)
                            Text(commit.relativeDate)
                                .font(.caption2)
                                .foregroundStyle(.cinderMuted)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cinderCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quick Open

    private var quickOpenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Open Project")
            HStack(spacing: 12) {
                quickOpenButton(icon: "folder.fill",             label: "Finder",    color: .snoozeBlue)   { NSWorkspace.shared.open(project.path) }
                quickOpenButton(icon: "chevron.left.forwardslash.chevron.right", label: "VS Code", color: .reigniteGreen) { ClaudeSkillsService.openVSCode(in: project) }
                quickOpenButton(icon: "terminal.fill",           label: "Terminal",  color: .heatWarm)     { ClaudeSkillsService.openTerminal(in: project) }
            }
        }
    }

    // MARK: - Skills Launcher

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeader("Launch with Claude Code")
                Spacer()
                Text("Opens Terminal → runs claude <skill>")
                    .font(.caption2)
                    .foregroundStyle(.cinderMuted)
            }

            // Category picker
            Picker("Category", selection: $selectedSkillCategory) {
                ForEach(SkillCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Skills grid
            let skills = ClaudeSkillsService.skillsFor(category: selectedSkillCategory)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(skills) { skill in
                    SkillButton(skill: skill) {
                        ClaudeSkillsService.launch(skill, in: project)
                        isPresented = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.cinderMuted)
            .tracking(1.2)
            .textCase(.uppercase)
    }

    private func quickOpenButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.cinderSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cinderCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var dormantString: String {
        let d = project.dormantDays
        if d == 0 { return "Active today" }
        if d == 1 { return "1 day" }
        if d < 30 { return "\(d) days" }
        let m = d / 30
        return m == 1 ? "1 month" : "\(m) months"
    }
}

// MARK: - Skill Button

struct SkillButton: View {
    let skill: CinderSkill
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: skill.icon)
                    .font(.callout)
                    .foregroundStyle(.heatHot)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(skill.label)
                            .font(.callout.bold())
                            .foregroundStyle(.cinderPrimary)
                        Text(skill.slash)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.heatWarm.opacity(0.8))
                    }
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.cinderSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "terminal.fill")
                    .font(.caption2)
                    .foregroundStyle(.cinderMuted)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.cinderCardHover : Color.cinderCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isHovered ? Color.heatHot.opacity(0.3) : Color.cinderBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityLabel("Launch \(skill.label) skill in Terminal")
        .accessibilityHint(skill.description)
    }
}

// MARK: - Info Row

struct InfoRow<Content: View>: View {
    let icon: String
    let color: Color
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(label)
                .foregroundStyle(.cinderSecondary)
                .font(.callout)
            Spacer()
            content()
                .font(.callout)
        }
    }
}

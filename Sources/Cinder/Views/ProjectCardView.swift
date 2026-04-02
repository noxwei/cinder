import SwiftUI

struct ProjectCardView: View {
    let project: CinderProject

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heatBanner

            VStack(alignment: .leading, spacing: 16) {
                // Title + git indicator
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.title2.bold())
                            .foregroundStyle(.cinderPrimary)
                            .lineLimit(2)

                        Text(project.path.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.cinderMuted)
                            .monospaced()
                    }
                    Spacer()
                    if !project.isGitRepo {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.heatWarm)
                            .accessibilityLabel("Not a git repository")
                    }
                }

                if !project.stacks.isEmpty {
                    stackBadges
                }

                Divider()
                    .background(Color.cinderBorder)

                commitsSection

                footerBar
            }
            .padding(20)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // Ember glow effect for hot/blazing projects — shadow-based, not glass (per HIG: glass on nav layer only)
        .shadow(
            color: emberGlowColor,
            radius: 16,
            x: 0, y: 4
        )
    }

    // MARK: - Heat Banner

    private var heatBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: project.heat.icon)
                .font(.caption.bold())
            Text(project.heat.label.uppercased())
                .font(.caption.bold())
                .tracking(1.5)
            Spacer()
            Text(dormantText)
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [project.heat.color, project.heat.color.opacity(0.65)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var dormantText: String {
        let days = project.dormantDays
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 30 { return "\(days)d ago" }
        let months = days / 30
        return months == 1 ? "1 month ago" : "\(months) months ago"
    }

    // MARK: - Stack Badges

    private var stackBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(project.stacks, id: \.self) { stack in
                    StackBadge(stack: stack)
                }
            }
        }
    }

    // MARK: - Commits

    @ViewBuilder
    private var commitsSection: some View {
        if project.recentCommits.isEmpty {
            HStack {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.cinderMuted)
                Text(project.isGitRepo ? "No commits found" : "No git history")
                    .foregroundStyle(.cinderMuted)
                    .font(.callout)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent commits")
                    .font(.caption.bold())
                    .foregroundStyle(.cinderMuted)
                    .tracking(1)
                    .textCase(.uppercase)

                ForEach(project.recentCommits) { commit in
                    CommitRow(commit: commit)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Label(project.momentumLabel, systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(project.commitCountLastMonth > 5 ? Color.reigniteGreen : .cinderMuted)

            Spacer()

            if let date = project.lastCommitDate {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.cinderMuted)
            }
        }
    }

    // MARK: - Background & Glow

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.cinderCard)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(heatBorderColor, lineWidth: 1)
            )
    }

    private var heatBorderColor: Color {
        switch project.heat {
        case .blazing: return Color.heatBlazing.opacity(0.45)
        case .hot:     return Color.heatHot.opacity(0.30)
        case .warm:    return Color.heatWarm.opacity(0.20)
        default:       return Color.cinderBorder
        }
    }

    private var emberGlowColor: Color {
        switch project.heat {
        case .blazing: return Color.heatBlazing.opacity(0.25)
        case .hot:     return Color.heatHot.opacity(0.18)
        default:       return Color.black.opacity(0.35)
        }
    }
}

// MARK: - Stack Badge

struct StackBadge: View {
    let stack: TechStack

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: stack.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(stack.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(stack.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(stack.color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(stack.color.opacity(0.25), lineWidth: 0.5))
    }
}

// MARK: - Commit Row

struct CommitRow: View {
    let commit: GitCommit

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(commit.hash)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.heatWarm.opacity(0.8))
                .frame(width: 48, alignment: .leading)

            Text(commit.shortMessage)
                .font(.callout)
                .foregroundStyle(.cinderPrimary)
                .lineLimit(1)

            Spacer()

            Text(commit.relativeDate)
                .font(.caption2)
                .foregroundStyle(.cinderMuted)
        }
    }
}

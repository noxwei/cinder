import SwiftUI

struct StatsView: View {
    @Bindable var viewModel: CardStackViewModel

    var body: some View {
        ZStack {
            Color.cinderBase.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    statsGrid

                    heatDistribution

                    if !viewModel.hotProjects.isEmpty {
                        projectList(
                            icon: "flame.fill", iconColor: .heatHot,
                            title: "Hottest Projects",
                            projects: viewModel.hotProjects
                        )
                    }

                    if !viewModel.coldProjects.isEmpty {
                        projectList(
                            icon: "snowflake", iconColor: .heatCold,
                            title: "Needs Attention",
                            projects: viewModel.coldProjects
                        )
                    }
                }
                .padding(32)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Stats")
                .font(.title2.bold())
                .foregroundStyle(.cinderPrimary)
            Text("Your project activity at a glance")
                .font(.callout)
                .foregroundStyle(.cinderSecondary)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            StatCard(value: "\(viewModel.allProjects.count)", label: "Active Projects",  icon: "folder.fill",                    color: .snoozeBlue)
            StatCard(value: "\(viewModel.hotProjects.count)",   label: "Hot Right Now",  icon: "flame.fill",                     color: .heatHot)
            StatCard(value: "\(viewModel.totalReignited)",      label: "Reignited",      icon: "arrow.clockwise.circle.fill",    color: .reigniteGreen)
            StatCard(value: "\(viewModel.archivedProjects.count)", label: "Archived",   icon: "archivebox.fill",                color: .archiveGrey)
        }
    }

    private var heatDistribution: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Heat Distribution")
                .font(.headline)
                .foregroundStyle(.cinderPrimary)

            VStack(spacing: 8) {
                ForEach([HeatLevel.blazing, .hot, .warm, .cooling, .cold, .ash], id: \.label) { level in
                    let count = viewModel.allProjects.filter { $0.heat == level }.count
                    if count > 0 {
                        HeatBar(level: level, count: count, total: max(1, viewModel.allProjects.count))
                    }
                }
            }
        }
        .padding(20)
        .background(Color.cinderCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func projectList(icon: String, iconColor: Color, title: String, projects: [CinderProject]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.cinderPrimary)
                .labelStyle(TintedIconLabelStyle(color: iconColor))

            VStack(spacing: 8) {
                ForEach(projects.prefix(5)) { project in
                    HStack(spacing: 12) {
                        Image(systemName: project.heat.icon)
                            .foregroundStyle(project.heat.color)
                            .frame(width: 20)
                            .accessibilityHidden(true)

                        Text(project.name)
                            .font(.callout)
                            .foregroundStyle(.cinderPrimary)
                            .lineLimit(1)

                        Spacer()

                        if let date = project.lastCommitDate {
                            Text(date, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.cinderMuted)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.cinderSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(20)
        .background(Color.cinderCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Spacer()
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.cinderPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.cinderSecondary)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(Color.cinderCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Heat Bar

struct HeatBar: View {
    let level: HeatLevel
    let count: Int
    let total: Int

    private var fraction: CGFloat { CGFloat(count) / CGFloat(total) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: level.icon)
                .foregroundStyle(level.color)
                .frame(width: 16)
                .accessibilityHidden(true)

            Text(level.label)
                .font(.callout)
                .foregroundStyle(.cinderSecondary)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level.color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level.color.opacity(0.7))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 8)

            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.cinderMuted)
                .frame(width: 24, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.label): \(count) projects")
    }
}

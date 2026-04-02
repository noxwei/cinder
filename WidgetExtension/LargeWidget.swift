import WidgetKit
import SwiftUI

// MARK: - Large Widget (4×4)
// All projects as animated squares — hottest top-left, ash bottom-right.

struct LargeWidget: Widget {
    static let kind = "CinderLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CinderProvider()) { entry in
            LargeWidgetView(entry: entry)
                .containerBackground(.widgetBase, for: .widget)
        }
        .configurationDisplayName("Cinder Grid")
        .description("All projects arranged by heat — hottest first.")
        .supportedFamilies([.systemLarge])
    }
}

struct LargeWidgetView: View {
    let entry: CinderEntry

    // Max 24 projects in the grid
    private var grid: [ProjectResponse] {
        Array(entry.data.projects.prefix(24))
    }

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.emberHot)
                    .shadow(color: .emberHot.opacity(0.5), radius: 4)
                Text("Cinder")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(entry.data.digest.totalActive) projects")
                    .font(.caption)
                    .foregroundStyle(.widgetMuted)
            }

            // Grid
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(grid, id: \.id) { project in
                    GridSquare(project: project)
                }
            }

            // Summary footer
            HStack(spacing: 8) {
                heatPill("flame.fill", entry.data.digest.hotProjects.count, .emberHot)
                heatPill("snowflake", entry.data.digest.needsAttention.count,
                         Color(red: 0.35, green: 0.45, blue: 0.65))
                Spacer()
                if let urgent = entry.data.digest.mostUrgent {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.widgetMuted)
                        Text(urgent)
                            .font(.caption2)
                            .foregroundStyle(.widgetMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
    }

    private func heatPill(_ icon: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

struct GridSquare: View {
    let project: ProjectResponse
    @State private var isHovered = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(project.heat.heatColor.opacity(isHovered ? 0.35 : 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(project.heat.heatColor.opacity(0.4), lineWidth: 0.5)
                )

            Image(systemName: project.heat.heatIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(project.heat.heatColor)
        }
        .frame(height: 32)
        .help(project.name + " · " + project.heat + " · \(project.dormantDays)d")
        .onHover { isHovered = $0 }
    }
}

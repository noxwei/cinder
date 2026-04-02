import WidgetKit
import SwiftUI

// MARK: - Large Widget (4x4) + Extra Large (macOS desktop)
// All projects as squares — hottest top-left, ash bottom-right.

struct LargeWidget: Widget {
    static let kind = "CinderLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CinderProvider()) { entry in
            LargeWidgetView(entry: entry)
                .containerBackground(.widgetBase, for: .widget)
        }
        .configurationDisplayName("Cinder Grid")
        .description("All projects arranged by heat — hottest first.")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}

struct LargeWidgetView: View {
    let entry: CinderEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    // Extra large shows more projects; large caps at 24.
    private var grid: [ProjectResponse] {
        let limit = family == .systemExtraLarge ? 48 : 24
        return Array(entry.data.projects.prefix(limit))
    }

    // Extra large uses more columns to fill the wider canvas.
    private var columnCount: Int {
        family == .systemExtraLarge ? 10 : 6
    }

    private var cols: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: columnCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(renderingMode == .accented ? .primary : .emberHot)
                    .shadow(color: renderingMode == .accented ? .clear : Color.emberHot.opacity(0.5), radius: 4)
                    .widgetAccentable()
                Text("Cinder")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .widgetAccentable()
                Spacer()
                Text("\(entry.data.digest.totalActive) projects")
                    .font(.caption)
                    .foregroundStyle(.widgetMuted)
            }

            // Grid
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(grid, id: \.id) { project in
                    GridSquare(project: project, renderingMode: renderingMode)
                }
            }

            // Summary footer
            HStack(spacing: 8) {
                heatPill(
                    "flame.fill",
                    entry.data.digest.hotProjects.count,
                    renderingMode == .accented ? .primary : .emberHot
                )
                heatPill(
                    "snowflake",
                    entry.data.digest.needsAttention.count,
                    renderingMode == .accented
                        ? .secondary
                        : Color(hue: 0.619, saturation: 0.46, brightness: 0.65)
                )
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
        .widgetAccentable()
    }
}

struct GridSquare: View {
    let project: ProjectResponse
    var renderingMode: WidgetRenderingMode = .fullColor
    @State private var isHovered = false

    private var tileColor: Color {
        project.heat.heatColor(for: renderingMode)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(renderingMode == .accented
                      ? Color.primary.opacity(isHovered ? 0.25 : 0.12)
                      : project.heat.heatColor.opacity(isHovered ? 0.35 : 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(tileColor.opacity(0.4), lineWidth: 0.5)
                )

            Image(systemName: project.heat.heatIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tileColor)
                .widgetAccentable()
        }
        .frame(height: 32)
        .help(project.name + " · " + project.heat + " · \(project.dormantDays)d")
        .onHover { isHovered = $0 }
    }
}

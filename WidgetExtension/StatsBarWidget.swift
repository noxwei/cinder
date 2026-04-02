import WidgetKit
import SwiftUI

// MARK: - Stats Bar Widget
// Ultra minimal. Just numbers across one line.
// 🔥3  🟡4  🟢2  🔵3  💀2
// Accessory rect / lock screen / system small variants.

struct StatsBarWidget: Widget {
    static let kind = "CinderStatsBar"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CinderProvider()) { entry in
            StatsBarWidgetView(entry: entry)
                .containerBackground(.widgetBase, for: .widget)
        }
        .configurationDisplayName("Stats Bar")
        .description("Heat breakdown at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct StatsBarWidgetView: View {
    let entry: CinderEntry

    // Counts per heat tier
    private var counts: [(icon: String, color: Color, count: Int)] {
        let projects = entry.data.projects
        return [
            ("flame.fill",   .emberHot,                       projects.filter { $0.heat == "Blazing" }.count),
            ("flame",        Color(red: 1.0, green: 0.6, blue: 0.2), projects.filter { $0.heat == "Hot" }.count),
            ("thermometer.medium", Color(red: 0.9, green: 0.8, blue: 0.3), projects.filter { $0.heat == "Warm" }.count),
            ("snowflake",    Color(red: 0.35, green: 0.45, blue: 0.65), projects.filter { $0.heat == "Cold" || $0.heat == "Cooling" }.count),
            ("moon.fill",    Color.ashGrey,                   projects.filter { $0.heat == "Ash" }.count),
        ].filter { $0.count > 0 }
    }

    var body: some View {
        smallView
    }

    // MARK: Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("CINDER")
                .font(.system(size: 9, weight: .black))
                .tracking(1.8)
                .foregroundStyle(Color.widgetMuted)

            Spacer()

            // Heat grid — 2×3 or flex layout
            VStack(alignment: .leading, spacing: 8) {
                ForEach(counts.indices, id: \.self) { i in
                    let item = counts[i]
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(item.color)
                            .frame(width: 14)

                        Text("\(item.count)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(heatLabel(for: i))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.widgetMuted)
                    }
                }
            }

            Spacer()

            // Total
            Text("\(entry.data.digest.totalActive) total")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(white: 0.25))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func heatLabel(for index: Int) -> String {
        let labels = ["blazing", "hot", "warm", "cold", "ash"]
        return index < labels.count ? labels[index] : ""
    }
}

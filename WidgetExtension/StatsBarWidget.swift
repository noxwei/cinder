import WidgetKit
import SwiftUI

// MARK: - Stats Bar Widget
// Ultra minimal. Just numbers across one line.
// Accessory rect / lock screen / system small variants.

struct StatsBarWidget: Widget {
    static let kind = "CinderStatsBar"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CinderProvider()) { entry in
            StatsBarWidgetView(entry: entry)
                .containerBackground(Color.widgetBase, for: .widget)
        }
        .configurationDisplayName("Stats Bar")
        .description("Heat breakdown at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct StatsBarWidgetView: View {
    let entry: CinderEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    // Heat tier definitions — colors adapt to rendering mode
    private struct HeatTier {
        let icon: String
        let baseColor: Color
        let label: String
        let count: Int
    }

    private var tiers: [HeatTier] {
        let projects = entry.data.projects
        return [
            HeatTier(icon: "flame.fill",         baseColor: Color.emberHot,
                     label: "blazing", count: projects.filter { $0.heat == "Blazing" }.count),
            HeatTier(icon: "flame",               baseColor: Color(hue: 0.068, saturation: 0.80, brightness: 1.00),
                     label: "hot",     count: projects.filter { $0.heat == "Hot" }.count),
            HeatTier(icon: "thermometer.medium",  baseColor: Color(hue: 0.117, saturation: 0.90, brightness: 1.00),
                     label: "warm",    count: projects.filter { $0.heat == "Warm" }.count),
            HeatTier(icon: "snowflake",            baseColor: Color(hue: 0.619, saturation: 0.46, brightness: 0.65),
                     label: "cold",    count: projects.filter { $0.heat == "Cold" || $0.heat == "Cooling" }.count),
            HeatTier(icon: "moon.fill",            baseColor: Color.ashGrey,
                     label: "ash",     count: projects.filter { $0.heat == "Ash" }.count),
        ].filter { $0.count > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("CINDER")
                .font(.system(size: 9, weight: .black))
                .tracking(1.8)
                .foregroundStyle(Color.widgetMuted)

            Spacer()

            // Heat grid
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tiers.indices, id: \.self) { i in
                    let tier = tiers[i]
                    let displayColor = renderingMode == .accented ? Color.primary : tier.baseColor
                    HStack(spacing: 6) {
                        Image(systemName: tier.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(displayColor)
                            .frame(width: 14)
                            .widgetAccentable()

                        Text("\(tier.count)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .widgetAccentable()

                        Text(tier.label)
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
}

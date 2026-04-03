import WidgetKit
import SwiftUI

// MARK: - Small Widget (2x2)
// Single hottest project — name, heat dot, dormant days. Glanceable.

struct SmallWidget: Widget {
    static let kind = "CinderSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CinderProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(Color.widgetBase, for: .widget)
        }
        .configurationDisplayName("Hottest Project")
        .description("Your most active project at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct SmallWidgetView: View {
    let entry: CinderEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var top: ProjectResponse? {
        entry.data.projects.first
    }

    var body: some View {
        ZStack {
            // Heat-tinted background glow — suppressed in accented mode
            if renderingMode != .accented, let p = top {
                RadialGradient(
                    colors: [p.heat.heatColor.opacity(0.22), Color.widgetBase],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 120
                )
            }

            VStack(alignment: .leading, spacing: 0) {
                // Heat badge
                HStack(spacing: 5) {
                    Image(systemName: top?.heat.heatIcon ?? "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(top?.heat.heatColor(for: renderingMode) ?? .primary)
                    Text((top?.heat ?? "–").uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(top?.heat.heatColor(for: renderingMode) ?? .primary)
                }
                .widgetAccentable()
                .padding(.bottom, 6)

                Spacer()

                // Project name
                Text(top?.name ?? "No projects")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .widgetAccentable()

                // Dormant days
                Text(dormantLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.widgetSecond)
                    .padding(.top, 3)

                // Stacks
                if let stacks = top?.stacks.prefix(2) {
                    HStack(spacing: 4) {
                        ForEach(Array(stacks), id: \.self) { s in
                            Text(s)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.widgetMuted)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.widgetSurface)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
        }
    }

    private var dormantLabel: String {
        guard let d = top?.dormantDays else { return "–" }
        if d == 0 { return "active today" }
        if d == 1 { return "1 day ago" }
        return "\(d)d dormant"
    }
}

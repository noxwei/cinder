import WidgetKit
import SwiftUI

// MARK: - Graveyard Widget
// Ash projects only. Shame-based motivation.

struct GraveyardWidget: Widget {
    static let kind = "CinderGraveyard"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CinderProvider()) { entry in
            GraveyardWidgetView(entry: entry)
                // Dark near-black background to reinforce the graveyard aesthetic.
                // Color.clear would let Liquid Glass through, but the dark tone is
                // intentional here — it reads as a distinct design choice, not a bug.
                .containerBackground(Color(red: 0.06, green: 0.05, blue: 0.07), for: .widget)
        }
        .configurationDisplayName("Graveyard")
        .description("Ash projects. Shame-based motivation.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GraveyardWidgetView: View {
    let entry: CinderEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var ashProjects: [ProjectResponse] {
        entry.data.projects.filter { $0.heat == "Ash" }
    }

    private var ashCount: Int { ashProjects.count }

    // Shame copy rotates deterministically on day of year
    private var shameText: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let lines = [
            "still there.",
            "collecting dust.",
            "waiting.",
            "they remember you.",
            "it compiles, somewhere.",
            "not today either.",
            "the void stares back.",
            "git log says it all.",
        ]
        return lines[day % lines.count]
    }

    // Ash color adapts to rendering mode
    private var ashColor: Color {
        renderingMode == .accented ? .primary : Color.ashGrey
    }

    var body: some View {
        if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }

    // MARK: Small — just the number + tombstone

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ashColor)
                Text("GRAVEYARD")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(ashColor)
            }
            .widgetAccentable()

            Spacer()

            Text("\(ashCount)")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .widgetAccentable()

            Text(ashCount == 1 ? "project" : "projects")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ashColor)

            Text(shameText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(white: 0.3))
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium — number + list of ash project names

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left — big number
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.fill")
                        .font(.caption.bold())
                        .foregroundStyle(ashColor)
                    Text("GRAVEYARD")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(ashColor)
                }
                .widgetAccentable()

                Spacer()

                Text("\(ashCount)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.4)
                    .widgetAccentable()

                Text(shameText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(white: 0.28))
            }
            .frame(maxWidth: 80)

            Divider()
                .background(Color(white: 0.15))

            // Right — project list
            VStack(alignment: .leading, spacing: 5) {
                ForEach(ashProjects.prefix(5), id: \.id) { project in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(ashColor.opacity(0.5))
                            .frame(width: 5, height: 5)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(project.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(white: 0.5))
                                .lineLimit(1)
                            Text("\(project.dormantDays)d dormant")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color(white: 0.28))
                        }
                    }
                }

                if ashProjects.count > 5 {
                    Text("+ \(ashProjects.count - 5) more")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.25))
                        .padding(.top, 2)
                }

                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

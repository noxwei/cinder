import WidgetKit
import SwiftUI

// MARK: - Nudge Widget
// "What should I work on today?" — project tarot card.
// Rotates through cold/cooling projects deterministically by day.
// Shame-adjacent but gentler: curiosity over guilt.

struct NudgeWidget: Widget {
    static let kind = "CinderNudge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CinderProvider()) { entry in
            NudgeWidgetView(entry: entry)
                .containerBackground(Color.widgetBase, for: .widget)
        }
        .configurationDisplayName("Daily Nudge")
        .description("One cold project to revisit today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NudgeWidgetView: View {
    let entry: CinderEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
    }

    // Pick a cold/cooling project for today — deterministic by day of year
    private var pick: ProjectResponse? {
        let candidates = entry.data.projects.filter {
            $0.heat == "Cold" || $0.heat == "Cooling"
        }
        guard !candidates.isEmpty else { return nil }
        return candidates[dayOfYear % candidates.count]
    }

    // Rotating nudge prompts — tarot-card energy
    private var nudgePrompt: String {
        let day = dayOfYear
        let prompts = [
            "revisit today?",
            "one commit.",
            "still interesting?",
            "open it up.",
            "just look.",
            "30 minutes.",
            "what was the plan?",
            "it remembers you.",
            "pick it up.",
            "why did you stop?",
            "one file.",
            "dust it off.",
        ]
        return prompts[day % prompts.count]
    }

    var body: some View {
        if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }

    // MARK: Small — card + project name + prompt

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.widgetMuted)
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.widgetMuted)
            }

            Spacer()

            if let p = pick {
                // Heat indicator
                HStack(spacing: 4) {
                    Image(systemName: p.heat.heatIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(p.heat.heatColor(for: renderingMode))
                    Text(p.heat.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(p.heat.heatColor(for: renderingMode))
                }
                .widgetAccentable()
                .padding(.bottom, 4)

                Text(p.name)
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .widgetAccentable()

                Text(nudgePrompt)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
                    .padding(.top, 3)

                Text("\(p.dormantDays)d dormant")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.widgetMuted)
                    .padding(.top, 1)
            } else {
                Text("All fires burning.")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Nothing cold today.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.widgetMuted)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium — card + stacks + recent context

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left — tarot card feel
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(Color.widgetMuted)
                    Text("NUDGE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.widgetMuted)
                }

                Spacer()

                if let p = pick {
                    Text(p.name)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .widgetAccentable()

                    HStack(spacing: 4) {
                        Image(systemName: p.heat.heatIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(p.heat.heatColor(for: renderingMode))
                        Text(p.heat)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(p.heat.heatColor(for: renderingMode))
                    }
                    .widgetAccentable()
                    .padding(.top, 2)
                } else {
                    Text("All fires\nburning.")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: 110)

            Divider()
                .background(Color(white: 0.15))

            // Right — detail + stacks + nudge
            VStack(alignment: .leading, spacing: 6) {
                if let p = pick {
                    Text(nudgePrompt)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color(white: 0.4))

                    Divider()
                        .background(Color(white: 0.12))

                    Label("\(p.dormantDays) days dormant", systemImage: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.widgetMuted)

                    if !p.stacks.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(p.stacks.prefix(3), id: \.self) { stack in
                                Text(stack)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.widgetMuted)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(white: 0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Text("tap to open cinder")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.2))
                } else {
                    Text("No cold projects.\nAll good.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.widgetMuted)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

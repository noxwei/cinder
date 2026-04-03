import WidgetKit
import SwiftUI

// MARK: - Medium Widget (4x2)
// Top 5 projects as heat-coloured Cinder squares + summary line.

struct MediumWidget: Widget {
    static let kind = "CinderMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CinderProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(Color.widgetBase, for: .widget)
        }
        .configurationDisplayName("Heat Row")
        .description("Top 5 projects as heat-coloured squares.")
        .supportedFamilies([.systemMedium])
    }
}

struct MediumWidgetView: View {
    let entry: CinderEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var topFive: [ProjectResponse] {
        Array(entry.data.projects.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Summary line
            HStack(spacing: 0) {
                summaryChip(
                    icon: "flame.fill",
                    value: "\(entry.data.digest.hotProjects.count)",
                    label: "blazing",
                    color: renderingMode == .accented ? .primary : Color.emberHot
                )
                Text(" · ")
                    .foregroundStyle(.widgetMuted)
                    .font(.caption)
                summaryChip(
                    icon: "snowflake",
                    value: "\(entry.data.digest.needsAttention.count)",
                    label: "cold",
                    color: renderingMode == .accented
                        ? .secondary
                        : Color(hue: 0.619, saturation: 0.46, brightness: 0.65)
                )
                Spacer()
                Text("\u{21BB} " + refreshAge)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.widgetMuted)
            }
            .widgetAccentable()

            // Heat squares row
            HStack(spacing: 8) {
                ForEach(topFive, id: \.id) { project in
                    CinderSquare(project: project, showName: true, renderingMode: renderingMode)
                }
                // Fill empty slots
                if topFive.count < 5 {
                    ForEach(0..<(5 - topFive.count), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.widgetSurface)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                }
            }
        }
        .padding(14)
    }

    private func summaryChip(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text("\(value) \(label)")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }

    private var refreshAge: String {
        let mins = Int(Date().timeIntervalSince(entry.data.fetchedAt) / 60)
        if mins < 1 { return "just now" }
        return "\(mins)m ago"
    }
}

// Reusable heat square used in medium + large widgets
struct CinderSquare: View {
    let project: ProjectResponse
    var showName: Bool = false
    var size: CGFloat = 0   // 0 = flexible
    var renderingMode: WidgetRenderingMode = .fullColor

    private var tileColor: Color {
        project.heat.heatColor(for: renderingMode)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(renderingMode == .accented
                          ? Color.primary.opacity(0.15)
                          : project.heat.heatColor.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(tileColor.opacity(0.45), lineWidth: 1)
                    )

                VStack(spacing: 3) {
                    Image(systemName: project.heat.heatIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tileColor)
                        .widgetAccentable()

                    if project.dormantDays > 0 {
                        Text("\(project.dormantDays)d")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(tileColor.opacity(0.8))
                            .widgetAccentable()
                    } else {
                        Text("now")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(tileColor.opacity(0.8))
                            .widgetAccentable()
                    }
                }
            }
            .frame(maxWidth: size > 0 ? size : .infinity, minHeight: size > 0 ? size : 56)

            if showName {
                Text(project.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.widgetSecond)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

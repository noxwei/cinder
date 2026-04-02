import SwiftUI

// MARK: - Cinder Tray View
// The popover panel that drops down from the menu bar icon.
// Heat breakdown + recent activity + quick "open Cinder" button.

struct CinderTrayView: View {
    let projects: [CinderProject]

    // Heat breakdown
    private var blazing: [CinderProject] { projects.filter { $0.heat == .blazing } }
    private var hot:     [CinderProject] { projects.filter { $0.heat == .hot } }
    private var warm:    [CinderProject] { projects.filter { $0.heat == .warm } }
    private var cold:    [CinderProject] { projects.filter { $0.heat == .cold || $0.heat == .cooling } }
    private var ash:     [CinderProject] { projects.filter { $0.heat == .ash } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider().opacity(0.12)
                heatBars
                Divider().opacity(0.12)
                projectList
                Divider().opacity(0.12)
                footer
            }
        }
        .frame(width: 320, height: 480)
        .background(Color(hex: "#121014"))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#FF6D1A"))
                .shadow(color: Color(hex: "#FF6D1A").opacity(0.5), radius: 4)
            Text("Cinder")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(projects.count) projects")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Heat Bar Summary

    private var heatBars: some View {
        VStack(spacing: 6) {
            heatRow("flame.fill",     "Blazing",  blazing.count, Color(hex: "#FF4500"))
            heatRow("flame",          "Hot",      hot.count,     Color(hex: "#FF7A1A"))
            heatRow("thermometer.medium", "Warm", warm.count,    Color(hex: "#FFB81A"))
            heatRow("snowflake",      "Cold",     cold.count,    Color(hex: "#4D8CFF"))
            heatRow("moon.fill",      "Ash",      ash.count,     Color(hex: "#58535A"))
        }
        .padding(14)
    }

    private func heatRow(_ icon: String, _ label: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.65))
            Spacer()
            // Bar
            GeometryReader { geo in
                let fraction = projects.isEmpty ? 0.0 : CGFloat(count) / CGFloat(projects.count)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.12))
                    Capsule()
                        .fill(color.opacity(0.7))
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 5)
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, alignment: .trailing)
        }
    }

    // MARK: Top Projects

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("HOTTEST")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color(white: 0.35))
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(projects.prefix(5)) { project in
                trayProjectRow(project)
            }
        }
    }

    private func trayProjectRow(_ project: CinderProject) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(project.heat.color.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(project.heat.color.opacity(0.4), lineWidth: 0.5)
                )
                .overlay(
                    Image(systemName: project.heat.icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(project.heat.color)
                )
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(project.momentumLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.4))
            }
            Spacer()
            if !project.stacks.isEmpty {
                Text(project.stacks.first?.rawValue ?? "")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(white: 0.35))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                NSWorkspace.shared.open(URL(string: "cinder://open")!)
            } label: {
                Label("Open Cinder", systemImage: "flame")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(hex: "#FF6D1A"))

            Spacer()

            Button {
                NotificationCenter.default.post(name: .cinderRefresh, object: nil)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.45))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

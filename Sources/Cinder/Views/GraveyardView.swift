import SwiftUI

struct GraveyardView: View {
    @Bindable var viewModel: CardStackViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color.cinderBase.ignoresSafeArea()

            if viewModel.archivedProjects.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 32)
                        .padding(.top, 28)
                        .padding(.bottom, 20)

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.archivedProjects) { project in
                                GraveyardCard(project: project) {
                                    viewModel.unarchive(project)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .scrollEdgeEffectStyle(.soft, for: .bottom)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Graveyard")
                .font(.title2.bold())
                .foregroundStyle(.cinderPrimary)
            Text("\(viewModel.archivedProjects.count) archived projects — bring one back to life")
                .font(.callout)
                .foregroundStyle(.cinderSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.reigniteGreen)
            Text("Nothing here")
                .font(.title2.bold())
                .foregroundStyle(.cinderPrimary)
            Text("Projects you archive will appear here.\nYou can always un-archive them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.cinderSecondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Graveyard Card

struct GraveyardCard: View {
    let project: CinderProject
    let onUnarchive: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.cinderPrimary)
                        .lineLimit(1)
                    Text(project.path.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.cinderMuted)
                        .monospaced()
                }
                Spacer()
                Image(systemName: project.heat.icon)
                    .foregroundStyle(project.heat.color)
                    .accessibilityLabel("\(project.heat.label) heat level")
            }

            HStack(spacing: 4) {
                ForEach(project.stacks.prefix(3), id: \.self) { StackBadge(stack: $0) }
            }

            Divider().background(Color.cinderBorder)

            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.cinderMuted)
                Text(dormantText)
                    .font(.caption)
                    .foregroundStyle(.cinderMuted)
                Spacer()
                Button("Un-archive") {
                    onUnarchive()
                }
                .buttonStyle(.plain)
                .font(.caption.bold())
                .foregroundStyle(.reigniteGreen)
                .accessibilityLabel("Un-archive \(project.name)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isHovered ? Color.cinderCardHover : Color.cinderCard)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cinderBorder, lineWidth: 1))
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    private var dormantText: String {
        let d = project.dormantDays
        if d < 30 { return "\(d)d dormant" }
        let m = d / 30
        return m == 1 ? "1 month dormant" : "\(m) months dormant"
    }
}

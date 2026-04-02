import SwiftUI

struct CardStackView: View {
    @Bindable var viewModel: CardStackViewModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            Color.cinderBase.ignoresSafeArea()

            if viewModel.deck.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    modeHeader
                        .padding(.top, 24)
                        .padding(.horizontal, 32)

                    Spacer()

                    ZStack {
                        ForEach(Array(viewModel.deck.prefix(3).enumerated().reversed()), id: \.element.id) { index, project in
                            if index == 0 {
                                TopCard(project: project, viewModel: viewModel, reduceMotion: reduceMotion)
                            } else {
                                BackCard(project: project, stackIndex: index)
                            }
                        }
                    }
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 32)

                    Spacer()

                    actionBar
                        .padding(.bottom, 36)
                }
            }
        }
        .onChange(of: viewModel.mode) { _, _ in
            viewModel.buildDeck()
        }
    }

    // MARK: - Mode Header

    private var modeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.mode.rawValue)
                    .font(.title2.bold())
                    .foregroundStyle(.cinderPrimary)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.cinderSecondary)
            }
            Spacer()
            if !viewModel.deck.isEmpty {
                Text("\(viewModel.deck.count) remaining")
                    .font(.caption)
                    .foregroundStyle(.cinderMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cinderCard)
                    .clipShape(Capsule())
            }
        }
    }

    private var subtitle: String {
        switch viewModel.mode {
        case .discover:  return "What sparks today?"
        case .hottest:   return "Your most active projects"
        case .coldest:   return "Projects going cold"
        case .streaking: return "Keep the momentum going"
        default:         return ""
        }
    }

    // MARK: - Action Bar (Liquid Glass buttons)

    private var actionBar: some View {
        HStack(spacing: 32) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 24) {
                    // Archive
                    Button {
                        if let top = viewModel.deck.first { viewModel.archive(top) }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "archivebox.fill")
                                .font(.title2)
                                .foregroundStyle(.archiveGrey)
                            Text("Archive")
                                .font(.caption2)
                                .foregroundStyle(.cinderSecondary)
                        }
                        .frame(width: 72, height: 72)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular, in: .circle)
                    .accessibilityLabel("Archive project")
                    .accessibilityHint("Moves project to the Graveyard")

                    // Snooze
                    Button {
                        if let top = viewModel.deck.first { viewModel.snooze(top, days: 7) }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.title2)
                                .foregroundStyle(.snoozeBlue)
                            Text("Snooze 7d")
                                .font(.caption2)
                                .foregroundStyle(.cinderSecondary)
                        }
                        .frame(width: 72, height: 72)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular, in: .circle)
                    .accessibilityLabel("Snooze project for 7 days")

                    // Reignite — primary action with ember tint
                    Button {
                        if let top = viewModel.deck.first { viewModel.reignite(top) }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.title)
                                .foregroundStyle(.heatHot)
                            Text("Reignite")
                                .font(.caption.bold())
                                .foregroundStyle(.cinderPrimary)
                        }
                        .frame(width: 88, height: 88)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.heatHot.opacity(0.35)), in: .circle)
                    .accessibilityLabel("Reignite project")
                    .accessibilityHint("Marks project as active and shows your resume brief")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.dust.fill")
                .font(.system(size: 64))
                .foregroundStyle(.cinderMuted)
            Text("All clear")
                .font(.title2.bold())
                .foregroundStyle(.cinderPrimary)
            Text("You've gone through all projects in this mode.\nSwitch modes or refresh to find more.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.cinderSecondary)
                .font(.callout)
            Button("Refresh") {
                Task { await viewModel.loadProjects() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.heatHot)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Top Card (Swipeable)

struct TopCard: View {
    let project: CinderProject
    @Bindable var viewModel: CardStackViewModel
    let reduceMotion: Bool

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0

    private var swipeOpacity: Double { min(1, abs(offset.width) / 80) }
    private var isReigniting: Bool { offset.width > 30 }
    private var isArchiving: Bool { offset.width < -30 }

    var body: some View {
        ProjectCardView(project: project)
            .overlay(swipeOverlay)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .gesture(swipeGesture)
            .shadow(color: shadowColor, radius: 24, x: 0, y: 8)
            // Ember glow for blazing/hot projects
            .shadow(
                color: (project.heat == .blazing || project.heat == .hot) ? Color.heatHot.opacity(0.18) : .clear,
                radius: 32
            )
            .animation(reduceMotion ? .none : .interactiveSpring(response: 0.3, dampingFraction: 0.7), value: offset)
    }

    private var shadowColor: Color {
        if isReigniting { return Color.heatHot.opacity(0.3) }
        if isArchiving  { return Color.archiveGrey.opacity(0.3) }
        return Color.black.opacity(0.4)
    }

    @ViewBuilder
    private var swipeOverlay: some View {
        if swipeOpacity > 0 {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isReigniting ? Color.heatHot.opacity(0.15) : Color.archiveGrey.opacity(0.15))

                VStack {
                    HStack {
                        if isReigniting {
                            Label("REIGNITE", systemImage: "flame.fill")
                                .font(.title3.bold())
                                .foregroundStyle(.heatHot)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(20)
                        }
                        Spacer()
                        if isArchiving {
                            Label("ARCHIVE", systemImage: "archivebox.fill")
                                .font(.title3.bold())
                                .foregroundStyle(.archiveGrey)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(20)
                        }
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .opacity(swipeOpacity)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
                rotation = reduceMotion ? 0 : Double(value.translation.width / 20)
            }
            .onEnded { value in
                let threshold: CGFloat = 130
                if value.translation.width > threshold {
                    flyOut(direction: 1)
                    DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.3)) {
                        viewModel.reignite(project)
                        resetCard()
                    }
                } else if value.translation.width < -threshold {
                    flyOut(direction: -1)
                    DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.3)) {
                        viewModel.archive(project)
                        resetCard()
                    }
                } else {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7)) {
                        offset = .zero
                        rotation = 0
                    }
                }
            }
    }

    private func flyOut(direction: CGFloat) {
        withAnimation(reduceMotion ? .none : .easeIn(duration: 0.3)) {
            offset = CGSize(width: direction * 600, height: offset.height)
            rotation = reduceMotion ? 0 : direction * 20
        }
    }

    private func resetCard() {
        offset = .zero
        rotation = 0
    }
}

// MARK: - Back Cards

struct BackCard: View {
    let project: CinderProject
    let stackIndex: Int

    private var scale: CGFloat { 1.0 - CGFloat(stackIndex) * 0.04 }
    private var yOffset: CGFloat { CGFloat(stackIndex) * 12 }

    var body: some View {
        ProjectCardView(project: project)
            .scaleEffect(scale)
            .offset(y: -yOffset)
            .allowsHitTesting(false)
    }
}

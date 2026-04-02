import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var swipeRecords: [SwipeRecord]

    @State private var viewModel = CardStackViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            mainContent
                .backgroundExtensionEffect()
        }
        .background(Color.cinderBase)
        .task {
            viewModel.configure(modelContext: modelContext, swipeRecords: swipeRecords)
            await viewModel.loadProjects()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cinderRefresh)) { _ in
            Task { await viewModel.loadProjects() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cinderOpenSettings)) { _ in
            showSettings = true
        }
        .sheet(isPresented: $viewModel.showReignitionSheet) {
            if let project = viewModel.lastReignited {
                ReignitionView(project: project, isPresented: $viewModel.showReignitionSheet)
                    .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.mode {
        case .graveyard:
            GraveyardView(viewModel: viewModel)
        case .stats:
            StatsView(viewModel: viewModel)
        case .gitTree:
            if let hottest = viewModel.allProjects.first {
                GitTreeView(project: hottest)
            } else {
                loadingView
            }
        default:
            if viewModel.isLoading {
                loadingView
            } else {
                CardStackView(viewModel: viewModel)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.heatHot)
            Text("Scanning projects…")
                .foregroundStyle(.cinderSecondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cinderBase)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Bindable var viewModel: CardStackViewModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $viewModel.mode) {
                Section("Browse") {
                    ForEach([DiscoveryMode.discover, .hottest, .coldest, .streaking], id: \.self) { mode in
                        sidebarRow(mode)
                    }
                }
                Section("Library") {
                    sidebarRow(.graveyard)
                    sidebarRow(.stats)
                    sidebarRow(.gitTree)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)

            // API status panel pinned to sidebar bottom
            APIStatusView(server: viewModel.apiServer)
        }
        .background(Color.cinderSurface)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                VStack(spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.heatHot)
                            .shadow(color: .heatHot.opacity(0.5), radius: 4)
                        Text("Cinder")
                            .font(.headline)
                            .foregroundStyle(.cinderPrimary)
                    }
                    Text("\(viewModel.allProjects.count) projects")
                        .font(.caption2)
                        .foregroundStyle(.cinderMuted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Cinder — \(viewModel.allProjects.count) projects")
            }
        }
    }

    private func sidebarRow(_ mode: DiscoveryMode) -> some View {
        Label(mode.rawValue, systemImage: mode.icon)
            .foregroundStyle(viewModel.mode == mode ? mode.color : .cinderSecondary)
            .tag(mode)
    }
}

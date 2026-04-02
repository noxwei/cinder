import SwiftUI

// MARK: - Theme Picker
// Accessible from Settings → Appearance.
// Shows all 6 themes as swatch cards.

struct ThemePickerView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private let cols = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Appearance")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Choose a color theme")
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.5))
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                    .font(.callout.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Theme grid
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(CinderTheme.all) { t in
                    ThemeSwatchCard(theme: t, isSelected: theme.current.id == t.id) {
                        withAnimation(.spring(duration: 0.3)) {
                            theme.set(t)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 520)
        .background(theme.base)
    }
}

// MARK: - Swatch Card

struct ThemeSwatchCard: View {
    let theme: CinderTheme
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Color preview strip
                HStack(spacing: 0) {
                    ForEach([
                        theme.heatBlazing,
                        theme.heatHot,
                        theme.heatWarm,
                        theme.accent1,
                        theme.heatCooling,
                        theme.heatCold,
                        theme.heatAsh,
                    ], id: \.self) { c in
                        c.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Card surface preview
                HStack(spacing: 6) {
                    // Mini sidebar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.surface)
                        .frame(width: 24, height: 36)
                        .overlay(
                            VStack(spacing: 3) {
                                ForEach(0..<3) { _ in
                                    Capsule()
                                        .fill(theme.accent1.opacity(0.5))
                                        .frame(height: 3)
                                        .padding(.horizontal, 4)
                                }
                            }
                        )

                    // Mini card stack
                    VStack(spacing: 3) {
                        ForEach(0..<2) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i == 0 ? theme.card : theme.surface)
                                .frame(height: 14)
                                .overlay(
                                    HStack {
                                        Circle()
                                            .fill(i == 0 ? theme.heatBlazing : theme.heatCold)
                                            .frame(width: 5, height: 5)
                                            .padding(.leading, 4)
                                        Spacer()
                                    }
                                )
                        }
                    }
                    .frame(height: 36)
                }
                .padding(.top, 8)

                // Name + description
                HStack(spacing: 5) {
                    Text(theme.emoji)
                        .font(.system(size: 14))
                    Text(theme.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)

                Text(theme.description)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.45))
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? theme.accent1 : Color(white: isHovered ? 0.2 : 0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(duration: 0.2), value: isHovered)
    }
}

// MARK: - Settings Window

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @State private var tab: SettingsTab = .appearance

    enum SettingsTab: String, CaseIterable {
        case appearance = "Appearance"
        case api        = "API"
        case scanner    = "Scanner"

        var icon: String {
            switch self {
            case .appearance: return "paintpalette"
            case .api:        return "network"
            case .scanner:    return "folder.badge.magnifyingglass"
            }
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            ForEach(SettingsTab.allCases, id: \.self) { t in
                Group {
                    switch t {
                    case .appearance:
                        AppearanceSettingsTab()
                    case .api:
                        APISettingsTab()
                    case .scanner:
                        ScannerSettingsTab()
                    }
                }
                .tabItem {
                    Label(t.rawValue, systemImage: t.icon)
                }
                .tag(t)
            }
        }
        .frame(width: 520, height: 400)
        .background(theme.base)
    }
}

// MARK: - Appearance Tab

private struct AppearanceSettingsTab: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color Theme")
                        .font(.headline)
                        .foregroundStyle(.white)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 10)], spacing: 10) {
                        ForEach(CinderTheme.all) { t in
                            ThemeSwatchCard(theme: t, isSelected: theme.current.id == t.id) {
                                withAnimation(.spring(duration: 0.3)) {
                                    theme.set(t)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(theme.base)
    }
}

// MARK: - API Tab (placeholder)

private struct APISettingsTab: View {
    @Environment(\.theme) private var theme
    var body: some View {
        VStack {
            Text("API settings")
                .foregroundStyle(Color(white: 0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.base)
    }
}

// MARK: - Scanner Tab (placeholder)

private struct ScannerSettingsTab: View {
    @Environment(\.theme) private var theme
    var body: some View {
        VStack {
            Text("Scanner settings")
                .foregroundStyle(Color(white: 0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.base)
    }
}

import AppKit
import SwiftUI

// MARK: - CinderNotchPanel
// NSPanel at .screenSaver level (101) — sits above the menu bar, flush to the notch bottom edge.
// Heat bar: 1pt tall, spans the hardware notch width.
// Single click: drops a 310×280pt drawer below the notch.
// Double click: opens the full Cinder window.
// Right click: compact NSMenu.

@MainActor
final class CinderNotchPanel: NSObject {

    // MARK: - State

    private var barPanel:     NSPanel?
    private var drawerPanel:  NSPanel?
    private var drawerOpen    = false
    private var projects:     [CinderProject] = []
    private var cinderModeOn  = false

    private var pulseTimer:   Timer?
    private var glowPulse:    Double = 0

    // MARK: - Lifecycle

    override init() {
        super.init()
        setupBarPanel()
        observeProjectUpdates()
    }

    func teardown() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        barPanel?.orderOut(nil)
        drawerPanel?.orderOut(nil)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notch Geometry

    private struct NotchGeometry {
        let barRect:    NSRect   // 1pt bar flush to notch bottom
        let notchRect:  NSRect   // full hardware notch rect
        let screen:     NSScreen
    }

    private func notchGeometry() -> NotchGeometry? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) else { return nil }

        let leftArea  = screen.auxiliaryTopLeftArea  ?? .zero
        let rightArea = screen.auxiliaryTopRightArea ?? .zero
        let notchH    = screen.safeAreaInsets.top            // ~32pt on 14/16" MBP

        guard notchH > 0 else { return nil }                 // no notch on this screen

        let notchW    = screen.frame.width - leftArea.width - rightArea.width
        let notchX    = screen.frame.origin.x + leftArea.width
        let notchY    = screen.frame.maxY - notchH

        let notchRect = NSRect(x: notchX, y: notchY, width: notchW, height: notchH)
        let barRect   = NSRect(x: notchX, y: notchY, width: notchW, height: 1)

        return NotchGeometry(barRect: barRect, notchRect: notchRect, screen: screen)
    }

    // MARK: - Bar Panel Setup

    private func setupBarPanel() {
        guard let geo = notchGeometry() else { return }

        let panel = NSPanel(
            contentRect: geo.barRect,
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.level           = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.backgroundColor = .clear
        panel.isOpaque        = false
        panel.hasShadow       = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let barView = NSHostingView(
            rootView: NotchBarView(
                projects:    projects,
                cinderMode:  cinderModeOn,
                glowPulse:   glowPulse
            )
        )
        barView.frame = NSRect(origin: .zero, size: geo.barRect.size)
        panel.contentView = barView

        // click tracking
        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(barTapped(_:)))
        let doubleRecognizer = NSClickGestureRecognizer(target: self, action: #selector(barDoubleTapped(_:)))
        doubleRecognizer.numberOfClicksRequired = 2
        clickRecognizer.numberOfClicksRequired  = 1
        clickRecognizer.require(toFail: doubleRecognizer)

        let rightClick = NSClickGestureRecognizer(target: self, action: #selector(barRightClicked(_:)))
        rightClick.buttonMask = 0x2

        barView.addGestureRecognizer(clickRecognizer)
        barView.addGestureRecognizer(doubleRecognizer)
        barView.addGestureRecognizer(rightClick)

        barPanel = panel
        panel.orderFrontRegardless()
        startPulse()
    }

    // MARK: - Pulse

    private func startPulse() {
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickPulse() }
        }
    }

    private func tickPulse() {
        let dominant = dominantHeat
        guard dominant == .blazing || dominant == .hot else {
            glowPulse = 0; refreshBar(); return
        }
        glowPulse = (glowPulse + 0.02).truncatingRemainder(dividingBy: .pi * 2)
        refreshBar()
    }

    private var dominantHeat: HeatLevel {
        projects.sorted { $0.heatLevel.rank < $1.heatLevel.rank }.first?.heatLevel ?? .ash
    }

    private func refreshBar() {
        guard let panel = barPanel,
              let hosting = panel.contentView as? NSHostingView<NotchBarView> else { return }
        hosting.rootView = NotchBarView(
            projects:   projects,
            cinderMode: cinderModeOn,
            glowPulse:  glowPulse
        )
    }

    // MARK: - Drawer

    @objc private func barTapped(_ recognizer: NSClickGestureRecognizer) {
        drawerOpen ? closeDrawer() : openDrawer()
    }

    @objc private func barDoubleTapped(_ recognizer: NSClickGestureRecognizer) {
        closeDrawer()
        NotificationCenter.default.post(name: .cinderOpenSettings, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func barRightClicked(_ recognizer: NSClickGestureRecognizer) {
        let menu = NSMenu()
        menu.addItem(withTitle: cinderModeOn ? "Disable Cinder Mode" : "Enable Cinder Mode",
                     action: #selector(toggleCinderMode), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Cinder",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent ?? NSEvent(), for: barPanel!.contentView!)
    }

    @objc private func toggleCinderMode() {
        cinderModeOn.toggle()
        NotificationCenter.default.post(name: .cinderModeToggled, object: cinderModeOn)
        refreshBar()
        if drawerOpen { refreshDrawer() }
    }

    private func openDrawer() {
        guard let geo = notchGeometry() else { return }

        let drawerW: CGFloat = 310
        let drawerH: CGFloat = cinderModeOn ? 380 : 280
        let drawerX = geo.notchRect.midX - drawerW / 2
        let drawerY = geo.notchRect.minY - drawerH

        let panel = NSPanel(
            contentRect: NSRect(x: drawerX, y: drawerY + drawerH, width: drawerW, height: drawerH),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.level           = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.backgroundColor = .clear
        panel.isOpaque        = false
        panel.hasShadow       = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let drawerView = NSHostingView(
            rootView: NotchDrawerView(
                projects:   projects,
                cinderMode: cinderModeOn,
                onClose:    { [weak self] in self?.closeDrawer() },
                onOpenApp:  { [weak self] in
                    self?.closeDrawer()
                    NotificationCenter.default.post(name: .cinderOpenSettings, object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                },
                onToggleCinderMode: { [weak self] in self?.toggleCinderMode() }
            )
        )
        panel.contentView = drawerView
        drawerPanel = panel
        panel.orderFrontRegardless()
        drawerOpen = true

        // spring drop-in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration        = 0.32
            ctx.timingFunction  = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
            panel.animator().setFrame(NSRect(x: drawerX, y: drawerY, width: drawerW, height: drawerH),
                                      display: true)
        }

        // dismiss on click outside
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.drawerOpen else { return }
            self.closeDrawer()
        }
    }

    private func closeDrawer() {
        guard let panel = drawerPanel, drawerOpen else { return }
        drawerOpen = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration       = 0.18
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
            var f = panel.frame; f.origin.y += f.height * 0.1
            f.size.height *= 0.92
            panel.animator().setFrame(f, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
        drawerPanel = nil
    }

    private func refreshDrawer() {
        guard let panel = drawerPanel,
              let hosting = panel.contentView as? NSHostingView<NotchDrawerView> else { return }
        hosting.rootView = NotchDrawerView(
            projects:   projects,
            cinderMode: cinderModeOn,
            onClose:    { [weak self] in self?.closeDrawer() },
            onOpenApp:  { [weak self] in
                self?.closeDrawer()
                NotificationCenter.default.post(name: .cinderOpenSettings, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            },
            onToggleCinderMode: { [weak self] in self?.toggleCinderMode() }
        )
    }

    // MARK: - Project Updates

    private func observeProjectUpdates() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(projectsDidUpdate(_:)),
            name:     .cinderProjectsUpdated,
            object:   nil
        )
    }

    @objc private func projectsDidUpdate(_ note: Notification) {
        guard let list = note.userInfo?["projects"] as? [CinderProject] else { return }
        projects = list
        refreshBar()
        if drawerOpen { refreshDrawer() }
    }
}

// MARK: - NotchBarView

struct NotchBarView: View {
    let projects:   [CinderProject]
    let cinderMode: Bool
    let glowPulse:  Double

    private var dominant: HeatLevel {
        projects.sorted { $0.heatLevel.rank < $1.heatLevel.rank }.first?.heatLevel ?? .ash
    }

    private var barColor: Color  { dominant.notchColor }
    private var barAlpha: Double { dominant.notchAlpha }
    private var glowRadius: CGFloat {
        switch dominant {
        case .blazing: return 14
        case .hot:     return 8
        default:       return 0
        }
    }

    private var animatedGlowOpacity: Double {
        switch dominant {
        case .blazing: return 0.55 + 0.45 * sin(glowPulse)
        case .hot:     return 0.75
        default:       return 0
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // outer glow
                if glowRadius > 0 {
                    Rectangle()
                        .fill(barColor.opacity(animatedGlowOpacity * 0.35))
                        .blur(radius: glowRadius * 2)
                        .frame(height: 6)
                }

                // heat bar
                Rectangle()
                    .fill(barColor.opacity(barAlpha))
                    .frame(height: cinderMode ? 2 : 1)
                    .overlay {
                        if glowRadius > 0 {
                            Rectangle()
                                .fill(barColor.opacity(animatedGlowOpacity))
                                .blur(radius: glowRadius * 0.5)
                        }
                    }
                    .overlay {
                        // Cinder Mode shimmer scan
                        if cinderMode {
                            ShimmerBar(width: geo.size.width)
                        }
                    }
            }
        }
        .frame(height: cinderMode ? 2 : 1)
    }
}

// MARK: - Shimmer

struct ShimmerBar: View {
    let width: CGFloat
    @State private var offset: CGFloat = -20

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.12), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 20)
            .offset(x: offset)
            .onAppear {
                withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                    offset = width + 20
                }
            }
            .clipped()
    }
}

// MARK: - NotchDrawerView

struct NotchDrawerView: View {
    let projects:           [CinderProject]
    let cinderMode:         Bool
    let onClose:            () -> Void
    let onOpenApp:          () -> Void
    let onToggleCinderMode: () -> Void

    private var sorted: [CinderProject] {
        projects.sorted { $0.heatLevel.rank < $1.heatLevel.rank }.prefix(4).map { $0 }
    }

    private var topProject: CinderProject? { sorted.first }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(cinderMode ? Color.orange : Color(white: 0.45))
                    .frame(width: 7, height: 7)
                    .shadow(color: cinderMode ? .orange.opacity(0.8) : .clear, radius: 4)
                    .animation(.easeInOut(duration: 0.3), value: cinderMode)

                Text("CINDER")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.85))
                    .tracking(2)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color(white: 0.08))

            Divider().background(Color(white: 0.15))

            // Project heat rows
            VStack(spacing: 0) {
                Text("PROJECT HEAT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
                    .tracking(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                ForEach(sorted, id: \.id) { project in
                    ProjectHeatRow(project: project)
                }
            }

            Divider().background(Color(white: 0.12)).padding(.vertical, 6)

            // Last commit
            if let top = topProject {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LAST COMMIT")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.35))
                        .tracking(1.5)

                    HStack(spacing: 4) {
                        Text(top.name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(white: 0.55))
                        if let recent = top.recentCommits.first {
                            Text("·")
                                .foregroundStyle(Color(white: 0.30))
                            Text(recent.message)
                                .font(.system(size: 11))
                                .italic()
                                .foregroundStyle(Color(hex: "#C8A878"))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            Spacer(minLength: 0)

            // Cinder Mode status (when on)
            if cinderMode {
                Divider().background(Color(white: 0.12))
                HStack {
                    Text("CINDER MODE ACTIVE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.orange.opacity(0.9))
                        .tracking(1.5)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            // Footer buttons
            HStack(spacing: 10) {
                Button(action: onToggleCinderMode) {
                    Text(cinderMode ? "Cinder Mode: On" : "Cinder Mode")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(cinderMode ? Color(hex: "#FF8C40") : Color(white: 0.50))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(cinderMode ? Color(hex: "#3D1A00") : Color(white: 0.09))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(cinderMode ? Color(hex: "#C45A00") : Color(white: 0.14),
                                                      lineWidth: cinderMode ? 1 : 0.8)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button(action: onOpenApp) {
                    Text("Open Cinder")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(white: 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color(white: 0.20), lineWidth: 0.8)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: 310)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.07).opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(hex: "#2A1A0A").opacity(0.7), lineWidth: 0.5)
                )
        )
        // Top corners flush to the notch
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 12,
            bottomTrailingRadius: 12,
            topTrailingRadius: 0,
            style: .continuous
        ))
        .shadow(color: .black.opacity(0.60), radius: 18, x: 0, y: 8)
    }
}

// MARK: - ProjectHeatRow

private struct ProjectHeatRow: View {
    let project: CinderProject

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(project.heatLevel.notchColor)
                .frame(width: 7, height: 7)

            Text(project.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(white: 0.88))
                .lineLimit(1)

            Spacer()

            // heat bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.10))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(project.heatLevel.notchColor)
                        .frame(width: geo.size.width * project.heatLevel.barFraction)
                }
            }
            .frame(width: 80, height: 4)

            Text("\(project.heatLevel.barPercent)%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(white: 0.40))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
    }
}

// MARK: - HeatLevel extensions for notch

private extension HeatLevel {
    var rank: Int {
        switch self {
        case .blazing: return 0
        case .hot:     return 1
        case .warm:    return 2
        case .cooling: return 3
        case .cold:    return 4
        case .ash:     return 5
        }
    }

    var notchColor: Color {
        switch self {
        case .blazing: return Color(hue: 0.043, saturation: 0.90, brightness: 1.00)
        case .hot:     return Color(hue: 0.068, saturation: 0.80, brightness: 1.00)
        case .warm:    return Color(hue: 0.117, saturation: 0.90, brightness: 1.00)
        case .cooling: return Color(hue: 0.597, saturation: 0.44, brightness: 0.80)
        case .cold:    return Color(hue: 0.619, saturation: 0.46, brightness: 0.65)
        case .ash:     return Color(white: 0.33)
        }
    }

    var notchAlpha: Double {
        switch self {
        case .blazing: return 1.00
        case .hot:     return 0.92
        case .warm:    return 0.75
        case .cooling: return 0.55
        case .cold:    return 0.45
        case .ash:     return 0.00   // invisible — cold day, nothing to show
        }
    }

    var barFraction: CGFloat {
        switch self {
        case .blazing: return 0.90
        case .hot:     return 0.72
        case .warm:    return 0.48
        case .cooling: return 0.28
        case .cold:    return 0.14
        case .ash:     return 0.04
        }
    }

    var barPercent: Int { Int(barFraction * 100) }
}

// MARK: - Notification

extension Notification.Name {
    static let cinderModeToggled = Notification.Name("cinderModeToggled")
}

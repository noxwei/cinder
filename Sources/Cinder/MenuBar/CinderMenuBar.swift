import AppKit
import SwiftUI

// MARK: - Cinder Menu Bar Extra
// A pulsing heat indicator that lives in the menu bar near the notch.
// - Icon = tiny heat square that reflects the hottest project's heat level
// - Pulses orange when blazing projects exist, fades to grey when all cold
// - Click → tray drops down with heat breakdown + quick actions

@Observable
@MainActor
final class CinderMenuBar: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var pulseTimer: Timer?

    // Shared app state (updated by the main scanner)
    var projects: [CinderProject] = []
    var isConnected: Bool = false

    override init() {
        super.init()
        setup()
    }

    // MARK: - Setup

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()

        statusItem?.button?.action = #selector(toggleTray)
        statusItem?.button?.target = self
        statusItem?.button?.toolTip = "Cinder — project heat tracker"

        // Start pulse loop
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pulse() }
        }

        // Listen for project updates from the CardStackViewModel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(projectsDidUpdate(_:)),
            name: .cinderProjectsUpdated,
            object: nil
        )
    }

    @objc private func projectsDidUpdate(_ notification: Notification) {
        guard let projects = notification.userInfo?["projects"] as? [CinderProject] else { return }
        updateProjects(projects)
    }

    // MARK: - Icon

    func updateProjects(_ projects: [CinderProject]) {
        self.projects = projects
        updateIcon()
    }

    private var dominantHeat: HeatLevel {
        guard let hottest = projects.first else { return .ash }
        return hottest.heat
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let heat = dominantHeat
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 3, yRadius: 3)
            heat.menuBarColor.set()
            path.fill()

            // Inner glow dot
            let dotRect = CGRect(x: 6, y: 6, width: 6, height: 6)
            let dot = NSBezierPath(ovalIn: dotRect)
            NSColor.white.withAlphaComponent(heat == .ash ? 0.25 : 0.6).set()
            dot.fill()
            return true
        }
        image.isTemplate = false
        button.image = image
    }

    private var pulsePhase: CGFloat = 0
    private var isExpanding = true

    private func pulse() {
        guard let button = statusItem?.button else { return }
        let heat = dominantHeat
        guard heat == .blazing || heat == .hot else {
            button.alphaValue = 1.0
            return
        }
        // Subtle breathing animation
        pulsePhase = isExpanding ? 0.6 : 1.0
        isExpanding.toggle()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 1.8
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            button.animator().alphaValue = pulsePhase
        }
    }

    // MARK: - Tray

    @objc private func toggleTray() {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let p = NSPopover()
        p.contentSize = NSSize(width: 320, height: 480)
        p.behavior = .transient
        p.animates = true
        p.contentViewController = NSHostingController(
            rootView: CinderTrayView(projects: projects)
                .preferredColorScheme(.dark)
        )
        p.show(relativeTo: statusItem!.button!.bounds,
               of: statusItem!.button!,
               preferredEdge: .minY)
        self.popover = p
    }

    func teardown() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }
}

// MARK: - Heat → NSColor

extension HeatLevel {
    var menuBarColor: NSColor {
        switch self {
        case .blazing:  return NSColor(red: 1.00, green: 0.43, blue: 0.10, alpha: 1)
        case .hot:      return NSColor(red: 1.00, green: 0.60, blue: 0.20, alpha: 1)
        case .warm:     return NSColor(red: 1.00, green: 0.78, blue: 0.15, alpha: 1)
        case .cooling:  return NSColor(red: 0.50, green: 0.65, blue: 0.85, alpha: 1)
        case .cold:     return NSColor(red: 0.35, green: 0.48, blue: 0.70, alpha: 1)
        case .ash:      return NSColor(white: 0.35, alpha: 1)
        }
    }
}

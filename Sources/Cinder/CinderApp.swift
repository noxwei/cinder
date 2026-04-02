import SwiftUI
import SwiftData

@main
struct CinderApp: App {
    @State private var themeManager = ThemeManager()
    @State private var menuBarController = CinderMenuBar()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: SwipeRecord.self)
                .preferredColorScheme(.dark)
                .tint(themeManager.accent)
                .environment(\.theme, themeManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Projects") {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .cinderRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Appearance…") {
                    NotificationCenter.default.post(name: .cinderOpenSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let cinderRefresh        = Notification.Name("cinderRefresh")
    static let cinderOpenSettings   = Notification.Name("cinderOpenSettings")
    static let cinderProjectsUpdated = Notification.Name("cinderProjectsUpdated")
}

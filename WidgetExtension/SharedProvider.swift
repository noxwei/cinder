import WidgetKit

// Swift 6: TimelineProvider completions are not @Sendable, but Task requires @Sendable captures.
// SendableBox wraps the completion with @unchecked Sendable — safe because WidgetKit
// always calls completions on the main thread.
private struct SendableBox<T>: @unchecked Sendable { let value: T }

struct CinderProvider: TimelineProvider {
    func placeholder(in context: Context) -> CinderEntry {
        CinderEntry(date: .now, data: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (CinderEntry) -> Void) {
        let box = SendableBox(value: completion)
        Task {
            let data = await WidgetAPIClient.fetchAll() ?? .placeholder
            box.value(CinderEntry(date: .now, data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CinderEntry>) -> Void) {
        let box = SendableBox(value: completion)
        Task {
            let data  = await WidgetAPIClient.fetchAll() ?? .placeholder
            let entry = CinderEntry(date: .now, data: data)
            let next  = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
            box.value(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

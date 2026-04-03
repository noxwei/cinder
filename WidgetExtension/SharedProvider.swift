import WidgetKit

// Single timeline provider shared by all Cinder widgets.
// Fetches once per cycle — macOS caches the result across widget families.
struct CinderProvider: @preconcurrency TimelineProvider {
    func placeholder(in context: Context) -> CinderEntry {
        CinderEntry(date: .now, data: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (CinderEntry) -> Void) {
        Task {
            let data = await WidgetAPIClient.fetchAll() ?? .placeholder
            completion(CinderEntry(date: .now, data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CinderEntry>) -> Void) {
        Task {
            let data  = await WidgetAPIClient.fetchAll() ?? .placeholder
            let entry = CinderEntry(date: .now, data: data)
            // Refresh every 15 minutes
            let next  = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

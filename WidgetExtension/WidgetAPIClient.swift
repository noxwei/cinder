import Foundation

struct WidgetAPIClient {
    static let baseURL = "http://localhost:4242/api"

    // Fetch everything needed by all widgets in 2 concurrent calls
    static func fetchAll() async -> CinderWidgetData? {
        async let digestTask  = fetch(DigestResponse.self,    path: "/digest")
        async let projectsTask = fetch([ProjectResponse].self, path: "/projects?limit=40")

        guard let digest = await digestTask else { return nil }
        let projects = await projectsTask ?? []

        return CinderWidgetData(
            digest:    digest,
            projects:  projects.sorted { $0.heat.heatRank < $1.heat.heatRank },
            fetchedAt: .now
        )
    }

    private static func fetch<T: Decodable>(_ type: T.Type, path: String) async -> T? {
        guard let url = URL(string: baseURL + path) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

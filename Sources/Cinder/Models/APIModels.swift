import Foundation

// MARK: - Stats

struct StatsResponse: Codable {
    let totalProjects: Int
    let archivedProjects: Int
    let totalReignited: Int
    let heatBreakdown: HeatBreakdown
    let generatedAt: String  // ISO8601

    struct HeatBreakdown: Codable {
        let blazing: Int
        let hot: Int
        let warm: Int
        let cooling: Int
        let cold: Int
        let ash: Int

        var hotCount: Int { blazing + hot }
        var coldCount: Int { cold + ash }
    }
}

// MARK: - Project

struct ProjectResponse: Codable {
    let id: String
    let name: String
    let path: String
    let stacks: [String]
    let heat: String
    let dormantDays: Int
    let lastCommitDate: String?
    let commitCountLastMonth: Int
    let recentCommits: [CommitResponse]
    let isGitRepo: Bool
    let momentumLabel: String
}

struct CommitResponse: Codable {
    let hash: String
    let message: String
    let date: String
    let author: String
}

// MARK: - Digest (widget / notification friendly)

struct DigestResponse: Codable {
    // One-liner suitable for a Shortcuts notification
    let headline: String        // "🔥 3 blazing · ✨ 5 warm · 🧊 12 cold"
    let summary: String         // "You have 20 active projects. 3 are on fire."
    let mostActive: String?     // name of hottest project
    let mostUrgent: String?     // oldest cold/ash project that needs love
    let needsAttention: [String] // names of cold+ash projects (limit 5)
    let hotProjects: [String]   // names of blazing+hot projects (limit 5)
    let totalActive: Int
    let totalArchived: Int
    let generatedAt: String
}

// MARK: - Skill Launch

struct SkillLaunchRequest: Codable {
    let projectName: String
    let skill: String            // e.g. "/load", "/analyze"
}

// MARK: - Generic Responses

struct ActionResponse: Codable {
    let success: Bool
    let message: String
}

struct ErrorResponse: Codable {
    let error: String
    let status: Int
}

// MARK: - HTTP Primitives

struct HTTPRequest {
    let method: String
    let path: String            // e.g. "/api/projects"
    let query: [String: String] // parsed query params
    let headers: [String: String]
    let body: Data

    var pathComponents: [String] {
        path.split(separator: "/").map(String.init)
    }

    init(method: String, fullPath: String, headers: [String: String], body: Data) {
        self.method = method
        self.headers = headers
        self.body = body

        // Parse path and query string
        if let qIdx = fullPath.firstIndex(of: "?") {
            self.path = String(fullPath[..<qIdx])
            let qs = String(fullPath[fullPath.index(after: qIdx)...])
            var q: [String: String] = [:]
            for pair in qs.components(separatedBy: "&") {
                let kv = pair.components(separatedBy: "=")
                if kv.count == 2 {
                    q[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
                }
            }
            self.query = q
        } else {
            self.path = fullPath
            self.query = [:]
        }
    }
}

struct HTTPResponse {
    let status: Int
    let headers: [String: String]
    let body: Data

    static let corsHeaders: [String: String] = [
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
    ]

    static func json<T: Encodable>(_ value: T, status: Int = 200) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(value)) ?? Data()
        var h = corsHeaders
        h["Content-Type"]   = "application/json; charset=utf-8"
        h["Content-Length"] = "\(data.count)"
        return HTTPResponse(status: status, headers: h, body: data)
    }

    static func text(_ string: String, status: Int = 200) -> HTTPResponse {
        let data = Data(string.utf8)
        var h = corsHeaders
        h["Content-Type"]   = "text/plain; charset=utf-8"
        h["Content-Length"] = "\(data.count)"
        return HTTPResponse(status: status, headers: h, body: data)
    }

    static func notFound(_ path: String) -> HTTPResponse {
        json(ErrorResponse(error: "Not found: \(path)", status: 404), status: 404)
    }

    static func badRequest(_ msg: String) -> HTTPResponse {
        json(ErrorResponse(error: msg, status: 400), status: 400)
    }

    static func options() -> HTTPResponse {
        HTTPResponse(status: 204, headers: corsHeaders, body: Data())
    }

    // Serialise to raw HTTP/1.1 bytes
    func serialize() -> Data {
        let statusText = HTTPResponse.statusText(status)
        var raw = "HTTP/1.1 \(status) \(statusText)\r\n"
        for (k, v) in headers { raw += "\(k): \(v)\r\n" }
        raw += "Connection: close\r\n\r\n"
        var data = Data(raw.utf8)
        data.append(body)
        return data
    }

    private static func statusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default:  return "Unknown"
        }
    }
}

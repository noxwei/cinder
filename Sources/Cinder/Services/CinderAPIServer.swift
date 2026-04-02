import Foundation
import Network

// MARK: - Cinder API Server
// Listens on 0.0.0.0:4242 — accessible via localhost, LAN, and Tailscale
// All endpoints: GET|POST /api/...

@MainActor
@Observable
final class CinderAPIServer {

    static let port: UInt16 = 4242
    static let apiKeyDefaultsKey = "cinderAPIKey"

    var isRunning    = false
    var requestCount = 0
    var lastRequest  = ""

    // API key — generated once, stored in UserDefaults, required for all POST requests
    var apiKey: String = {
        if let existing = UserDefaults.standard.string(forKey: CinderAPIServer.apiKeyDefaultsKey) {
            return existing
        }
        let key = "cinder-" + UUID().uuidString.lowercased().prefix(20)
        UserDefaults.standard.set(key, forKey: CinderAPIServer.apiKeyDefaultsKey)
        return key
    }()

    func regenerateAPIKey() {
        let key = "cinder-" + UUID().uuidString.lowercased().prefix(20)
        UserDefaults.standard.set(key, forKey: Self.apiKeyDefaultsKey)
        apiKey = key
    }

    private var listener: NWListener?
    private var viewModel: CardStackViewModel?

    // MARK: - Lifecycle

    func start(viewModel: CardStackViewModel) {
        self.viewModel = viewModel

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let listener = try? NWListener(
            using: params,
            on: NWEndpoint.Port(rawValue: Self.port)!
        ) else {
            print("[Cinder API] Failed to create listener on port \(Self.port)")
            return
        }
        self.listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isRunning = true
                    print("[Cinder API] Running on port \(Self.port)")
                case .failed(let error):
                    self?.isRunning = false
                    print("[Cinder API] Failed: \(error)")
                case .cancelled:
                    self?.isRunning = false
                default: break
                }
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveData(connection: connection, accumulated: Data())
    }

    private func receiveData(connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] content, _, isComplete, error in
            guard let self else { return }

            var buffer = accumulated
            if let content { buffer.append(content) }

            // HTTP headers end with \r\n\r\n
            guard let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                if !isComplete && error == nil {
                    self.receiveData(connection: connection, accumulated: buffer)
                }
                return
            }

            // Parse request line + headers
            let headerData  = buffer[..<headerEndRange.lowerBound]
            let afterHeaders = buffer[headerEndRange.upperBound...]

            guard let headerStr = String(data: headerData, encoding: .utf8) else { return }
            let lines = headerStr.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else { return }

            let parts = requestLine.components(separatedBy: " ")
            guard parts.count >= 2 else { return }
            let method   = parts[0]
            let fullPath = parts[1]

            var headers: [String: String] = [:]
            for line in lines.dropFirst() {
                let kv = line.components(separatedBy: ": ")
                if kv.count >= 2 {
                    headers[kv[0].lowercased()] = kv[1...].joined(separator: ": ")
                }
            }

            let contentLength = Int(headers["content-length"] ?? "0") ?? 0
            let body = Data(afterHeaders.prefix(contentLength))

            let request = HTTPRequest(
                method: method,
                fullPath: fullPath,
                headers: headers,
                body: body
            )

            // Route on main actor (needs ViewModel)
            DispatchQueue.main.async {
                let response = self.route(request)
                self.requestCount += 1
                self.lastRequest = "\(method) \(request.path)"
                self.send(response, connection: connection)
            }
        }
    }

    private func send(_ response: HTTPResponse, connection: NWConnection) {
        connection.send(
            content: response.serialize(),
            completion: .contentProcessed { _ in connection.cancel() }
        )
    }

    // MARK: - Router

    private func route(_ req: HTTPRequest) -> HTTPResponse {
        // OPTIONS preflight (CORS)
        if req.method == "OPTIONS" { return .options() }

        // Auth check for all mutating requests
        // Accept: Authorization: Bearer <key>  OR  X-Cinder-Key: <key>  OR  ?key=<key>
        if req.method == "POST" || req.method == "DELETE" || req.method == "PUT" {
            let bearer = req.headers["authorization"]?.replacingOccurrences(of: "Bearer ", with: "")
            let header = req.headers["x-cinder-key"]
            let query  = req.query["key"]
            guard bearer == apiKey || header == apiKey || query == apiKey else {
                var h = HTTPResponse.corsHeaders
                h["Content-Type"] = "application/json"
                let body = Data(#"{"error":"Unauthorized — include X-Cinder-Key header or ?key= param","status":401}"#.utf8)
                h["Content-Length"] = "\(body.count)"
                return HTTPResponse(status: 401, headers: h, body: body)
            }
        }

        let components = req.pathComponents
        guard components.first == "api" else { return .notFound(req.path) }
        let tail = Array(components.dropFirst())

        switch (req.method, tail) {

        // ── Health ──────────────────────────────────────
        case ("GET", ["health"]):
            return handleHealth()

        // ── Stats ───────────────────────────────────────
        case ("GET", ["stats"]):
            return handleStats()

        // ── Digest (widget-friendly) ────────────────────
        case ("GET", ["digest"]):
            return handleDigest()

        // ── Projects ────────────────────────────────────
        case ("GET", ["projects"]):
            return handleProjects(query: req.query)

        case ("GET", ["projects", "hot"]):
            return handleProjectsHot()

        case ("GET", ["projects", "cold"]):
            return handleProjectsCold()

        case ("GET", ["projects", "random"]):
            return handleProjectsRandom()

        case ("GET", ["projects", let name]):
            return handleProject(name: name)

        // ── Project actions ─────────────────────────────
        case ("POST", ["projects", let name, "reignite"]):
            return handleReignite(name: name)

        case ("POST", ["projects", let name, "snooze"]):
            return handleSnooze(name: name, body: req.body, query: req.query)

        case ("POST", ["projects", let name, "archive"]):
            return handleArchive(name: name)

        // ── Refresh scan ────────────────────────────────
        case ("POST", ["refresh"]):
            return handleRefresh()

        // ── Skills ──────────────────────────────────────
        case ("POST", ["skills", "launch"]):
            return handleSkillLaunch(body: req.body)

        case ("GET", ["skills"]):
            return handleSkillsList()

        default:
            return .notFound(req.path)
        }
    }

    // MARK: - Handlers

    private func handleHealth() -> HTTPResponse {
        .json(ActionResponse(
            success: true,
            message: "Cinder API running · \(viewModel?.allProjects.count ?? 0) projects loaded"
        ))
    }

    private func handleStats() -> HTTPResponse {
        guard let vm = viewModel else { return .json(ErrorResponse(error: "Not ready", status: 503), status: 503) }
        let all = vm.allProjects

        let breakdown = StatsResponse.HeatBreakdown(
            blazing: all.filter { $0.heat == .blazing }.count,
            hot:     all.filter { $0.heat == .hot     }.count,
            warm:    all.filter { $0.heat == .warm    }.count,
            cooling: all.filter { $0.heat == .cooling }.count,
            cold:    all.filter { $0.heat == .cold    }.count,
            ash:     all.filter { $0.heat == .ash     }.count
        )

        return .json(StatsResponse(
            totalProjects:    all.count,
            archivedProjects: vm.archivedProjects.count,
            totalReignited:   vm.totalReignited,
            heatBreakdown:    breakdown,
            generatedAt:      ISO8601DateFormatter().string(from: .now)
        ))
    }

    private func handleDigest() -> HTTPResponse {
        guard let vm = viewModel else { return .json(ErrorResponse(error: "Not ready", status: 503), status: 503) }
        let all      = vm.allProjects
        let hot      = all.filter { $0.heat == .blazing || $0.heat == .hot }
        let needsAttn = all.filter { $0.heat == .cold || $0.heat == .ash }
            .sorted { ($0.lastCommitDate ?? .distantPast) < ($1.lastCommitDate ?? .distantPast) }

        let b   = all.filter { $0.heat == .blazing }.count
        let h   = all.filter { $0.heat == .hot     }.count
        let w   = all.filter { $0.heat == .warm    }.count
        let c   = all.filter { $0.heat == .cold    }.count
        let ash = all.filter { $0.heat == .ash     }.count

        var parts: [String] = []
        if b > 0 { parts.append("🔥 \(b) blazing") }
        if h > 0 { parts.append("🔥 \(h) hot") }
        if w > 0 { parts.append("✨ \(w) warm") }
        if c + ash > 0 { parts.append("🧊 \(c + ash) cold") }
        let headline = parts.joined(separator: " · ")

        let summary: String
        if hot.count == 0 {
            summary = "All \(all.count) projects are quiet. Time to pick one."
        } else if hot.count == 1 {
            summary = "\(hot[0].name) is on fire. \(needsAttn.count) projects need attention."
        } else {
            summary = "\(hot.count) projects blazing. \(needsAttn.count) going cold."
        }

        return .json(DigestResponse(
            headline:        headline.isEmpty ? "No active projects" : headline,
            summary:         summary,
            mostActive:      hot.first?.name,
            mostUrgent:      needsAttn.first?.name,
            needsAttention:  needsAttn.prefix(5).map(\.name),
            hotProjects:     hot.prefix(5).map(\.name),
            totalActive:     all.count,
            totalArchived:   vm.archivedProjects.count,
            generatedAt:     ISO8601DateFormatter().string(from: .now)
        ))
    }

    private func handleProjects(query: [String: String]) -> HTTPResponse {
        guard let vm = viewModel else { return .json(ErrorResponse(error: "Not ready", status: 503), status: 503) }
        var projects = vm.allProjects

        // Filter by heat if provided: ?heat=hot
        if let heatFilter = query["heat"] {
            projects = projects.filter { $0.heat.label.lowercased() == heatFilter.lowercased() }
        }

        // Limit: ?limit=10
        if let limitStr = query["limit"], let limit = Int(limitStr) {
            projects = Array(projects.prefix(limit))
        }

        return .json(projects.map(projectDTO))
    }

    private func handleProjectsHot() -> HTTPResponse {
        guard let vm = viewModel else { return .json(ErrorResponse(error: "Not ready", status: 503), status: 503) }
        let hot = vm.hotProjects
        return .json(hot.map(projectDTO))
    }

    private func handleProjectsCold() -> HTTPResponse {
        guard let vm = viewModel else { return .json(ErrorResponse(error: "Not ready", status: 503), status: 503) }
        let cold = vm.coldProjects
        return .json(cold.map(projectDTO))
    }

    private func handleProjectsRandom() -> HTTPResponse {
        guard let vm = viewModel, let random = vm.allProjects.randomElement() else {
            return .json(ErrorResponse(error: "No projects available", status: 404), status: 404)
        }
        return .json(projectDTO(random))
    }

    private func handleProject(name: String) -> HTTPResponse {
        guard let vm = viewModel else { return .json(ErrorResponse(error: "Not ready", status: 503), status: 503) }
        let decoded = name.removingPercentEncoding ?? name
        guard let project = vm.allProjects.first(where: {
            $0.name.lowercased() == decoded.lowercased() ||
            $0.path.lastPathComponent.lowercased() == decoded.lowercased()
        }) else {
            return .notFound("/api/projects/\(name)")
        }
        return .json(projectDTO(project))
    }

    private func handleReignite(name: String) -> HTTPResponse {
        guard let vm = viewModel else { return .json(ErrorResponse(error: "Not ready", status: 503), status: 503) }
        let decoded = name.removingPercentEncoding ?? name
        guard let project = findProject(decoded, in: vm.allProjects) else {
            return .notFound(name)
        }
        vm.reignite(project)
        return .json(ActionResponse(success: true, message: "Reignited \(project.name)"))
    }

    private func handleSnooze(name: String, body: Data, query: [String: String]) -> HTTPResponse {
        guard let vm = viewModel else { return .json(ErrorResponse(error: "Not ready", status: 503), status: 503) }
        let decoded = name.removingPercentEncoding ?? name
        guard let project = findProject(decoded, in: vm.allProjects) else {
            return .notFound(name)
        }

        // Days from JSON body or query param, default 7
        var days = Int(query["days"] ?? "") ?? 7
        if let bodyJSON = try? JSONDecoder().decode([String: Int].self, from: body),
           let d = bodyJSON["days"] { days = d }

        vm.snooze(project, days: days)
        return .json(ActionResponse(success: true, message: "Snoozed \(project.name) for \(days) days"))
    }

    private func handleArchive(name: String) -> HTTPResponse {
        guard let vm = viewModel else { return .json(ErrorResponse(error: "Not ready", status: 503), status: 503) }
        let decoded = name.removingPercentEncoding ?? name
        guard let project = findProject(decoded, in: vm.allProjects) else {
            return .notFound(name)
        }
        vm.archive(project)
        return .json(ActionResponse(success: true, message: "Archived \(project.name)"))
    }

    private func handleRefresh() -> HTTPResponse {
        Task { @MainActor in
            await viewModel?.loadProjects()
        }
        return .json(ActionResponse(success: true, message: "Scan triggered"))
    }

    private func handleSkillLaunch(body: Data) -> HTTPResponse {
        guard let req = try? JSONDecoder().decode(SkillLaunchRequest.self, from: body) else {
            return .badRequest("Body must be {\"projectName\": \"…\", \"skill\": \"/load\"}")
        }
        guard let vm = viewModel,
              let project = findProject(req.projectName, in: vm.allProjects) else {
            return .notFound(req.projectName)
        }
        guard let skill = ClaudeSkillsService.skills.first(where: {
            $0.slash == req.skill || $0.id == req.skill
        }) else {
            return .badRequest("Unknown skill: \(req.skill). Use GET /api/skills for valid options.")
        }
        ClaudeSkillsService.launch(skill, in: project)
        return .json(ActionResponse(success: true, message: "Launched \(skill.slash) in \(project.name)"))
    }

    private func handleSkillsList() -> HTTPResponse {
        let list = ClaudeSkillsService.skills.map { s -> [String: String] in
            ["id": s.id, "slash": s.slash, "label": s.label, "category": s.category.rawValue, "description": s.description]
        }
        return .json(list)
    }

    // MARK: - Helpers

    private func projectDTO(_ p: CinderProject) -> ProjectResponse {
        let fmt = ISO8601DateFormatter()
        return ProjectResponse(
            id:                   p.id,
            name:                 p.name,
            path:                 p.path.path,
            stacks:               p.stacks.map(\.rawValue),
            heat:                 p.heat.label,
            dormantDays:          p.dormantDays,
            lastCommitDate:       p.lastCommitDate.map { fmt.string(from: $0) },
            commitCountLastMonth: p.commitCountLastMonth,
            recentCommits:        p.recentCommits.map {
                CommitResponse(
                    hash:    $0.hash,
                    message: $0.message,
                    date:    fmt.string(from: $0.date),
                    author:  $0.author
                )
            },
            isGitRepo:      p.isGitRepo,
            momentumLabel:  p.momentumLabel
        )
    }

    private func findProject(_ name: String, in projects: [CinderProject]) -> CinderProject? {
        let lower = name.lowercased()
        return projects.first {
            $0.name.lowercased()                 == lower ||
            $0.path.lastPathComponent.lowercased() == lower
        }
    }
}

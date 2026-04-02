import Foundation

// MARK: - Git Tree Service
// Parses `git log --graph --oneline --decorate --color=never` output into
// structured data for rendering in the GitTreeView WKWebView.

struct GitCommit: Identifiable, Sendable {
    let id: String          // short hash
    let fullHash: String
    let message: String
    let author: String
    let date: String
    let relativeDate: String
    let refs: [String]      // branch / tag labels
    let graphLine: String   // raw graph prefix chars for positioning
    let isMerge: Bool
}

actor GitTreeService {

    func fetchTree(for projectPath: String, limit: Int = 80) async throws -> [GitCommit] {
        let format = "%H|||%h|||%s|||%an|||%ad|||%ar|||%D"
        let args = [
            "log",
            "--graph",
            "--format=\(format)",
            "--date=short",
            "--decorate",
            "--color=never",
            "-\(limit)",
        ]

        let raw = try await runGit(args: args, at: projectPath)
        return parse(raw)
    }

    // MARK: - Private

    private func parse(_ raw: String) -> [GitCommit] {
        var commits: [GitCommit] = []
        let lines = raw.components(separatedBy: "\n")

        for line in lines {
            // Skip pure graph lines (no commit data — just | and / characters)
            guard line.contains("|||") else { continue }

            // Split graph prefix from commit data
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 7 else { continue }

            // The graph prefix is everything before the first hash-like segment
            // parts[0] may have graph chars + the hash embedded: "* abcdef1" → graph="* ", hash
            let rawPrefix = parts[0]
            let fullHash  = parts[1].trimmingCharacters(in: .whitespaces)
            let shortHash = parts[2].trimmingCharacters(in: .whitespaces)
            let message   = parts[3].trimmingCharacters(in: .whitespaces)
            let author    = parts[4].trimmingCharacters(in: .whitespaces)
            let date      = parts[5].trimmingCharacters(in: .whitespaces)
            let relDate   = parts[6].trimmingCharacters(in: .whitespaces)
            let refsRaw   = parts.count > 7 ? parts[7].trimmingCharacters(in: .whitespaces) : ""

            // Extract graph column characters (*, |, /, \, space)
            let graphChars = rawPrefix.prefix(while: { "* |/\\-_".contains($0) })
            let graphLine = String(graphChars)

            // Parse refs: "HEAD -> main, origin/main, tag: v1.0"
            let refs = refsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let isMerge = message.lowercased().hasPrefix("merge")
                || graphLine.contains("\\")
                || graphLine.contains("/")

            commits.append(GitCommit(
                id: shortHash,
                fullHash: fullHash,
                message: message,
                author: author,
                date: date,
                relativeDate: relDate,
                refs: refs,
                graphLine: graphLine,
                isMerge: isMerge
            ))
        }

        return commits
    }

    private func runGit(args: [String], at path: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

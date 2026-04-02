import Foundation

struct GitService {

    // MARK: - Git Runner (safe — no shell string interpolation)
    // Each call passes arguments as an array directly to git, never through a shell.
    // This prevents command injection via maliciously-named project directories.

    @discardableResult
    private static func git(_ args: [String], at url: URL) -> String {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = Pipe()
        process.executableURL  = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments      = ["-C", url.path] + args
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Git Checks

    static func isGitRepo(at url: URL) -> Bool {
        let result = git(["rev-parse", "--is-inside-work-tree"], at: url)
        return result == "true"
    }

    // MARK: - Commits

    static func recentCommits(at url: URL, count: Int = 5) -> [GitCommit] {
        let separator = "|||"
        let format = "%h\(separator)%s\(separator)%ae\(separator)%ai"
        let raw = git(["log", "-\(count)", "--format=\(format)"], at: url)
        guard !raw.isEmpty else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]

        return raw.components(separatedBy: "\n").compactMap { line -> GitCommit? in
            let parts = line.components(separatedBy: separator)
            guard parts.count >= 4 else { return nil }
            let hash    = parts[0]
            let message = parts[1]
            let author  = parts[2]
            let dateStr = parts[3]

            var date: Date?
            date = formatter.date(from: dateStr)
            if date == nil {
                let fallback = DateFormatter()
                fallback.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                date = fallback.date(from: dateStr)
            }
            return GitCommit(
                id: hash,
                hash: hash,
                message: message,
                date: date ?? .distantPast,
                author: author
            )
        }
    }

    static func lastCommitDate(at url: URL) -> Date? {
        let raw = git(["log", "-1", "--format=%ai"], at: url)
        guard !raw.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.date(from: raw)
    }

    static func commitCountLastMonth(at url: URL) -> Int {
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
        let since = ISO8601DateFormatter().string(from: oneMonthAgo)
        let result = git(["rev-list", "--count", "--after=\(since)", "HEAD"], at: url)
        return Int(result) ?? 0
    }

    static func currentBranch(at url: URL) -> String? {
        let result = git(["branch", "--show-current"], at: url)
        return result.isEmpty ? nil : result
    }

    static func uncommittedChanges(at url: URL) -> Int {
        let result = git(["status", "--porcelain"], at: url)
        return result.isEmpty ? 0 : result.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }
}

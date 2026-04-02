import Foundation

struct ProjectScanner {

    // Add paths here to scan additional locations
    static let scanRoots: [URL] = [
        URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Local_Dev/projects"),
        URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Desktop"),
        URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Documents"),
    ]

    static func scan() async -> [CinderProject] {
        var projects: [CinderProject] = []
        let fm = FileManager.default

        for root in scanRoots {
            guard fm.fileExists(atPath: root.path) else { continue }
            guard let contents = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                // Skip known non-project dirs
                let name = url.lastPathComponent
                guard !ignoredNames.contains(name) else { continue }

                let project = await buildProject(at: url)
                projects.append(project)
            }
        }

        // Sort: hottest first
        return projects.sorted { lhs, rhs in
            switch (lhs.lastCommitDate, rhs.lastCommitDate) {
            case (.some(let a), .some(let b)): return a > b
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.name < rhs.name
            }
        }
    }

    static func buildProject(at url: URL) async -> CinderProject {
        let name = url.lastPathComponent
        let isGit = GitService.isGitRepo(at: url)

        var lastCommitDate: Date? = nil
        var recentCommits: [GitCommit] = []
        var commitCountLastMonth = 0

        if isGit {
            lastCommitDate = GitService.lastCommitDate(at: url)
            recentCommits = GitService.recentCommits(at: url, count: 4)
            commitCountLastMonth = GitService.commitCountLastMonth(at: url)
        } else {
            // Fall back to file modification date
            lastCommitDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        }

        let stacks = detectStack(at: url)

        return CinderProject(
            name: displayName(from: name),
            path: url,
            stacks: stacks,
            lastCommitDate: lastCommitDate,
            recentCommits: recentCommits,
            isGitRepo: isGit,
            commitCountLastMonth: commitCountLastMonth
        )
    }

    // MARK: - Stack Detection

    static func detectStack(at url: URL) -> [TechStack] {
        let fm = FileManager.default
        var stacks: [TechStack] = []

        func exists(_ relative: String) -> Bool {
            fm.fileExists(atPath: url.appending(path: relative).path)
        }

        // Swift / SwiftUI
        if exists("Package.swift") || !glob(url, pattern: "*.xcodeproj").isEmpty || !glob(url, pattern: "*.xcworkspace").isEmpty {
            stacks.append(.swift)
            // Heuristic: check for SwiftUI import
            let swiftFiles = glob(url, pattern: "Sources/**/*.swift") + glob(url, pattern: "*.swift")
            if swiftFiles.prefix(5).contains(where: { fileContains($0, text: "SwiftUI") }) {
                stacks.append(.swiftUI)
            }
        }

        // Node / JS ecosystem
        if exists("package.json") {
            if let pkg = readJSON(url.appending(path: "package.json")) {
                let allDeps = (pkg["dependencies"] as? [String: Any] ?? [:])
                    .merging(pkg["devDependencies"] as? [String: Any] ?? [:]) { a, _ in a }

                if allDeps["next"] != nil            { stacks.append(.nextjs) }
                else if allDeps["astro"] != nil      { stacks.append(.astro) }
                else if allDeps["react"] != nil      { stacks.append(.react) }
                else if allDeps["vue"] != nil        { stacks.append(.vue) }
                else if allDeps["electron"] != nil   { stacks.append(.electron) }

                if allDeps["typescript"] != nil || exists("tsconfig.json") { stacks.append(.typescript) }
            }
            if exists("bun.lockb") || exists("bun.lock") { stacks.append(.bun) }
            else { stacks.append(.node) }
        }

        // Python
        if exists("pyproject.toml") || exists("requirements.txt") || exists("setup.py") || exists("Pipfile") {
            stacks.append(.python)
        }

        // Rust
        if exists("Cargo.toml") { stacks.append(.rust) }

        // Go
        if exists("go.mod") { stacks.append(.go) }

        return stacks.isEmpty ? [.unknown] : stacks
    }

    // MARK: - Helpers

    private static func displayName(from folderName: String) -> String {
        // Convert kebab-case/snake_case to Title Case
        folderName
            .components(separatedBy: CharacterSet(charactersIn: "-_"))
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func glob(_ url: URL, pattern: String) -> [URL] {
        // Simple glob: just check immediate children matching extension
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return [] }
        let ext = (pattern as NSString).pathExtension
        return ext.isEmpty ? [] : contents.filter { $0.pathExtension == ext }
    }

    private static func fileContains(_ url: URL, text: String) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return content.contains(text)
    }

    private static func readJSON(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static let ignoredNames: Set<String> = [
        ".git", "node_modules", ".build", "DerivedData", ".DS_Store",
        "dist", "build", ".next", "__pycache__", "venv", ".venv",
        "LibraryOfBabel.bfg-report", "logs", "DataStuff", "RandomProjs",
    ]
}

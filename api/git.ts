import { spawnSync } from "child_process";
import type { GitCommit } from "./types";

function run(cmd: string, args: string[]): string {
  const result = spawnSync(cmd, args, { encoding: "utf8", timeout: 5000 });
  return (result.stdout ?? "").trim();
}

export function isGitRepo(dir: string): boolean {
  const result = run("git", ["-C", dir, "rev-parse", "--is-inside-work-tree"]);
  return result === "true";
}

export function lastCommitDate(dir: string): Date | null {
  const raw = run("git", ["-C", dir, "log", "-1", "--format=%ai"]);
  if (!raw) return null;
  const d = new Date(raw);
  return isNaN(d.getTime()) ? null : d;
}

export function recentCommits(dir: string, count = 4): GitCommit[] {
  const SEP = "|||";
  const fmt = `%h${SEP}%s${SEP}%ae${SEP}%ai`;
  const raw = run("git", ["-C", dir, "log", `-${count}`, `--format=${fmt}`]);
  if (!raw) return [];

  return raw.split("\n").flatMap((line) => {
    const [hash, message, author, dateStr] = line.split(SEP);
    if (!hash || !message) return [];
    const d = new Date(dateStr ?? "");
    return [{
      hash: hash.replace(/'/g, ""),
      message: message.length > 72 ? message.slice(0, 69) + "…" : message,
      date: isNaN(d.getTime()) ? new Date(0).toISOString() : d.toISOString(),
      author: author ?? "",
    }];
  });
}

export function commitCountLastMonth(dir: string): number {
  const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const raw = run("git", ["-C", dir, "rev-list", "--count", `--after=${since}`, "HEAD"]);
  return parseInt(raw, 10) || 0;
}

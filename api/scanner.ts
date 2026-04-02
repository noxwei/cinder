import { readdirSync, existsSync, readFileSync, statSync } from "fs";
import { join, basename } from "path";
import * as git from "./git";
import type { CinderProject, HeatLevel } from "./types";

const SCAN_ROOT = process.env.PROJECTS_DIR ?? "/projects";

const IGNORED = new Set([
  ".git", "node_modules", ".build", "DerivedData", ".DS_Store",
  "dist", "build", ".next", "__pycache__", "venv", ".venv",
  "LibraryOfBabel.bfg-report", "logs", "DataStuff", "RandomProjs",
]);

function dormantDays(lastCommit: Date | null): number {
  if (!lastCommit) return 999;
  return Math.floor((Date.now() - lastCommit.getTime()) / 86_400_000);
}

function heatLevel(days: number): HeatLevel {
  if (days < 3)   return "Blazing";
  if (days < 7)   return "Hot";
  if (days < 30)  return "Warm";
  if (days < 90)  return "Cooling";
  if (days < 180) return "Cold";
  return "Ash";
}

function detectStacks(dir: string): string[] {
  const stacks: string[] = [];

  const has = (rel: string) => existsSync(join(dir, rel));

  if (has("Package.swift") || readdirSync(dir).some(f => f.endsWith(".xcodeproj"))) {
    stacks.push("Swift");
  }

  if (has("package.json")) {
    try {
      const pkg = JSON.parse(readFileSync(join(dir, "package.json"), "utf8"));
      const deps = { ...(pkg.dependencies ?? {}), ...(pkg.devDependencies ?? {}) };
      if (deps["next"])       stacks.push("Next.js");
      else if (deps["astro"]) stacks.push("Astro");
      else if (deps["react"]) stacks.push("React");
      else if (deps["vue"])   stacks.push("Vue");
      else if (deps["electron"]) stacks.push("Electron");
      if (deps["typescript"] || has("tsconfig.json")) stacks.push("TypeScript");
    } catch {}
    if (has("bun.lockb") || has("bun.lock")) stacks.push("Bun");
    else stacks.push("Node");
  }

  if (has("pyproject.toml") || has("requirements.txt") || has("Pipfile")) stacks.push("Python");
  if (has("Cargo.toml")) stacks.push("Rust");
  if (has("go.mod"))     stacks.push("Go");

  return stacks.length ? stacks : ["Unknown"];
}

function displayName(folder: string): string {
  return folder
    .split(/[-_]/)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}

function momentumLabel(count: number): string {
  if (count === 0)      return "no recent activity";
  if (count <= 3)       return `${count} commits / month`;
  if (count <= 15)      return `${count} commits / month`;
  return `${count} commits / month`;
}

export function scanProjects(): CinderProject[] {
  let entries: string[];
  try {
    entries = readdirSync(SCAN_ROOT);
  } catch {
    return [];
  }

  const projects: CinderProject[] = [];

  for (const entry of entries) {
    if (IGNORED.has(entry)) continue;
    const dir = join(SCAN_ROOT, entry);
    try {
      if (!statSync(dir).isDirectory()) continue;
    } catch { continue; }

    const isRepo   = git.isGitRepo(dir);
    const lastDate = isRepo ? git.lastCommitDate(dir) : (() => {
      try { return statSync(dir).mtime; } catch { return null; }
    })();
    const commits  = isRepo ? git.recentCommits(dir) : [];
    const monthly  = isRepo ? git.commitCountLastMonth(dir) : 0;
    const days     = dormantDays(lastDate);

    projects.push({
      id:                   dir,
      name:                 displayName(entry),
      path:                 dir,
      stacks:               detectStacks(dir),
      heat:                 heatLevel(days),
      dormantDays:          days,
      lastCommitDate:       lastDate?.toISOString() ?? null,
      commitCountLastMonth: monthly,
      recentCommits:        commits,
      isGitRepo:            isRepo,
      momentumLabel:        momentumLabel(monthly),
    });
  }

  return projects.sort((a, b) => {
    if (a.lastCommitDate && b.lastCommitDate)
      return new Date(b.lastCommitDate).getTime() - new Date(a.lastCommitDate).getTime();
    if (a.lastCommitDate) return -1;
    if (b.lastCommitDate) return 1;
    return a.name.localeCompare(b.name);
  });
}

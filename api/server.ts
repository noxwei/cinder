import { existsSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { scanProjects } from "./scanner";
import type { CinderProject, AppState, SwipeRecord } from "./types";

// ── Config ──────────────────────────────────────────────────────────────────

const PORT          = parseInt(process.env.PORT ?? "4242", 10);
const DATA_FILE     = process.env.DATA_FILE ?? "/data/state.json";
const TAILSCALE_URL = process.env.CINDER_TAILSCALE_URL ?? "https://<your-host>.ts.net:8445";

// ── State ────────────────────────────────────────────────────────────────────

// API key lives in CINDER_API_KEY env var — never in state.json.
// state.json only holds swipe records and is safe to commit to git.
function resolveApiKey(): string {
  const envKey = process.env.CINDER_API_KEY;
  if (envKey) return envKey;
  // Fallback: generate, print clearly, require user to set it
  const generated = "cinder-" + crypto.randomUUID().toLowerCase().slice(0, 20);
  console.warn(`\n⚠  CINDER_API_KEY not set. Generated for this session: ${generated}`);
  console.warn(`   Set it permanently: export CINDER_API_KEY=${generated}\n`);
  return generated;
}

function loadState(): AppState {
  try {
    if (existsSync(DATA_FILE)) {
      return JSON.parse(readFileSync(DATA_FILE, "utf8")) as AppState;
    }
  } catch {}
  const state: AppState = { swipeRecords: [] };
  saveState(state);
  return state;
}

function saveState(state: AppState): void {
  try { writeFileSync(DATA_FILE, JSON.stringify(state, null, 2)); } catch {}
}

let state = loadState();
const API_KEY = resolveApiKey();
let projectCache: CinderProject[] = [];
let cacheTs = 0;
const CACHE_TTL = 5 * 60 * 1000; // 5 min

function getProjects(): CinderProject[] {
  if (Date.now() - cacheTs > CACHE_TTL) {
    projectCache = scanProjects();
    cacheTs = Date.now();
  }
  return projectCache;
}

function activeProjects(): CinderProject[] {
  const archived = new Set(
    state.swipeRecords.filter(r => r.direction === "archive").map(r => r.projectPath)
  );
  const snoozed = new Set(
    state.swipeRecords
      .filter(r => r.direction === "snooze" && r.snoozeUntil && new Date(r.snoozeUntil) > new Date())
      .map(r => r.projectPath)
  );
  return getProjects().filter(p => !archived.has(p.id) && !snoozed.has(p.id));
}

function findProject(name: string, pool = activeProjects()): CinderProject | undefined {
  const lower = decodeURIComponent(name).toLowerCase();
  return pool.find(
    p => p.name.toLowerCase() === lower || p.path.split("/").pop()!.toLowerCase() === lower
  );
}

// ── Auth ─────────────────────────────────────────────────────────────────────

function checkAuth(req: Request): boolean {
  if (req.method === "GET" || req.method === "OPTIONS") return true;
  const bearer = req.headers.get("authorization")?.replace("Bearer ", "");
  const hdr    = req.headers.get("x-cinder-key");
  const query  = new URL(req.url).searchParams.get("key");
  return bearer === API_KEY || hdr === API_KEY || query === API_KEY;
}

// ── Response helpers ─────────────────────────────────────────────────────────

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Cinder-Key",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function unauthorized(): Response {
  return json({ error: "Unauthorized — include X-Cinder-Key header or ?key= param", status: 401 }, 401);
}

function notFound(path: string): Response {
  return json({ error: `Not found: ${path}`, status: 404 }, 404);
}

function plainText(body: string): Response {
  return new Response(body, {
    status: 200,
    headers: { ...CORS, "Content-Type": "text/plain; charset=utf-8" },
  });
}

// ── Handlers ──────────────────────────────────────────────────────────────────

function handleHealth(): Response {
  return json({ success: true, message: `Cinder API running · ${activeProjects().length} projects loaded` });
}

function handleStats(): Response {
  const all = activeProjects();
  const count = (heat: string) => all.filter(p => p.heat === heat).length;
  return json({
    totalProjects:    all.length,
    archivedProjects: state.swipeRecords.filter(r => r.direction === "archive").length,
    totalReignited:   state.swipeRecords.filter(r => r.direction === "reignite").length,
    heatBreakdown: {
      blazing: count("Blazing"), hot: count("Hot"), warm: count("Warm"),
      cooling: count("Cooling"), cold: count("Cold"), ash: count("Ash"),
    },
    generatedAt: new Date().toISOString(),
  });
}

function handleDigest(): Response {
  const all      = activeProjects();
  const hot      = all.filter(p => p.heat === "Blazing" || p.heat === "Hot");
  const attn     = all
    .filter(p => p.heat === "Cold" || p.heat === "Ash")
    .sort((a, b) => (a.lastCommitDate ?? "") < (b.lastCommitDate ?? "") ? -1 : 1);

  const b   = all.filter(p => p.heat === "Blazing").length;
  const h   = all.filter(p => p.heat === "Hot").length;
  const w   = all.filter(p => p.heat === "Warm").length;
  const c   = all.filter(p => p.heat === "Cold").length;
  const ash = all.filter(p => p.heat === "Ash").length;

  const parts: string[] = [];
  if (b)     parts.push(`Blazing: ${b}`);
  if (h)     parts.push(`Hot: ${h}`);
  if (w)     parts.push(`Warm: ${w}`);
  if (c+ash) parts.push(`Cold: ${c + ash}`);

  const headline = parts.join(" · ") || "No active projects";
  const summary  = hot.length === 0
    ? `All ${all.length} projects are quiet.`
    : hot.length === 1
    ? `${hot[0].name} is on fire. ${attn.length} projects need attention.`
    : `${hot.length} projects blazing. ${attn.length} going cold.`;

  return json({
    headline,
    summary,
    mostActive:      hot[0]?.name ?? null,
    mostUrgent:      attn[0]?.name ?? null,
    needsAttention:  attn.slice(0, 5).map(p => p.name),
    hotProjects:     hot.slice(0, 5).map(p => p.name),
    totalActive:     all.length,
    totalArchived:   state.swipeRecords.filter(r => r.direction === "archive").length,
    generatedAt:     new Date().toISOString(),
  });
}

function handleProjects(url: URL): Response {
  let pool = activeProjects();
  const heat  = url.searchParams.get("heat");
  const limit = parseInt(url.searchParams.get("limit") ?? "0", 10);
  if (heat)  pool = pool.filter(p => p.heat.toLowerCase() === heat.toLowerCase());
  if (limit) pool = pool.slice(0, limit);
  return json(pool);
}

function handleProjectAction(name: string, action: string, body: Record<string, unknown>): Response {
  const project = findProject(name);
  if (!project) return notFound(name);

  const record: SwipeRecord = {
    projectPath: project.id,
    projectName: project.name,
    direction:   action as SwipeRecord["direction"],
    timestamp:   new Date().toISOString(),
  };

  if (action === "snooze") {
    const days = (body.days as number) ?? 7;
    const until = new Date(Date.now() + days * 86_400_000);
    record.snoozeUntil = until.toISOString();
  }

  state.swipeRecords.push(record);
  saveState(state);

  // Bust cache
  cacheTs = 0;

  return json({ success: true, message: `${action.charAt(0).toUpperCase() + action.slice(1)}d ${project.name}` });
}

function handleRefresh(): Response {
  cacheTs = 0;
  projectCache = scanProjects();
  cacheTs = Date.now();
  return json({ success: true, message: `Scanned ${projectCache.length} projects` });
}

function handleSkills(): Response {
  return json([
    { id: "load",       slash: "/load",       label: "Load Context",  category: "Jump Back In" },
    { id: "status",     slash: "/status",     label: "Status Check",  category: "Jump Back In" },
    { id: "git",        slash: "/git",        label: "Git Workflow",  category: "Jump Back In" },
    { id: "sprint-plan",slash: "/sprint-plan",label: "Sprint Plan",   category: "Plan"         },
    { id: "estimate",   slash: "/estimate",   label: "Estimate",      category: "Plan"         },
    { id: "analyze",    slash: "/analyze",    label: "Analyze",       category: "Inspect"      },
    { id: "troubleshoot",slash:"/troubleshoot",label:"Troubleshoot",  category: "Inspect"      },
    { id: "scan",       slash: "/scan",       label: "Security Scan", category: "Inspect"      },
    { id: "test",       slash: "/test",       label: "Run Tests",     category: "Ship"         },
    { id: "ship-check", slash: "/ship-check", label: "Ship Check",    category: "Ship"         },
    { id: "end-of-day", slash: "/end-of-day", label: "End of Day",    category: "Ship"         },
  ]);
}

function handleLlmsTxt(): Response {
  const all  = activeProjects();
  const stats = {
    total:   all.length,
    blazing: all.filter(p => p.heat === "Blazing").length,
    hot:     all.filter(p => p.heat === "Hot").length,
    warm:    all.filter(p => p.heat === "Warm").length,
    cooling: all.filter(p => p.heat === "Cooling").length,
    cold:    all.filter(p => p.heat === "Cold").length,
    ash:     all.filter(p => p.heat === "Ash").length,
  };

  const topProject = all.find(p => p.heat === "Blazing") ?? all.find(p => p.heat === "Hot");

  return plainText(`# Cinder API — LLM Reference
Generated: ${new Date().toISOString()}
Base URL (local):    http://0.0.0.0:${PORT}
Base URL (Tailscale): ${TAILSCALE_URL}

## What is Cinder?
Cinder is a macOS SwiftUI app that tracks unfinished dev projects by heat level (git activity).
It exposes a REST API on port ${PORT} for widgets, iOS Shortcuts, and automation.
There is also a companion macOS native app with a Tinder-style swipe UI, menu bar extra, and git tree viewer.

## Auth
- GET endpoints: public, no auth required
- POST endpoints: require one of:
    Header:  X-Cinder-Key: <key>
    Header:  Authorization: Bearer <key>
    Query:   ?key=<key>

## Heat Levels
Heat is derived from days since last git commit:
  Blazing  — 0–3 days
  Hot      — 3–7 days
  Warm     — 7–30 days
  Cooling  — 30–90 days
  Cold     — 90–180 days
  Ash      — 180+ days (dead project)

## Current Stats
Total active projects: ${stats.total}
  🔥 Blazing : ${stats.blazing}
     Hot     : ${stats.hot}
     Warm    : ${stats.warm}
  ❄️ Cooling : ${stats.cooling}
     Cold    : ${stats.cold}
  🪦 Ash     : ${stats.ash}
${topProject ? `\nHottest project: ${topProject.name} (${topProject.heat}, last commit ${topProject.lastCommitDate ?? "unknown"})` : ""}

## Endpoints

### GET /api/health
Returns: { success, message }
Example response:
  { "success": true, "message": "Cinder API running · 12 projects loaded" }

### GET /api/stats
Returns heat breakdown and swipe history counts.
Fields: totalProjects, archivedProjects, totalReignited, heatBreakdown{blazing,hot,warm,cooling,cold,ash}, generatedAt

### GET /api/digest
Human-readable summary. Best for widgets and Shortcuts.
Fields: headline, summary, mostActive, mostUrgent, needsAttention[], hotProjects[], totalActive, totalArchived, generatedAt
Example response:
  {
    "headline": "Blazing: 2 · Hot: 1 · Cold: 3",
    "summary": "2 projects blazing. 3 going cold.",
    "mostActive": "voxlight",
    "mostUrgent": "old-side-project",
    "needsAttention": ["old-side-project", "abandoned-api"],
    "hotProjects": ["voxlight", "cinder"],
    "totalActive": 12,
    "totalArchived": 4,
    "generatedAt": "2026-04-02T..."
  }

### GET /api/projects
Returns all active (non-archived, non-snoozed) projects as array.
Query params:
  ?heat=Blazing|Hot|Warm|Cooling|Cold|Ash   — filter by heat level
  ?limit=N                                    — max results

Project object shape:
  {
    "id": "/Users/.../projects/voxlight",
    "name": "voxlight",
    "path": "/Users/.../projects/voxlight",
    "heat": "Blazing",
    "dormantDays": 1,
    "lastCommitDate": "2026-04-01T...",
    "commitCountLastMonth": 47,
    "currentBranch": "dev",
    "uncommittedChanges": 3,
    "recentCommits": [
      { "hash": "a1b2c3d", "message": "fix: sync engine", "author": "Wei", "date": "..." }
    ],
    "techStack": ["swift", "xcode"],
    "description": null
  }

### GET /api/projects/hot
Returns only Blazing + Hot projects.

### GET /api/projects/cold
Returns only Cold + Ash projects.

### GET /api/projects/random
Returns one random active project.

### GET /api/projects/:name
Returns single project by name (case-insensitive). 404 if not found.

### GET /api/skills
Returns the list of Claude Code skills available for project re-entry.
Each skill: { id, slash, label, category }
Categories: "Jump Back In", "Plan", "Inspect", "Ship"

### POST /api/projects/:name/reignite
Mark a project as reignited (removes from cold tracking).
Body: {} (empty OK)
Returns: { success, message }

### POST /api/projects/:name/snooze
Snooze a project (hide from active list for N days).
Body: { "days": 7 }   — default 7 days
Returns: { success, message }

### POST /api/projects/:name/archive
Archive a project (permanently hide).
Body: {} (empty OK)
Returns: { success, message }

### POST /api/refresh
Force rescan of projects directory. Busts cache.
Returns: { success, message: "Scanned N projects" }

### GET /api/llms.txt
This document. Full LLM reference. Public.

### GET /api/llms-mini.txt
Minimal iOS Shortcuts cheatsheet. Public.

## Data Notes
- Projects are scanned from PROJECTS_DIR env var (default: /projects in Docker, ~/Local_Dev/projects on host)
- Archived/snoozed state persists in DATA_FILE (default: /data/state.json)
- Project cache TTL: 5 minutes. Force refresh: POST /api/refresh
- Swipe records are append-only. Archive is permanent unless state.json is edited.

## Running Locally
Docker: docker compose up -d   (port ${PORT})
Direct: bun run api/server.ts  (PROJECTS_DIR=~/Local_Dev/projects)
`);
}

function handleLlmsMiniTxt(): Response {
  const all = activeProjects();
  const hot = all.filter(p => p.heat === "Blazing" || p.heat === "Hot");
  const ash = all.filter(p => p.heat === "Ash" || p.heat === "Cold");

  return plainText(`# Cinder API — iOS Shortcuts Quick Reference
Base (local):    http://0.0.0.0:${PORT}/api
Base (Tailscale): ${TAILSCALE_URL}/api
Auth (POST only): header X-Cinder-Key or ?key=YOUR_KEY

## Key Endpoints (GET = no auth needed)
GET  /digest          → headline + summary + mostActive + mostUrgent + needsAttention[]
GET  /stats           → heatBreakdown{blazing,hot,warm,cooling,cold,ash}
GET  /projects        → all projects array
GET  /projects/hot    → Blazing + Hot only
GET  /projects/cold   → Cold + Ash only
GET  /projects/random → one random project
GET  /projects/:name  → single project by name

## POST Actions (need auth)
POST /projects/:name/reignite    body: {}
POST /projects/:name/snooze      body: {"days":7}
POST /projects/:name/archive     body: {}
POST /refresh                    body: {}

## Shortcut Recipe: Daily Heat Check
1. GET /api/digest
2. Read: headline, summary, mostActive
3. Show notification or widget

## Shortcut Recipe: Open Hottest Project in Claude
1. GET /api/projects/hot
2. Take first item → name field
3. Open URL: cinder://reignite?project=[name]

## Live Data (right now)
Active: ${all.length} · Hot: ${hot.length} · Ash: ${ash.length}
${hot.length > 0 ? `Hottest: ${hot[0].name} (${hot[0].heat})` : "Nothing blazing right now."}
${ash.length > 0 ? `Most urgent: ${ash[0].name} (${ash[0].dormantDays}d dormant)` : ""}

## Notes
- GET endpoints are public (no auth)
- Cache refreshes every 5min or POST /refresh
- Project :name is case-insensitive, matches name or directory basename
`);
}

// ── Router ────────────────────────────────────────────────────────────────────

async function route(req: Request): Promise<Response> {
  const url      = new URL(req.url);
  const method   = req.method;
  const segments = url.pathname.replace(/^\//, "").split("/");

  if (method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }

  if (!checkAuth(req)) return unauthorized();

  if (segments[0] !== "api") return notFound(url.pathname);
  const [, ...tail] = segments;

  // Body parsing
  let body: Record<string, unknown> = {};
  if (method === "POST") {
    try { body = await req.json(); } catch {}
  }

  const key = `${method} /${tail.join("/")}`;

  if (key === "GET /health")           return handleHealth();
  if (key === "GET /stats")            return handleStats();
  if (key === "GET /digest")           return handleDigest();
  if (key === "GET /projects")         return handleProjects(url);
  if (key === "GET /llms.txt")         return handleLlmsTxt();
  if (key === "GET /llms-mini.txt")    return handleLlmsMiniTxt();
  if (key === "GET /projects/hot")     return json(activeProjects().filter(p => p.heat === "Blazing" || p.heat === "Hot"));
  if (key === "GET /projects/cold")    return json(activeProjects().filter(p => p.heat === "Cold" || p.heat === "Ash"));
  if (key === "GET /projects/random")  { const p = activeProjects(); return p.length ? json(p[Math.floor(Math.random() * p.length)]) : notFound("random"); }
  if (key === "GET /skills")           return handleSkills();
  if (key === "POST /refresh")         return handleRefresh();

  // GET /projects/:name
  if (method === "GET" && tail[0] === "projects" && tail.length === 2) {
    const p = findProject(tail[1]);
    return p ? json(p) : notFound(tail[1]);
  }

  // POST /projects/:name/reignite|snooze|archive
  if (method === "POST" && tail[0] === "projects" && tail.length === 3) {
    const [, name, action] = tail;
    if (["reignite", "snooze", "archive"].includes(action)) {
      return handleProjectAction(name, action, body);
    }
  }

  return notFound(url.pathname);
}

// ── Server ────────────────────────────────────────────────────────────────────

const server = Bun.serve({
  port: PORT,
  hostname: "0.0.0.0",
  fetch: route,
});

console.log(`
╔══════════════════════════════════════════╗
║  🔥  Cinder API                          ║
║  Port    : ${PORT}                          ║
║  Projects: ${process.env.PROJECTS_DIR ?? "/projects"}  ║
║  API Key : ${API_KEY}  ║
╚══════════════════════════════════════════╝
`);
console.log(`GET  http://0.0.0.0:${PORT}/api/health`);
console.log(`GET  http://0.0.0.0:${PORT}/api/digest`);
console.log(`GET  http://0.0.0.0:${PORT}/api/stats`);
console.log(`GET  http://0.0.0.0:${PORT}/api/llms.txt`);
console.log(`GET  http://0.0.0.0:${PORT}/api/llms-mini.txt`);

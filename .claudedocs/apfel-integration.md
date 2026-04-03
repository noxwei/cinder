# apfel Integration — cinder

Local Apple on-device inference for project heat narratives and swipe-assist features.
apfel runs at `http://localhost:11434` on the Mac mini — the same machine hosting the Bun API.

## What to use apfel for in cinder

- **Project heat narratives** — prose summaries for the iOS Shortcut TTS digest
- **Swipe decision assist** — one-liner about a project's last meaningful work shown on the swipe deck
- **wtd-style analysis** — file structure + git history narration per project

## What NOT to use apfel for

- Embeddings / semantic project search
- Context windows over ~3,000 words
- Knowledge of events/libraries after mid-2023

---

## Integration points

### 1. Prose heat narrative for iOS Shortcut TTS (`/api/digest`)

The current `/api/digest` endpoint returns structured JSON heat data.
apfel adds a natural-language prose summary for the Claude TTS step in the Shortcut.

```typescript
// In the Bun API server — add to digest handler
async function generateHeatNarrative(projects: ProjectHeat[]): Promise<string> {
  const blazing = projects.filter(p => p.heat === "Blazing").map(p => p.name);
  const cold = projects.filter(p => p.heat === "Cold" || p.heat === "Ash").map(p => p.name);
  const summary = [
    `${projects.length} projects tracked.`,
    blazing.length ? `Blazing: ${blazing.join(", ")}.` : "",
    cold.length ? `Going cold: ${cold.join(", ")}.` : "",
  ].filter(Boolean).join(" ");

  const res = await fetch("http://localhost:11434/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "apple-on-device",
      messages: [
        {
          role: "system",
          content: "You narrate dev project heat reports as brief, direct morning briefings. 2-3 sentences. Casual but informative. No emojis."
        },
        { role: "user", content: summary }
      ]
    })
  });

  const data = await res.json() as any;
  return data.choices[0].message.content as string;
}
```

Add `narrative` field to the digest response:
```typescript
// In /api/digest handler
const narrative = await generateHeatNarrative(projects).catch(() => "");
return Response.json({ projects, stats, narrative });
```

### 2. Swipe deck one-liners

Show an apfel-generated one-liner about the project's last commit on the reignite/archive card.
Cache per project + commit hash to avoid repeated inference on unchanged projects.

```typescript
// Cache: projectPath → { commitHash, oneliner }
const oneliners = new Map<string, { hash: string; text: string }>();

async function getProjectOneliner(
  projectPath: string,
  lastCommitHash: string,
  lastCommitMsg: string,
  daysSince: number
): Promise<string> {
  const cached = oneliners.get(projectPath);
  if (cached?.hash === lastCommitHash) return cached.text;

  const res = await fetch("http://localhost:11434/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "apple-on-device",
      messages: [
        {
          role: "system",
          content: "Write a single sentence (max 12 words) describing what a dev project was last doing. Direct, no fluff."
        },
        {
          role: "user",
          content: `Last commit (${daysSince}d ago): ${lastCommitMsg}`
        }
      ]
    })
  });

  const data = await res.json() as any;
  const text = data.choices[0].message.content as string;
  oneliners.set(projectPath, { hash: lastCommitHash, text });
  return text;
}
```

### 3. Project analysis (wtd-style for /api/projects endpoint)

apfel's `wtd` demo script does exactly this — but for the API, call apfel directly:

```typescript
import { execSync } from "child_process";

async function analyzeProject(projectPath: string): Promise<string> {
  // Gather context: file tree + recent git log
  let context = "";
  try {
    const tree = execSync(`find ${projectPath} -maxdepth 2 -not -path "*/node_modules/*" -not -path "*/.git/*"`,
      { encoding: "utf8", timeout: 5000 });
    const log = execSync(`git -C ${projectPath} log --oneline -10 2>/dev/null || echo "no git"`,
      { encoding: "utf8", timeout: 3000 });
    context = `File tree:\n${tree.slice(0, 2000)}\n\nRecent commits:\n${log}`;
  } catch { return "Analysis unavailable"; }

  const res = await fetch("http://localhost:11434/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "apple-on-device",
      messages: [
        {
          role: "system",
          content: "You analyze dev projects from their file structure and git history. Write 2 sentences: what it is and where it seems to be in development."
        },
        { role: "user", content: context }
      ]
    })
  });

  const data = await res.json() as any;
  return data.choices[0].message.content;
}
```

---

## Availability check

Both Swift app and Bun API should check before calling:

```typescript
async function apfelAvailable(): Promise<boolean> {
  try {
    const res = await fetch("http://localhost:11434/health", { signal: AbortSignal.timeout(2000) });
    return res.ok;
  } catch {
    return false;
  }
}

// In handlers that use apfel
if (!await apfelAvailable()) {
  return Response.json({ ...existingData, narrative: "" }); // degrade gracefully
}
```

---

## iOS Shortcut update

Current flow: `GET /api/digest → Claude (TTS) → Speak → ChatGPT (widget) → Update Draft`

With apfel, the narrative generation moves on-device:
- New flow: `GET /api/digest → (narrative already in response) → Claude (TTS polish) → Speak`
- Claude TTS step now receives pre-narrated text, reducing tokens needed from Claude API

---

## Setup

apfel runs on the same Mac mini as the Bun API server (port 4242).

```bash
# Install
brew tap Arthur-Ficial/tap && brew install Arthur-Ficial/tap/apfel

# Start (bind to all interfaces so Bun can reach it on localhost)
apfel --serve

# Verify from Bun
curl http://localhost:11434/health
```

No changes to Docker Compose needed — apfel runs as a background process, not a container.
Consider a launchd plist for auto-start on Mac mini boot.

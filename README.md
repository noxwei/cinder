# Cinder

> *Das Feuer, das nicht lodert, glimmt noch.* — The fire that does not blaze still smolders.

Tinder for your unfinished dev projects. Cinder scans your projects folder, assigns a heat level based on git activity, and lets you swipe to reignite or archive. Never stare at a graveyard of directories again.

## What it does

Cinder reads your `~/projects` (or any directory) and assigns each repo a **heat level**:

| Level | Days since last commit |
|---|---|
| Blazing | 0–3 |
| Hot | 3–7 |
| Warm | 7–30 |
| Cooling | 30–90 |
| Cold | 90–180 |
| Ash | 180+ |

You get:

- **Swipe deck** — Tinder-style cards. Swipe right to reignite (opens Claude Code skills launcher). Swipe left to archive.
- **Menu bar extra** — pulsing heat indicator. Click to pull down a tray with heat breakdown and top projects.
- **Git tree viewer** — `git log --graph` in a WKWebView. Toggle **Cinder Mode** for word scatter physics on scroll (powered by `@chenglou/pretext`).
- **6 color themes** — Ember, Deep Sea, Void, Matrix, Parchment, Forge. Full color-theory palette, each with its own heat spectrum.
- **6 WidgetKit widgets** — small, medium, large heat grid, graveyard counter, daily nudge, stats bar.
- **REST API** — Bun/Docker server on port 4242. Hit it from iOS Shortcuts, home screen widgets, or anything else.

## Requirements

- macOS 14+
- Xcode 16+ (for the Swift app)
- Bun 1.3+ or Docker (for the API server)
- Git (for project scanning)

## Setup

### Swift app

```bash
git clone https://github.com/noxwei/cinder
cd cinder
xcodegen generate   # generates Cinder.xcodeproj from project.yml
open Cinder.xcodeproj
# Press Cmd+R
```

### API server (Docker)

```bash
cp .env.example .env
# Edit .env — set CINDER_API_KEY and optionally CINDER_TAILSCALE_URL

docker compose up -d
# API is now running at http://localhost:4242
```

### API server (Bun, no Docker)

```bash
cd api
PROJECTS_DIR=~/projects CINDER_API_KEY=your-key bun run server.ts
```

## API

All GET endpoints are public. POST requires `X-Cinder-Key` header, `Authorization: Bearer <key>`, or `?key=<key>`.

```
GET  /api/health           liveness check
GET  /api/digest           heat summary — best for widgets and Shortcuts
GET  /api/stats            breakdown counts
GET  /api/projects         all active projects
GET  /api/projects/hot     Blazing + Hot only
GET  /api/projects/cold    Cold + Ash only
GET  /api/projects/random  one random project
GET  /api/projects/:name   single project
GET  /api/skills           Claude Code skill list
GET  /api/llms.txt         full LLM reference (plain text)
GET  /api/llms-mini.txt    iOS Shortcuts cheatsheet (plain text)

POST /api/projects/:name/reignite
POST /api/projects/:name/snooze     body: { "days": 7 }
POST /api/projects/:name/archive
POST /api/refresh
```

Full reference: `GET /api/llms.txt` or see [cinder-api-reference](https://bythewei.dev/docs/cinder-api-reference).

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `CINDER_API_KEY` | Yes (POST) | Auth key for write endpoints. Generate: `openssl rand -hex 16` |
| `CINDER_TAILSCALE_URL` | No | Your Tailscale HTTPS URL for remote access |
| `PROJECTS_DIR` | No | Directory to scan (default: `/projects` in Docker) |
| `PORT` | No | Server port (default: `4242`) |
| `DATA_FILE` | No | Path to state file (default: `/data/state.json`) |

## iOS Shortcuts

With the API running and `CINDER_TAILSCALE_URL` set, you can build a daily standup shortcut:

```
1. GET <your-tailscale-url>/api/digest
2. Use AI model: "Summarize for text-to-speech"
3. Speak text
4. Use AI model: "Format for widget display, max 11 lines"
5. Update Draft (Drafts app, Replace mode)
```

Automate it: Shortcuts → Automations → At sunrise → How's My Cinder.

The Drafts widget on your home screen shows the formatted output. Wakes you up with a spoken heat report. *La routine est la mère du succès.*

## Tailscale setup (optional)

To reach the API from iPhone/iPad with a trusted HTTPS cert:

```bash
# Check existing serves first — don't overwrite other projects
tailscale serve status

# Pick an unused port (443, 8443, 10000 for public; anything else for tailnet-only)
tailscale serve --bg --https=8445 4242

# Your URL: https://<machine>.<tailnet>.ts.net:8445
# Set it: export CINDER_TAILSCALE_URL=https://<machine>.<tailnet>.ts.net:8445
```

## Project structure

```
Sources/Cinder/
  CinderApp.swift          — app entry, ThemeManager, menu bar wiring
  MenuBar/                 — NSStatusItem, NSPopover tray
  Services/                — GitService, ProjectScanner, ClaudeSkillsService, CinderAPIServer
  Theme/                   — CinderTheme, ThemeManager (@Observable)
  ViewModels/              — CardStackViewModel
  Views/                   — ContentView, CardStackView, GitTreeView, ThemePickerView, ...
  Resources/               — pretext.bundle.js (word scatter physics)

WidgetExtension/           — 6 WidgetKit widgets

api/
  server.ts                — Bun HTTP server
  scanner.ts               — project directory scanner
  git.ts                   — git operations (array args, no shell injection)
  types.ts                 — shared types
```

## Security

- Git operations use `Process` with array arguments — no shell string interpolation.
- AppleScript paths are escaped before interpolation in `ClaudeSkillsService`.
- API key lives in `CINDER_API_KEY` env var, never in `state.json` or committed code.
- All write endpoints require auth. Read endpoints are public.

See `.claudedocs/scans/security-2026-04-02.md` for the full audit.

## License

MIT

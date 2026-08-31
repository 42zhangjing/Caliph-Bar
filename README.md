# CaliphBar

CaliphBar is a lightweight macOS menu-bar monitor for AI coding-tool quota usage. It keeps a draggable edge-docked pill on screen, opens custom `NSPanel` detail surfaces, and supports Chinese/English UI with a system-language default.

## Current scope

- **Claude Code** — exact account usage from Anthropic's OAuth usage endpoint when Claude Code credentials are available. Background Keychain reads are non-interactive. If exact usage is temporarily unavailable, CaliphBar prefers a recent last-known-good live snapshot; only then does it fall back to a clearly labeled cost-weighted estimate from local Claude JSONL logs.
- **Codex CLI** — prefers the official local Codex `app-server` JSON-RPC method `account/rateLimits/read` for current quota. Local rollout JSONL remains a fallback only; expired rollout windows are never labeled `LIVE`. No quota estimation and no direct private ChatGPT backend call.
- **Antigravity** — reads real quota summary data from the local Antigravity 2.x `language_server` while the desktop app is running. A signed-in, already-running `agy` CLI process is also supported as a local fallback. CaliphBar does not scrape the Antigravity UI and does not call Google's remote OAuth quota endpoints.
- **Codex Radar public intelligence** — polls the public structured summary separately from account truth, exposes a compact Radar signal, deduplicates meaningful reset-signal notifications, and can correlate a public event with a large real local Codex quota reset without uploading private quota history.

## UI and interaction

- smaller draggable floating edge pill with provider rings; the default three-row rail is `62 × 288` points and the optional four-row Radar layout is `62 × 328`
- continuous custom Bezier silhouette that docks flush to the physical left/right display edge
- remembers vertical position and dock side
- optional hover-to-expand mode
- provider hover switches the compact detail card and glides its pointer to the active row
- compact side detail card uses one stable outer size across providers
- full menu-bar panel with equal-width provider tabs and aligned Settings controls
- custom transparent `NSPanel` surfaces, not `NSPopover`
- session/weekly bars with reset times
- `LIVE`, `STALE`, `ESTIMATED`, and `OFFLINE` source states
- Chinese / English / Follow System language options
- menu-bar percentage follows the current provider selection
- Codex pill can show a separate Radar signal dot; the dot never changes the real account percentage
- optional independent Radar rail module, explicit left/right docking, and a center-position reset
- progressive provider refresh feedback instead of waiting for the slowest source before updating the UI

## Other features

- one local notification per quota window after crossing the configured threshold
- Codex Radar transition notifications for meaningful public reset-signal escalation
- launch at login via `SMAppService`
- 60-second account refresh plus manual refresh
- 5-minute Codex Radar refresh with an independent cache
- persisted last-known-good live account snapshots
- Universal Binary build: Apple Silicon + Intel

## Requirements

- macOS 13+
- Xcode or Xcode Command Line Tools
- Claude Code, Codex CLI, and/or Antigravity installed and signed in on the Mac

## Build

```bash
./build-app.sh
open CaliphBar.app
```

The script creates an ad-hoc-signed Universal Binary with bundle identifier:

```text
dev.chengyu.caliphbar
```

Install to Applications and launch:

```bash
./install.sh
```

For Xcode development, open `Package.swift` in Xcode. This is a SwiftPM project; no generated `.xcodeproj` is required.

## Data sources

### Claude

CaliphBar checks, in order:

1. `~/.claude/.credentials.json`
2. the macOS Keychain service `Claude Code-credentials` using a **non-interactive** background read
3. `GET https://api.anthropic.com/api/oauth/usage`
4. a recent cached live snapshot when a refresh fails
5. local Claude transcript cost estimation only when no fresh live snapshot can be preserved

If the Keychain item requires authorization, background refresh fails closed instead of presenting a surprise macOS permission prompt. Use **Settings → Repair Access** to explicitly request authorization.

The estimator labels its result `ESTIMATED`; it is never presented as an exact quota reading.

### Codex

CaliphBar now prefers a fresh local query through the official Codex CLI process:

```text
codex -s read-only -a never app-server
```

It performs a bounded read-only JSON-RPC handshake and requests:

```text
account/rateLimits/read
```

The bundled alpha CLI may buffer JSONL stdout while stdin remains open, so CaliphBar closes the one-shot request input after the local snapshot has completed to flush the official response. The returned `rateLimits.primary` / `secondary` values are used for the current session and weekly lanes. This is a local subprocess interaction with the Codex CLI; CaliphBar does not read the Codex OAuth token and does not directly call a private ChatGPT HTTP endpoint.

If the app-server query is unavailable, CaliphBar can inspect the newest `$CODEX_HOME/sessions/**/rollout-*.jsonl` or `~/.codex/sessions/**/rollout-*.jsonl` as a local fallback. Rollout data is historical observation data: a lane whose reset timestamp is already in the past is discarded, and any usable rollout fallback is labeled `STALE`, never `LIVE`.

This distinction prevents an old pre-reset percentage from remaining on screen for hours after Codex has already reset.

### Antigravity

CaliphBar discovers the Antigravity desktop app's local `language_server` process, reads its CSRF token from the process command line, discovers loopback listening ports with `lsof`, and requests:

```text
POST https://127.0.0.1:<port>/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary
```

The local server uses a self-signed certificate. CaliphBar relaxes certificate trust **only** for literal `127.0.0.1` / `localhost` requests and never redirects that trust to a remote host.

The preferred Antigravity 2.x quota summary contains two real quota families (`Gemini Models` and `Claude and GPT models`) with five-hour and weekly buckets. CaliphBar preserves all four real lanes in the main panel and fixed-size hover card. The compact rail headline uses the most constrained visible family so it still warns about the quota that will run out first.

If the desktop app is unavailable, CaliphBar can reuse a signed-in `agy` process that is already running. It intentionally does not launch, own, or kill `agy` in this version. No Google OAuth token is read or stored by CaliphBar.

### Codex Radar

Codex Radar is not an account provider. The current personal build polls the public structured summary:

```text
https://codexradar.com/current.json
```

on a separate five-minute timer and cache. Radar requests contain no Codex credentials and no local quota values. Internally, public Radar status/probability may create a `quiet`, `watch`, `hot`, `stale`, or `offline` signal, but the UI presents these as unambiguous phrases such as `NO RESET SIGNAL` / `暂无重置信号`. Radar probability uses neutral styling and never modifies or visually impersonates the user's real Codex percentage or normal reset timestamp.

If CaliphBar observes a large real quota jump across a reset boundary, it can record a small local confirmation event and correlate it with Radar state. Only percentage/reset metadata is retained locally; it is never uploaded to Codex Radar.

The richer `/api/v1/current` API is not used by the current implementation. Any future distributed/public integration should re-check the source's current terms and attribution requirements rather than assuming private/personal use automatically applies to distribution.

## Product architecture

CaliphBar deliberately separates two kinds of information:

```text
Layer 1 — Account Truth
real, user-specific quota and reset state

Layer 2 — Public Intelligence
community/public reset and model signals
```

Public intelligence may add context and alerts, but it never modifies account-truth percentages or reset timestamps. See `docs/ARCHITECTURE.md`.

## Project layout

```text
Sources/
  CaliphBarCore/
    Models.swift
    Provider.swift
    JSONLReader.swift
    Providers/
      Claude/
      Codex/
      Antigravity/
  CaliphBar/
    App/
    Services/
    UI/
Tests/
  CaliphBarCoreTests/
Resources/
docs/
```

Adding an account provider is intentionally small: implement `UsageProvider`, return the common `ProviderFetchResult`, then add the provider ID and its brand asset. Provider-specific fetching stays out of the shared UI. Public-intelligence sources use a separate model/cache path rather than pretending to be account providers.

## Maintainer / agent documentation

GitHub is the durable source of truth for CaliphBar. New agents and new chats should restore context from the repository rather than relying on conversation memory.

- `AGENTS.md` — mandatory handoff/workflow rules for AI agents and human maintainers
- `docs/ARCHITECTURE.md` — product/data-layer architecture
- `docs/MAINTENANCE.md` — cross-agent maintenance and local-install workflow
- `docs/RELEASE.md` — build/release checklist
- `docs/CODEX_RADAR_INTELLIGENCE.md` — Codex Radar public-intelligence architecture
- `design-qa.md` — durable UI and interaction regression checklist

## Privacy

CaliphBar is local-first. It reads local files already written by Claude Code and Codex CLI. For exact Claude usage it sends the existing Claude OAuth token only to Anthropic's own usage endpoint. Codex live quota is queried through the local Codex CLI app-server. Antigravity usage is read from Antigravity's loopback-only local service. Codex Radar receives only ordinary public-summary GET requests; CaliphBar does not upload private quota data, transcripts, credentials, or usage history to it. CaliphBar does not run a server or send usage data to CaliphBar infrastructure.

Never publish or paste your credential files, Keychain values, OAuth tokens, cookies, CSRF tokens, or API keys into bug reports.

## UI QA

See `design-qa.md` for the interaction/visual regression checklist. CI validates compilation, tests, Universal Binary output, and code-signature verification; visual feel still requires a local macOS pass after material UI changes.

## Notes on development signing

`build-app.sh` uses ad-hoc signing so local builds have a consistent app bundle identity. macOS Keychain grants are still sensitive to code-signature identity, and Claude Code can recreate its foreign Keychain item after updates. A future public release should use a stable Developer ID signature and notarization.

## License

MIT. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

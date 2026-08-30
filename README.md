# CaliphBar

CaliphBar is a lightweight macOS menu-bar monitor for AI coding-tool quota usage. It keeps a draggable edge-docked pill on screen, opens custom `NSPanel` detail surfaces, and supports Chinese/English UI with a system-language default.

## Current scope

- **Claude Code** — exact account usage from Anthropic's OAuth usage endpoint when Claude Code credentials are available. Background Keychain reads are non-interactive. If exact usage is temporarily unavailable, CaliphBar prefers a recent last-known-good live snapshot; only then does it fall back to a clearly labeled cost-weighted estimate from local Claude JSONL logs.
- **Codex CLI** — reads real `rate_limits.primary/secondary.used_percent` and reset timestamps from the newest `~/.codex/sessions/**/rollout-*.jsonl`. No quota estimation and no private ChatGPT backend call.
- **Antigravity** — reads real quota summary data from the local Antigravity 2.x `language_server` while the desktop app is running. A signed-in, already-running `agy` CLI process is also supported as a local fallback. CaliphBar does not scrape the Antigravity UI and does not call Google's remote OAuth quota endpoints.

## UI and interaction

- draggable floating edge pill with provider rings
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

## Other features

- one local notification per quota window after crossing the configured threshold
- launch at login via `SMAppService`
- 60-second background refresh plus manual refresh
- persisted last-known-good live snapshots
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

CaliphBar looks under `$CODEX_HOME/sessions` or `~/.codex/sessions`, finds the most recently modified `rollout-*.jsonl`, and reads the latest `payload.rate_limits` event. It reads a small file tail first and falls back to streaming the file if needed, avoiding a full in-memory copy of large rollouts.

CaliphBar does not use a private ChatGPT usage endpoint for Codex quota monitoring.

### Antigravity

CaliphBar discovers the Antigravity desktop app's local `language_server` process, reads its CSRF token from the process command line, discovers loopback listening ports with `lsof`, and requests:

```text
POST https://127.0.0.1:<port>/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary
```

The local server uses a self-signed certificate. CaliphBar relaxes certificate trust **only** for literal `127.0.0.1` / `localhost` requests and never redirects that trust to a remote host.

The preferred Antigravity 2.x quota summary contains two real quota families (`Gemini Models` and `Claude and GPT models`) with five-hour and weekly buckets. CaliphBar uses the most constrained known family for each cadence as the compact session/weekly monitor, so the pill errs on the side of warning about the quota that will run out first.

If the desktop app is unavailable, CaliphBar can reuse a signed-in `agy` process that is already running. It intentionally does not launch, own, or kill `agy` in this version. No Google OAuth token is read or stored by CaliphBar.

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
```

Adding a provider is intentionally small: implement `UsageProvider`, return the common `ProviderFetchResult`, then add the provider ID and its brand asset. Provider-specific fetching stays out of the shared UI.

## Privacy

CaliphBar is local-first. It reads local files already written by Claude Code and Codex CLI. For exact Claude usage it sends the existing Claude OAuth token only to Anthropic's own usage endpoint. Antigravity usage is read from Antigravity's loopback-only local service. CaliphBar does not run a server, upload transcripts, or send usage data to CaliphBar infrastructure.

Never publish or paste your credential files, Keychain values, OAuth tokens, cookies, CSRF tokens, or API keys into bug reports.

## UI QA

See `design-qa.md` for the interaction/visual regression checklist. CI validates compilation, tests, Universal Binary output, and code-signature verification; visual feel still requires a local macOS pass after material UI changes.

## Notes on development signing

`build-app.sh` uses ad-hoc signing so local builds have a consistent app bundle identity. macOS Keychain grants are still sensitive to code-signature identity, and Claude Code can recreate its foreign Keychain item after updates. A future public release should use a stable Developer ID signature and notarization.

## License

MIT. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

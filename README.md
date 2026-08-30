# CaliphBar

CaliphBar is a lightweight macOS menu-bar monitor for AI coding-tool quota usage. It keeps an always-visible edge pill on screen, opens a custom `NSPanel` for details, and synchronizes the menu-bar percentage with the currently selected provider.

## v0.1 scope

- **Claude Code** — exact account usage from Anthropic's OAuth usage endpoint when Claude Code credentials are available. Background Keychain reads are non-interactive. If exact usage is temporarily unavailable, CaliphBar prefers a recent last-known-good live snapshot; only then does it fall back to a clearly labeled cost-weighted estimate from local Claude JSONL logs.
- **Codex CLI** — reads real `rate_limits.primary/secondary.used_percent` and reset timestamps from the newest `~/.codex/sessions/**/rollout-*.jsonl`. No quota estimation.
- **Gemini** — visible placeholder only; intentionally not implemented in v0.1.

## UI

- draggable floating edge pill with provider rings
- snaps to the nearest left/right screen edge and remembers position
- custom transparent `NSPanel` detail window, not `NSPopover`
- session/weekly bars with reset countdowns
- `LIVE`, `STALE`, `ESTIMATED`, and `OFFLINE` source states
- menu-bar percentage follows the selected provider

## Other features

- one local notification per quota window after crossing 90%
- launch at login via `SMAppService`
- 60-second background refresh plus manual refresh
- persisted last-known-good live snapshots
- Universal Binary build: Apple Silicon + Intel

## Requirements

- macOS 13+
- Xcode or Xcode Command Line Tools
- Claude Code and/or Codex CLI installed and used on the Mac

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

If the Keychain item requires authorization, background refresh fails closed instead of presenting a surprise macOS permission prompt. Use **Settings → Repair Claude Keychain Access** to explicitly request authorization.

The estimator scans configured Claude project roots and labels the result `ESTIMATED`; it is never presented as an exact quota reading.

### Codex

CaliphBar looks under `$CODEX_HOME/sessions` or `~/.codex/sessions`, finds the most recently modified `rollout-*.jsonl`, and reads the latest `payload.rate_limits` event. It reads a small file tail first and falls back to streaming the file if needed, avoiding a full in-memory copy of large rollouts.

## Project layout

```text
Sources/
  CaliphBarCore/
    Models.swift
    Provider.swift
    Providers/
      Claude.swift
      Codex.swift
      Gemini.swift
  CaliphBar/
    App.swift
    Services.swift
    UI.swift
Tests/
  CaliphBarCoreTests/
```

Adding a provider is intentionally small: implement `UsageProvider`, return the common `ProviderFetchResult`, then add the provider ID and its UI glyph. Provider-specific fetching stays out of the shared UI.

## Privacy

CaliphBar is local-first. It reads local files already written by Claude Code and Codex CLI. For exact Claude usage it sends the existing Claude OAuth token only to Anthropic's own usage endpoint. It does not run a server, upload transcripts, or send usage data to CaliphBar infrastructure.

Never publish or paste your credential files, Keychain values, OAuth tokens, cookies, or API keys into bug reports.

## Notes on development signing

`build-app.sh` uses ad-hoc signing so local builds have a consistent app bundle identity. macOS Keychain grants are still sensitive to code-signature identity, and Claude Code can recreate its foreign Keychain item after updates. A future public release should use a stable Developer ID signature and notarization.

## License

MIT. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

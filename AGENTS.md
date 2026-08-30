# CaliphBar Agent Guide

This file is the durable handoff contract for any AI agent or human maintaining CaliphBar.
GitHub `main` is the source of truth. Never rely on chat memory as the authoritative state of the project.

## Start every task this way

1. Read `README.md`, this file, and any relevant file under `docs/`.
2. Fetch the latest repository state and inspect `main`, recent commits/PRs, CI status, and the working tree before changing code.
3. If a local working tree contains uncommitted changes, preserve them. Do not reset, checkout over, or discard them without explicit approval.
4. Confirm the current behavior from code before proposing a fix. Do not assume an earlier chat description still matches `main`.

Recommended local preflight:

```bash
git fetch origin
git checkout main
git pull --ff-only origin main
git status
git log -5 --oneline
```

## Ownership model

CaliphBar is intentionally multi-agent friendly:

- GitHub = durable project memory and canonical code.
- ChatGPT / Codex / Antigravity / Claude = interchangeable maintainers.
- The user should not have to manually coordinate Git mechanics for routine work.

When a change can be completed through GitHub, the agent should normally perform: branch → edit → test/CI → PR → merge.
When final verification requires the user's Mac, provide one copy-paste local-agent instruction that only pulls, builds, installs, launches, and reports results.

## Branch and merge workflow

- Keep `main` buildable.
- Use a focused branch for non-trivial changes.
- Prefer small, reviewable commits with descriptive messages.
- Open a PR for functional or material UI changes.
- Merge only after required CI is green.
- Do not bypass a failing test by deleting or weakening it unless the behavior itself is intentionally changing and the replacement test documents that change.

## Required verification

For code changes, verify as applicable:

```bash
swift test
./build-app.sh
lipo -info CaliphBar.app/Contents/MacOS/CaliphBar
codesign --verify --deep --strict CaliphBar.app
```

GitHub Actions is the authoritative macOS compile/build gate when the current agent is not running on macOS.
Material UI changes additionally require the local visual/interaction pass in `design-qa.md`.

## Product architecture rules

CaliphBar has two deliberately separate data layers.

### Layer 1 — Account Truth

Private/local account-specific quota truth. This layer answers: **"What is my real quota right now?"**

- Claude Code: Anthropic usage when available; stale/estimated fallbacks must be explicitly labeled.
- Codex: real local `rollout-*.jsonl` rate-limit data; never fabricate or estimate when real data is unavailable.
- Antigravity: real local loopback quota summary from the running Antigravity service / supported local fallback.

Never mix public/community predictions into these percentages or reset timestamps.

### Layer 2 — Public Intelligence

Public/community intelligence answers: **"Is something unusual happening globally, and should I care?"**

Examples: Codex Radar reset signals, public reset-window evidence, historical reset distributions, model/community intelligence.
This layer must always be visually and semantically distinct from account truth.
See `docs/CODEX_RADAR_INTELLIGENCE.md`.

## Provider safety rules

### Codex

- Keep the default provider local-first.
- Read real local `rate_limits` data.
- Do not estimate Codex quota.
- Do not add private ChatGPT backend calls merely for convenience when local truth is sufficient.
- Never attempt to bypass or extend quota limits.

### Claude

- Background Keychain access must remain non-interactive.
- Only an explicit user action may trigger a macOS authorization prompt.
- Never print/store OAuth tokens in logs, screenshots, issue bodies, or diagnostics.
- `LIVE`, `STALE`, `ESTIMATED`, and `OFFLINE` are materially different states and must remain distinguishable.

### Antigravity

- Prefer the local loopback `language_server` path.
- Local TLS trust relaxation must be limited to literal `127.0.0.1` / `localhost`.
- Do not scrape the Antigravity UI.
- Do not expose CSRF tokens or credentials in logs or bug reports.
- Do not silently introduce a remote Google OAuth quota path without an explicit product decision.

## UI rules

- Use custom `NSPanel`, not `NSPopover`, for the existing floating/detail surfaces.
- The edge pill is one continuous custom path, not `Capsule + connector`.
- Left/right docking must remain mirrored.
- Provider switching must not resize the compact detail card.
- Hover selection should glide smoothly and only update when the active provider actually changes.
- Settings must remain reachable from the full menu-bar panel.
- Support Simplified Chinese, English, and Follow System; do not introduce new user-visible hard-coded English strings.
- Motion should feel restrained and instrument-like: short ease-out transitions for data/content, spring only for tactile pill interactions.

For visual regression rules, read `design-qa.md` before changing UI.

## Public intelligence / third-party data

Before integrating any third-party public JSON/API:

1. Verify the endpoint and current schema from a live source or official documentation.
2. Check attribution and derivative-use requirements.
3. Do not assume "publicly reachable" means unrestricted redistribution.
4. Add timeouts, cache, stale-state handling, and schema-version tolerance.
5. Never let a public-data outage degrade Layer 1 account-truth monitoring.
6. Distinguish source facts from CaliphBar-derived interpretations.

## Local installation handoff template

After code is merged, if the user needs a local Mac verification, give a short instruction like:

```text
Do not modify source code.

cd Caliph-Bar
git checkout main
git pull --ff-only origin main
git rev-parse HEAD

./build-app.sh
./install.sh
pkill CaliphBar 2>/dev/null || true
open /Applications/CaliphBar.app

Verify the requested behavior and report results. Do not commit or push changes.
```

Include the expected `main` commit SHA when reproducibility matters.

## Documentation responsibility

When architecture, providers, release steps, data-source semantics, or durable interaction rules change, update the relevant documentation in the same PR. A future maintainer should be able to restore project context from the repository without needing the original chat transcript.

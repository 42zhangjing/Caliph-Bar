# Codex Radar Intelligence Layer

Status: **V1 runtime implemented for the personal CaliphBar build.**

CaliphBar keeps Codex Radar completely separate from account quota truth. The current implementation polls the public structured summary at `https://codexradar.com/current.json` every five minutes, keeps an independent cache, shows a compact Radar signal on the Codex pill, and can send deduplicated notifications when the public signal materially escalates.

The richer `/api/v1/current` endpoint is **not** used by the current implementation. If CaliphBar is later distributed publicly or commercialized, re-check the source's then-current terms, attribution expectations, and rate guidance rather than assuming personal/private use rules carry over.

## Non-negotiable separation

```text
Layer 1 — Account Truth                 Layer 2 — Public Intelligence
──────────────────────                  ─────────────────────────────
My real 5-hour remaining                Global/community reset signal
My real weekly remaining                24h / 48h reset probability
My exact account reset timestamp        Public event state
My provider source state                Historical reset pattern
```

A Radar prediction must never alter the user's real Codex percentage or normal reset timestamp.

## V1 data source

Current personal build:

```text
GET https://codexradar.com/current.json
```

Properties of the integration:

- five-minute polling, not the 60-second account-provider cadence
- ephemeral `URLSession`
- no Codex OAuth token, cookie, credential, transcript, or local quota value is sent
- parser accepts unknown fields and several camelCase/snake_case variants
- last-known-good Radar data is cached independently from provider snapshots
- public-intelligence failure cannot block Claude/Codex/Antigravity account refresh

Do not scrape rendered HTML when a usable structured source is available.

## RESET SIGNAL

CaliphBar maps public source evidence into a deliberately small state machine:

```text
QUIET    weak/no actionable signal
WATCH    meaningful evidence/probability
HOT      active/high-confidence/open-window signal
STALE    cached intelligence is too old
OFFLINE  no usable Radar source/cache
```

The edge pill shows only a small signal dot next to the **real Codex remaining percentage**. The quota number itself always comes from Layer 1.

Current default interpretation includes:

- explicit open window -> `HOT`
- strong/high/confirmed/active source language -> `HOT`
- 24h probability >= 65% -> `HOT`
- watch/medium/likely/pending/possible language -> `WATCH`
- 24h probability >= 35% -> `WATCH`
- otherwise -> `QUIET`

These thresholds are CaliphBar presentation policy, not Codex Radar claims. If the source later defines authoritative levels, prefer the source semantics and document the mapping.

## Notifications

Notify on meaningful **state transitions**, not every polling result.

Examples:

```text
QUIET -> WATCH
WATCH -> HOT
```

First launch never replays an already-existing old signal. A small persisted state fingerprint prevents restart spam.

Example notification:

```text
Codex Reset Radar
检测到高强度额度重置信号
```

or, when an explicit public window is open:

```text
Codex Reset Radar
检测到新的额度重置窗口信号
```

## Personal Confirmation

CaliphBar can correlate public intelligence with the user's **real local Codex quota change**, entirely on-device.

Example:

```text
RESET CONFIRMED LOCALLY

weekly remaining
7% -> 100%
```

Current detector stores only a tiny rolling record:

```text
session remaining
weekly remaining
session reset timestamp
weekly reset timestamp
observed time
```

A local confirmation requires a large upward quota jump plus reset-boundary evidence. Conversation content is never stored for this feature, and the observation is never uploaded to Codex Radar.

This creates a trust hierarchy:

1. Radar says something may be happening globally.
2. CaliphBar reads the user's real account quota locally.
3. If the local quota actually jumps across a reset boundary, CaliphBar can call it confirmed on this Mac.

## Historical pattern

Historical distributions are context, not forecasts.

Prefer:

```text
HISTORICAL WINDOW
00:00–08:59
21 / 34 historical resets
```

Do not rename that to `NEXT RESET` unless the source itself provides a real predicted window. This avoids false precision.

## Optional future UI

A later full-panel treatment may show a restrained detail strip:

```text
RESET RADAR     WATCH
24H             42%
updated         07:20
source          Codex Radar
```

The menu-bar/edge pill should remain compact. Detailed IQ, cost, model-health, history, or benchmark views belong behind the full panel or an external source link.

## Optional Phase 2 — Model Health

Codex Radar exposes broader model/community intelligence. CaliphBar may later surface one tiny actionable state such as:

```text
MODEL HEALTH
Sol xhigh   ↓ degraded
```

Do not turn CaliphBar into a general benchmark dashboard.

## Privacy

Radar requests are public-data reads. They contain no Claude/Codex/Antigravity credentials and no account quota values.

Personal Confirmation is computed entirely on-device. CaliphBar must never upload private quota history to the Radar source.

## Attribution and distribution

For the current personal build, keep the source identity visible in code/UI help and source links. If the project is distributed publicly or commercialized later, re-check Codex Radar's current terms and requested attribution/rate policy before release.

## Definition of done for V1

- account truth and Radar are semantically separate
- live Codex quota is not sourced from Radar
- public structured Radar source is polled independently
- transition notifications are deduplicated
- stale/offline states fail safely
- Radar failure cannot break account providers
- private quota history is never uploaded
- large local quota resets can be confirmed on-device

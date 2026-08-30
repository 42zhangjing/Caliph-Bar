# Codex Radar Intelligence Layer

Status: design approved in principle; live integration should respect Codex Radar's current authorization/attribution requirements before being enabled in a distributed build.

## Why this is a separate layer

CaliphBar already has account truth: real local/account quota, reset time, and state for the current user.
Codex Radar is different. It is **public/community intelligence** about broader Codex events and model conditions.

Never merge these semantics:

```text
Account Truth                       Public Intelligence
─────────────                       ───────────────────
My 5-hour remaining                 Global reset signal
My weekly remaining                 24h / 48h reset probability
My exact reset timestamp            Official/community event state
My provider state                   Historical reset pattern
```

A Radar prediction must never alter the user's real Codex percentage or normal reset timestamp.

## Data-source policy

The public Codex Radar summary has been observed at:

```text
https://codexradar.com/current.json
```

The summary advertises a richer endpoint:

```text
https://codexradar.com/api/v1/current
```

The public payload includes an `api_access` section stating that the full JSON API and derivative integrations require authorization and that attribution is required. Before enabling a distributable CaliphBar integration, confirm permission/current terms with the Codex Radar operator and preserve the requested attribution.

Do not scrape the rendered website when a structured authorized/public source is available.

## V1 UI — deliberately small

The first public-intelligence UI should answer three questions only.

### 1. RESET RADAR

Shows the source's current reset/event state without pretending it is the user's natural quota reset.

Example:

```text
RESET RADAR

额外重置信号
● 暂无开启窗口

24 小时概率
36%

状态更新
18:39
```

When the source exposes an explicit official/community event state, prefer that wording over CaliphBar inventing a new interpretation.

### 2. RESET SIGNAL

A compact indicator next to Codex:

```text
Codex   64%   Radar ●
```

Recommended display states:

- QUIET — no active reset window / weak evidence
- WATCH — meaningful probability/evidence, but no explicit open window
- HOT — source reports an active/high-confidence reset event or official signal
- STALE — source data is older than the accepted freshness threshold
- OFFLINE — no source and no usable cache

Important: do not blindly map a field named `level` to these labels without documenting its current source semantics. Preserve the original probability and status in the detail view.

### 3. Reset-event notification

Notify on meaningful **state transitions**, not on every polling result.

Examples:

```text
Codex Reset Radar
检测到新的额度重置信号
24 小时概率：68%
```

or, when the source has an explicit window:

```text
Codex Reset Radar
检测到官方/社区确认的重置窗口
点击查看来源与更新时间
```

Do not notify on app startup for an already-known old event.

## Stronger idea: Personal Confirmation

This is more valuable than another prediction gauge.

CaliphBar can correlate a public Radar event with the user's **local real Codex quota change** without sending private quota data anywhere.

Example:

```text
RESET CONFIRMED LOCALLY

你的周额度
7% → 100%

Radar
社区确认重置

时间差
+3 min
```

This creates a clear hierarchy:

1. Radar says something may be happening globally.
2. CaliphBar observes the user's real local quota.
3. If the real quota jumps across a reset boundary, CaliphBar can say **confirmed on this Mac**.

This is a local derived fact and is substantially more trustworthy than presenting community prediction as account truth.

Implementation note: persist a tiny rolling quota-state record (percentage, reset timestamp, observed time), never conversation content. Detect large upward quota discontinuities with reset-timestamp changes and protect against parser/source glitches with consecutive-sample validation.

## Historical pattern — label it correctly

Historical reset-hour distributions can be useful, but they should not be called a forecast unless the source itself provides a forecast.

Prefer:

```text
HISTORICAL WINDOW
00:00–08:59
21 / 34 historical resets
```

instead of:

```text
NEXT RESET
08:00–09:00
```

unless there is an actual source-backed predicted time window.

This avoids false precision.

## Optional phase 2: Model Health

Codex Radar also exposes model/community intelligence. A later CaliphBar version could add one tiny secondary indicator:

```text
MODEL HEALTH
Sol xhigh   ↓ degraded
```

Only surface this when the signal is genuinely actionable. Do not turn the small quota utility into a full benchmark dashboard.

A useful rule: the menu-bar/edge pill is for **quota + urgent intelligence**; detailed IQ/cost/history belongs behind the full panel or an external link.

## Data model

Recommended independent model:

```swift
struct RadarSnapshot {
    let schemaVersion: String?
    let monitoredAt: Date
    let window: RadarWindow?
    let prediction: RadarPrediction?
    let sourceURL: URL?
    let attribution: String
    let fetchedAt: Date
    let freshness: RadarFreshness
}
```

Do not reuse `ProviderSnapshot`; Radar is not an account provider.

## Fetch/caching strategy

Recommended default once authorized:

- refresh every 5–10 minutes, not every 60 seconds
- manual refresh shares the same in-flight request
- 3–5 second network timeout
- store last-known-good Radar payload separately
- use ETag / Last-Modified if the server provides them
- accept unknown JSON fields for forward compatibility
- honor `schema_version`; fail safely on incompatible major versions
- mark cache `STALE` after a defined age (for example 30–60 minutes)
- account providers continue refreshing even when Radar is offline

The exact polling rate must respect the source operator's authorization/rate guidance.

## Notification state machine

Persist a small event fingerprint so restarts do not replay alerts.

Suggested transition hierarchy:

```text
quiet → watch → hot → confirmed/closed → quiet
```

Notification candidates:

- `quiet → hot`
- explicit official/open-window event appears
- event materially changes predicted window/status
- local quota confirms a public reset

Avoid notification spam for probability changes such as 0.36 → 0.38.

## Privacy

Radar requests contain no Claude/Codex/Antigravity credentials and no local quota values.
Personal Confirmation is computed entirely on-device; CaliphBar must not upload the user's quota history to the Radar source.

## Attribution

When Codex Radar data is displayed, keep visible attribution such as:

```text
数据来自 Codex 雷达 codexradar.com
```

and provide a source link in the detail panel/full panel.

## Definition of done for V1

- account truth and Radar are visually distinct
- authorized/public structured source is used according to current terms
- current event state + probability + freshness are parse-tested
- polling/cache cannot break the Codex local provider
- transition notifications are deduplicated
- stale/offline states are explicit
- source attribution is visible
- local Personal Confirmation is either implemented safely or deferred explicitly

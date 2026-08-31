# CaliphBar Architecture

## Product boundary

CaliphBar is a lightweight macOS menu-bar monitor. It should remain small, local-first, and easy to extend without becoming a multi-provider platform framework.

The central architectural rule is that **account truth and public intelligence are different products inside one app**.

```text
                           CaliphBar
                              │
             ┌────────────────┴────────────────┐
             │                                 │
      Layer 1: Account Truth            Layer 2: Public Intelligence
      "What is my quota?"               "What is happening globally?"
             │                                 │
      Claude / Codex /                  Codex Radar / future
      Antigravity local data            public community signals
             │                                 │
             └──────────── UI composition ─────┘
```

Layer 2 may add context, alerts, or probabilities, but must never overwrite or reinterpret Layer 1 quota percentages and reset timestamps as if they were account facts.

## Core model

Provider implementations produce the common `ProviderFetchResult` / `ProviderSnapshot` model. Shared UI consumes snapshots and should not contain provider-specific networking or credential logic.

A provider owns:

- source discovery
- authentication/credential boundary
- parsing
- fallback behavior
- error semantics

Shared app services own:

- scheduling / refresh coordination
- last-known-good cache
- notifications
- launch at login
- selection and presentation state

## Account-truth providers

### Claude

Preferred live usage comes from Anthropic using Claude Code credentials. Background Keychain reads are deliberately non-interactive. If live usage fails, a recent live snapshot may be shown as `STALE`; only when appropriate can local transcript cost estimation appear, and it must be labeled `ESTIMATED`.

### Codex

CaliphBar prefers the official local Codex `app-server` JSON-RPC method `account/rateLimits/read`. A successful RPC response is account truth and is labeled `LIVE`; no Codex OAuth token is read by CaliphBar and no private ChatGPT HTTP usage endpoint is called directly.

The bundled alpha CLI currently buffers JSONL stdout while its stdin remains open on some macOS installations. CaliphBar therefore performs a bounded, read-only one-shot handshake and snapshot request, closes stdin to flush the official response, and repeats this local snapshot on the normal refresh interval. Providers publish progressively, so this Codex read never blocks Claude or Antigravity from updating first.

The app-server response contains the ordinary five-hour and weekly windows and may also expose a multi-bucket `rateLimitsByLimitId` map. Model-specific buckets such as Codex Spark are surfaced as additional account-truth windows rather than collapsed into the ordinary two lanes. Window duration metadata is preferred over transport slot order when deciding whether a lane is five-hour or weekly.

Local `rollout-*.jsonl` rate-limit observations are fallback evidence only. Expired lanes are discarded and any usable rollout fallback is labeled `STALE`, never `LIVE`.

### Antigravity

CaliphBar discovers the running Antigravity local language server and requests the loopback quota summary. It can use a supported already-running local fallback. Local self-signed TLS trust relaxation is constrained to loopback hostnames only.

## Public-intelligence layer

Public intelligence should be implemented independently from the provider snapshot pipeline so a third-party outage cannot make Claude/Codex/Antigravity appear unavailable.

Recommended components:

```text
RadarClient
  ├─ fetch public summary
  ├─ optional authorized API
  └─ schema validation

RadarCache
  ├─ last good payload
  ├─ ETag/Last-Modified when available
  └─ stale age

RadarInterpreter
  ├─ pass through source status/evidence
  ├─ derive presentation-safe severity
  └─ never invent source facts

RadarNotifier
  ├─ state-transition deduplication
  └─ high-value alerts only
```

See `docs/CODEX_RADAR_INTELLIGENCE.md` for the current design.

## UI surfaces

- Floating edge pill: quick provider state and remaining quota.
- Compact side detail panel: fixed-size provider details; hover switching should glide rather than resize. Codex may show up to four quota lanes when model-specific limits are returned.
- Full menu-bar panel: provider tabs, settings, richer information with the same stable footprint across provider switching.
- Public intelligence should be secondary to the account quota: a small Radar indicator in the Codex view, with details on demand.

## Persistence

UserDefaults is appropriate for lightweight UI preferences and current selection. Last-known-good account snapshots are cached separately. Public-intelligence cache must be separate from account snapshot cache so schemas and stale policies can evolve independently.

## Networking principles

- Every network request has a bounded timeout.
- Failure should preserve recent useful data when semantically safe.
- Stale data is labeled.
- Loopback TLS exceptions never apply to remote hosts.
- Credentials and secret headers never enter diagnostics.
- Public endpoints are treated as third-party dependencies and cannot block the account-truth refresh path.

## Extending CaliphBar

For a new account provider, implement `UsageProvider` and keep provider-specific code isolated.
For a new public-intelligence source, do **not** add it as a fake account provider. Add it to the intelligence layer with its own model/cache/notifications and compose it into the appropriate UI.

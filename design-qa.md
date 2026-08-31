# CaliphBar UI / Interaction QA

This document records the durable design constraints for the floating edge pill and its detail panels. It intentionally avoids machine-specific screenshots, temporary file paths, and claims that cannot be verified in CI.

## Floating edge pill

- The pill is one continuous custom `Path`, not a capsule plus a connector.
- The screen-facing closing edge bleeds slightly beyond the physical display edge so no separate vertical seam is visible.
- The free-facing edge uses a restrained two-stage cubic Bezier transition at the top and bottom, with a long straight middle body.
- Left/right docking must be exact horizontal mirrors.
- Provider rows use one shared geometry source (`SideNotchLayout`) for visual layout and pointer anchoring.
- Collapsed mode must not leave a large invisible hit target over other apps.

## Hover interaction

- Moving the pointer between Claude, Codex, and Antigravity updates the compact detail card only when the active provider row changes.
- The compact detail card keeps one fixed outer size across providers; only its content cross-fades and the window position glides to the new provider row.
- Codex may expose up to four account-truth quota rows (ordinary 5-hour/weekly plus model-specific rows such as Spark); their appearance must not resize the card.
- The compact Codex card may show a small Radar badge in its header, but must not mix Radar state into quota percentages or reset timestamps.
- The pointer tip remains vertically aligned with the active provider row.
- Moving from the pill into its compact detail card must not collapse the pill underneath the pointer.
- Hover work is rate-limited so duplicate local/global `mouseMoved` events do not cause repeated animations.

## Menu-bar panel and settings

- Clicking the menu-bar item always opens the full panel, even if a compact side panel is already visible.
- The full panel and side panel are distinct panel modes and must rebuild their root view when the mode changes.
- Settings must remain reachable from the full panel through the gear button.
- Provider tabs use equal widths and a shared selected highlight.
- Provider tabs expose a full-height hit target and hover feedback; the visible segment and clickable area must match.
- Settings controls share one aligned right-hand control column.
- Provider/settings switching keeps a stable panel footprint to avoid visible size jumps.
- The Codex full panel must visibly include the independent `RESET RADAR` detail strip even when Codex account quota is unavailable; public intelligence and account truth fail independently.

## Motion language

- Use short, restrained ease-out motion for provider/content changes.
- Reserve spring motion for tactile pill reveal/press interactions only.
- Quota ring and bar changes interpolate smoothly but should not bounce.
- Avoid animation replay when a value has not changed.

## Data semantics

- Current product semantics display **remaining quota**, not used quota.
- Codex `LIVE` data comes from the official local app-server `account/rateLimits/read`; model-specific `rateLimitsByLimitId` buckets are still account truth, not Radar intelligence.
- Codex rollout JSONL is STALE-only fallback; expired rollout lanes must not be displayed.
- Claude may show live, stale, estimated, or unavailable state according to its provider fallback rules.
- Antigravity uses real local quota-summary data when available; it is not a simulated Gemini placeholder.
- Public intelligence such as Codex Radar must remain visually separate from real account quota. A Radar signal may annotate Codex but must not alter the user's local percentage or reset timestamp.
- Radar probabilities are neutral information, not account health. Do not apply the account-quota red/yellow/green ring thresholds to Radar percentages; reserve yellow/red Radar accents for watch/strong signals.
- User-facing Radar states must be explicit (`暂无重置信号`, `值得关注`, `强重置信号`, `数据超2小时未更新`, `情报离线`) rather than ambiguous labels such as `QUIET` or `情报已过期`.
- `LOCAL RESET CONFIRMATION` is a correlation label: show it only when a fresh local Codex quota jump is paired with an active public Radar `WATCH` or `HOT` signal.

## Verification gates

CI verifies:

- core parser tests
- app compilation
- Universal Binary build (`arm64` + `x86_64`)
- bundle code-signature verification

CI does **not** prove visual quality or interaction feel. After material UI changes, perform one local macOS pass covering:

1. right-side dock
2. left-side dock
3. Claude → Codex → Antigravity hover sweep; side-card size must remain unchanged
4. when Codex returns model-specific buckets, verify all four quota rows are readable and correctly labeled
5. confirm the compact Codex side card shows the Radar badge without crowding the LIVE/STALE indicator
6. confirm the full Codex panel visibly shows `RESET RADAR` with an explicit localized state; quiet state must read `暂无重置信号` / `NO RESET SIGNAL`, not `QUIET`
7. confirm Radar remains visible/independent when Codex account truth is unavailable
8. side card → pill pointer movement without collapse
9. menu-bar panel → Settings → back; footprint must remain stable
10. Chinese / English / Follow System
11. auto-collapse and always-expanded modes
12. if Radar is stale/offline: Codex account quota remains unchanged and keeps its own LIVE/STALE semantics
13. if local reset confirmation appears, verify a concurrent Radar WATCH/HOT signal exists

A UI change is considered complete only after both CI and this local interaction pass succeed.

## Instrument Console redesign — 2026-08-31

- Selected source: `docs/design-qa/instrument-console-reference.png`
- Implemented full Codex panel: `docs/design-qa/instrument-console-codex.png`
- Implemented settings: `docs/design-qa/instrument-console-settings.png`
- Implemented four-lane side detail: `docs/design-qa/instrument-console-side-antigravity.png`
- Implemented four-item edge rail with reserved bleed: `docs/design-qa/instrument-console-edge-radar.png`

Comparison history:

1. The selected Instrument Console hierarchy was retained: toolbar, equal-width provider selector, Account Truth, and a separate Public Intelligence surface.
2. The generated reference's large permanent rail was intentionally rejected. The production edge rail remains a compact three-ring monitor and was reduced from `74 × 344` to a visible `62 × 288`; its ring diameter is now 39 points. Enabling the optional fourth Radar module expands visible height only to `62 × 328`. Its curve begins after the 40-point content safety zone, while a separate 6-point off-screen bleed prevents seams without clipping the visible top/bottom endpoints.
3. Settings replaced low-contrast menu pickers and ambiguous white switches with visible segmented controls and explicit ON/OFF labels. Simplified Chinese, English, and Follow System were exercised in the running app.
4. Antigravity now exposes Gemini 5-hour/weekly and Claude/GPT 5-hour/weekly. The fixed hover card grew from 204 to 228 points only after the four-lane screenshot revealed inadequate bottom safety space.
5. Optional Radar pinning adds a fourth compact rail module; disabled remains the default, preserving the small three-row footprint and Codex's tiny Radar status dot.
6. Right and left docking, center reset, auto-collapse handle, provider hover, Radar independence, progressive refresh, and real local Codex app-server data were exercised in the built macOS app.
7. The provider selector and settings segments now use full-size hit regions with hover/press feedback. Numeric quota and probability labels use system monospaced digits to prevent horizontal jitter.
8. Radar probabilities now use a neutral ring/value treatment; only watch/strong states introduce yellow/red urgency. Constrained Radar copy is authored as complete sentences with a `查看完整` link, and the integrated pointer was narrowed for a cleaner silhouette.

Final result: passed.

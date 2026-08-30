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
- The pointer tip remains vertically aligned with the active provider row.
- Moving from the pill into its compact detail card must not collapse the pill underneath the pointer.
- Hover work is rate-limited so duplicate local/global `mouseMoved` events do not cause repeated animations.

## Menu-bar panel and settings

- Clicking the menu-bar item always opens the full panel, even if a compact side panel is already visible.
- The full panel and side panel are distinct panel modes and must rebuild their root view when the mode changes.
- Settings must remain reachable from the full panel through the gear button.
- Provider tabs use equal widths and a shared selected highlight.
- Settings controls share one aligned right-hand control column.
- Provider/settings switching keeps a stable panel footprint to avoid visible size jumps.

## Motion language

- Use short, restrained ease-out motion for provider/content changes.
- Reserve spring motion for tactile pill reveal/press interactions only.
- Quota ring and bar changes interpolate smoothly but should not bounce.
- Avoid animation replay when a value has not changed.

## Data semantics

- Current product semantics display **remaining quota**, not used quota.
- Codex data remains real local `rate_limits` data; no estimation.
- Claude may show live, stale, estimated, or unavailable state according to its provider fallback rules.
- Antigravity uses real local quota-summary data when available; it is not a simulated Gemini placeholder.
- Public intelligence such as Codex Radar must remain visually separate from real account quota. A Radar signal may annotate Codex but must not alter the user's local percentage or reset timestamp.

## Verification gates

CI verifies:

- core parser tests
- app compilation
- Universal Binary build (`arm64` + `x86_64`)
- bundle code-signature verification

CI does **not** prove visual quality or interaction feel. After material UI changes, perform one local macOS pass covering:

1. right-side dock
2. left-side dock
3. Claude → Codex → Antigravity hover sweep
4. side card → pill pointer movement without collapse
5. menu-bar panel → Settings → back
6. Chinese / English / Follow System
7. auto-collapse and always-expanded modes
8. if Radar is enabled: Codex account quota remains unchanged when Radar is stale/offline

A UI change is considered complete only after both CI and this local interaction pass succeed.

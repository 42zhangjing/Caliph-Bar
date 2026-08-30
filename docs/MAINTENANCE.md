# CaliphBar Maintenance Playbook

This is the operational guide for maintaining CaliphBar across different agents, chats, and machines.

## Restoring context in a new chat

A new maintainer should not ask the user to retell the project history. Start from GitHub:

1. Read `README.md`.
2. Read `AGENTS.md`.
3. Read `docs/ARCHITECTURE.md` and the document relevant to the requested area.
4. Inspect latest `main`, recent commits/PRs, and CI.
5. Read the current implementation files before proposing a change.

A useful user prompt for any new chat/agent is:

```text
Continue maintaining my GitHub project 42zhangjing/Caliph-Bar.
First read README.md and AGENTS.md, inspect the latest main commit, recent PRs and CI, and restore project context from the repository. Do not infer current code from chat memory. Then handle my next request.
```

## Routine change workflow

For normal feature/fix work:

```text
main
  ↓
focused branch
  ↓
implementation + tests/docs
  ↓
PR
  ↓
macOS CI
  ↓
merge
  ↓
local Mac install/visual verification when needed
```

Avoid accumulating multiple unrelated UI, provider, and build-system changes into one giant branch.

## Before touching code

Check:

```bash
git status
git branch --show-current
git log -5 --oneline
git fetch origin
git rev-list --left-right --count HEAD...origin/main
```

If there are local changes, report them and preserve them. Never solve divergence with `git reset --hard` unless explicitly approved.

## After merging: local install handoff

The user often uses a local coding agent to install/test. Do not ask that agent to redesign or modify the just-merged implementation. Give it a constrained instruction:

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

Verify the requested behavior and report screenshots/results only. Do not commit or push changes.
```

Add the expected commit SHA if the exact build matters.

## Debugging data providers

### Claude

Report only non-secret state such as credentials found/not found, source state, percentages, reset times, and user-facing errors. Never dump credential JSON or Keychain values.

### Codex

Inspect only the structural `rate_limits` fields needed for usage. Never print conversation text from rollout logs. Missing real quota data should remain unavailable, not estimated.

### Antigravity

It is acceptable to inspect process names, PIDs, loopback listening ports, response status, and sanitized quota bucket metadata. Never print CSRF tokens or other secrets.

## Public data source maintenance

For Codex Radar or future public-intelligence sources:

- verify current endpoint/schema before coding against it
- respect attribution and authorization terms
- use a separate cache
- tolerate unknown/additional fields
- prefer source-provided severity/probability over inventing a competing prediction model
- store enough state to deduplicate notifications across app restarts
- an outage must not affect account quota providers

## UI regression maintenance

Read `design-qa.md` before changing the pill/detail surfaces. Static screenshots are not sufficient for motion/hover changes. After CI, perform a short local interaction pass and, when motion is the issue, prefer a 5–10 second screen recording over repeated still images.

## Dependency discipline

CaliphBar should remain lightweight. Before adding a package/framework, ask whether Foundation/AppKit/SwiftUI can do the job cleanly. Avoid dependencies that add large transitive trees for a small feature.

## Documentation drift

Whenever a provider, endpoint, fallback order, UI invariant, or build/release step changes, update the durable docs in the same PR. In particular, remove stale words such as "placeholder" when a provider becomes real.

# V1.1 task board

V1.1 brings everything into one codebase: one Cloudflare backend, one Better Auth setup, one Kotlin
Multiplatform module for the business logic, and native views on top (SwiftUI + Apple Maps on iOS,
Compose + OpenStreetMap on Android). See `/CLAUDE.md` for the architecture rule.

## Board

| ID | Feature | Owner | Status | Depends on | Branch |
|----|---------|-------|--------|------------|--------|
| [F0](F0-foundation.md) | Foundation: shared module, API client, place identity | _unassigned_ | todo | none | `feat/F0-foundation` |
| [F1](F1-auth.md) | Auth & onboarding (Better Auth) | _unassigned_ | todo | F0 | `feat/F1-auth` |
| [F2](F2-map-discovery.md) | Map & place discovery | _unassigned_ | todo | F0 | `feat/F2-map` |
| [F3](F3-accessibility-info.md) | Accessibility information (place detail) | _unassigned_ | todo | F0, F2 for navigation | `feat/F3-accessibility` |
| [F4](F4-contribute-forms.md) | Contribute: review forms & photos | _unassigned_ | todo | F0, F1 to submit | `feat/F4-contribute` |
| [F5](F5-profile.md) | Profile, saved places, my reviews | _unassigned_ | todo | F0, F1 | `feat/F5-profile` |

Status values: `todo` → `in progress` → `in review` → `done`.

**F0 has to land first.** It creates `Mobile/shared`, the API client and the platform-neutral place IDs that
everything else builds on. Once it's merged, F1–F5 can run in parallel. F4 and F5 can use a dev token
until F1 is merged.

## How to pick up a task

1. **Claim it.** Put your name in the Owner column, set Status to `in progress`, and push that change to `V1.1`
   (or open a draft PR) so no one else takes it.
2. **Branch.** `git checkout V1.1 && git pull && git checkout -b feat/F3-accessibility`
3. **Hand it to the agent.** In Claude Code, run `/pick-task F3`. The agent reads `CLAUDE.md` and the task
   file, proposes a plan for you to approve, then works in this order:
   backend → shared (with tests) → iOS → Android. It ticks the checklist as it goes.
4. **Verify.** Run both apps yourself and go through the acceptance criteria. The agent can build, but
   you're the one who confirms it actually works on a phone.
5. **PR into `V1.1`.** Ask the agent to open it, set Status to `in review`, and get someone else to review.
   Running `/code-review` before asking for a review is a good idea.

Large features are split into slices (e.g. F4.1, F4.2). You can PR a slice on its own, as long as both apps
still build.

## Task file template

Each `F<n>-*.md` file has the same sections so an agent can follow it without extra context:
**Goal · Today (what already exists, with file paths) · Backend · Shared · iOS · Android · Acceptance
criteria · Out of scope**.

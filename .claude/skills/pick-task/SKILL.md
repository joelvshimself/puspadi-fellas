---
name: pick-task
description: Pick up a V1.1 feature issue from GitHub (milestone V1.1, label "feature") and implement it end-to-end across backend, the shared KMP module, iOS and Android. Use when someone says "/pick-task #33", "/pick-task F3", "take the profile feature", or "what can I work on?".
---

# Pick up a feature issue

Tasks live in **GitHub issues**, not in docs. The repo is `joelvshimself/puspadi-fellas`, every feature
issue has the label `feature` and the milestone `V1.1`, and the board is https://github.com/users/kennethmuyoyo/projects/2.

## 1. Find the issue
- If the argument is a number (`#33` or `33`), use `gh issue view 33 --comments`.
- If it's a feature ID (`F3`), search for it: `gh issue list -m V1.1 -l feature --search "[F3] in:title"`.
- If there's no argument, list the open feature issues with their assignees and **Depends on** lines, then
  suggest ones that are unassigned and not blocked.

## 2. Load context
- Read `/CLAUDE.md` (the architecture rule: logic goes in `Mobile/shared`, views stay native) and `backend/API.md`.
- Read the issue body and comments completely. The checklist in the issue is the scope.
- Check **Depends on**. For each referenced issue, run `gh issue view N --json state`. If one is still
  open, tell the user what's missing and offer a stub or dev-token approach. Don't silently build on top
  of something that doesn't exist yet.
- Read every file listed under **Today**. Those files are the behavior to keep. Port it, don't redesign it.

## 3. Claim and branch
- If the issue isn't assigned, offer to run `gh issue edit N --add-assignee @me`.
- The working tree should be clean and on `feat/<F-id>-<name>`, branched from an up-to-date `V1.1`. Offer to create it.

## 4. Plan, then wait for approval
Give a short plan grouped as **Backend → Shared → iOS → Android**. For each item, name the files you'll
create, change or delete, and point out anything in the issue that's ambiguous. Wait for the user to OK
the plan before writing code.

## 5. Implement in this order
1. **Backend** (`backend/`): change the endpoint and migration, update `backend/API.md`, then run `npm run check`.
2. **Shared** (`Mobile/shared/src/commonMain/kotlin/app/rollspot/shared/`): DTOs in `api/`, then the
   repository, then the feature `*Model` exposing `StateFlow<*State>` and action functions. Write
   `commonTest` tests for every rule you port from Swift. Run `./gradlew :shared:allTests` from `Mobile/`.
3. **iOS** (`Mobile/Rollspot`): make the views observe the shared model (`import Shared`), then **delete**
   the Swift business logic it replaces. Build with xcodebuild (see CLAUDE.md).
4. **Android** (`Mobile/android/app`): Compose screens observing the same model. Match the iOS screen order
   and copy. Build with `./gradlew :androidApp:assembleDebug` from `Mobile/`.

Red flags to stop and fix: a network call, validation rule or `when`/`switch` over business state inside a
view, or the same logic written in both Swift and Kotlin.

## 6. Finish
- Tick the completed checklist items in the issue. Edit the body with `gh issue edit N --body-file`, and
  keep everything that's already there.
- Report what you verified (builds, tests) separately from what the user still needs to check by hand
  (the acceptance criteria on a simulator/emulator). Don't claim acceptance criteria you didn't run.
- Offer to commit, push and open a PR into `V1.1` using `.github/pull_request_template.md` with `Closes #N`.

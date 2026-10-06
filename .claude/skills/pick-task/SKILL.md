---
name: pick-task
description: Pick up a V1.1 feature task (F0–F5) from docs/tasks and implement it end-to-end across backend, the shared KMP module, iOS and Android. Use when someone says "/pick-task F3", "take F4.1", or "work on the profile feature".
---

# Pick up a feature task

The argument is a task ID like `F3` or a slice like `F4.1`. If it's missing, show the board in
`docs/tasks/README.md` and ask which one.

## 1. Load context
- Read `/CLAUDE.md` (the architecture rule: logic in `Mobile/shared`, views native) and `docs/tasks/README.md`.
- Read the task file `docs/tasks/F<n>-*.md` completely.
- Check its **Depends on** column. If a dependency isn't `done` and isn't merged into `V1.1`, tell the user
  what's missing and offer a stub or dev-token approach. Don't silently build on top of something that doesn't exist yet.
- Read every file listed under **Today**. Those files are the behavior to keep. Port it, don't redesign it.

## 2. Set up
- Make sure the working tree is clean and the user is on `feat/F<n>-<name>`, branched from an up-to-date `V1.1`.
  If they're not, offer to create the branch.
- If the board row still says `unassigned`, ask the user for their name and update the Owner and Status columns.

## 3. Plan, then wait for approval
Give a short plan grouped as **Backend → Shared → iOS → Android**. For each item, name the files you'll
create, change or delete, and point out anything in the task file that's ambiguous. Wait for the user to
OK the plan before writing code.

## 4. Implement in this order
1. **Backend** (`backend/`): change the endpoint and migration, update `backend/API.md`, then run `npm run check`.
2. **Shared** (`Mobile/shared/src/commonMain`): DTOs, repository, then the feature `*Model` exposing
   `StateFlow<*State>` and action functions. Write `commonTest` tests for every rule you port from Swift.
   Run `./gradlew :shared:allTests`.
3. **iOS** (`Mobile/Rollspot`): make the views observe the shared model, then **delete** the Swift business
   logic it replaces. Build with xcodebuild (see CLAUDE.md).
4. **Android** (`Mobile/android`): Compose screens observing the same model. Match the iOS screen order and
   copy, and use the Figma frames referenced in `docs/specs.md`. Build with `./gradlew :androidApp:assembleDebug`.

Red flags to stop and fix: a network call, validation rule or `when`/`switch` over business state inside a
view, or the same logic written in both Swift and Kotlin.

## 5. Finish
- Tick the completed checklist items in the task file.
- Report what you verified (builds, tests) separately from what the user still needs to check by hand
  (the acceptance criteria on a simulator/emulator). Don't claim acceptance criteria you didn't run.
- Offer to commit, push, open a PR into `V1.1`, and set the board Status to `in review`.

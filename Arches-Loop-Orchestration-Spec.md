# Arches Loop Orchestration Engine — Design Specification

*Drafted from planning conversation, 2026-07-28. This document is the founding spec to hand to Claude Code, alongside the Arches master repo, to build the orchestration system. It is written to be concrete enough to start implementation from — every structural piece has a real directory layout, file template, or command signature. Items still genuinely undecided are called out explicitly in §12 rather than left ambiguous elsewhere.*

---

## 1. Purpose & Vision

Arches is a fleet of 9 leaf repositories plus 1 master orchestrator repo, built for NVIDIA Jetson (Tegra, L4T/JetPack) hardware paired with an STM32 real-time co-processor. Because the repos are tightly interdependent — a change in one (e.g. HAL's proto contracts) frequently ripples into several others (Client, Server, PySDK) — manual cross-repo coordination doesn't scale.

This project builds a **Loop Orchestration Engine**: the human writes a small, structured markdown file (a "loop") describing a desired change. An LLM-driven pipeline reads it with full cross-repo context, plans the work repo-by-repo, implements it, verifies it against explicit success criteria, records what it learned, and hands the result back for human review — without the human manually tracking state across nine-plus repositories by hand.

---

## 2. Master Repo Directory Layout (Target State)

This is the concrete filesystem layout this spec assumes exists after the engine is built. Everything under `loop/`, `.claude/`, and `app/` is new; everything else already exists per the repo overview.

```
Arches/                                  # master orchestrator repo
├── Makefile                             # existing fan-out git targets + new orchestration targets
├── README.md
├── SOUL.md
├── CLAUDE.md                            # navigation map — gets a new "Loop Engine" section
├── .env                                 # GitHub org + token, Kanban board API creds (gitignored)
│
├── loop/
│   ├── backlog/
│   ├── to-do/
│   ├── in-progress/
│   ├── in-review/
│   ├── complete/
│   ├── failed/
│   └── execution/
│       └── <task-slug>/
│           ├── try-1/
│           │   ├── plan.md
│           │   ├── implementation-notes.md
│           │   └── audit.md
│           ├── try-2/
│           │   └── ...
│           └── final-summary.md
│
├── .claude/
│   ├── agents/
│   │   ├── orchestrator.md              # main agent system prompt / config
│   │   ├── executor.md                  # implementation sub-agent
│   │   └── qa.md                        # verification sub-agent
│   ├── hooks/
│   │   ├── on-loop-start.sh             # fires when a loop moves to in-progress
│   │   ├── on-loop-review.sh            # fires when a loop moves to in-review
│   │   ├── on-loop-complete.sh          # fires when a loop moves to complete
│   │   └── on-loop-failed.sh            # fires when a loop moves to failed
│   └── commands/
│       └── run-loop.md                  # the "run the loop" slash-command definition
│
├── tools/
│   └── kanban_sync/
│       ├── kanban_sync.py               # the two-way sync tool (see §6)
│       ├── requirements.txt
│       └── config.yaml
│
├── app/                                 # dynamically created applications live here (see §8)
│   └── <new-app-name>/
│       ├── Makefile
│       └── ...
│
├── Arches-Client/                       # existing leaf repos, checked out as siblings
├── Arches-Configuration/
├── Arches-Dashboard/
├── Arches-HAL/
├── Arches-HQ/
├── Arches-Hardware/
├── Arches-OS/
├── Arches-PySDK/
└── Arches-Server/
```

---

## 3. Repository Categorization

The master repo serves **two distinct products**, and every loop must be tagged against this split.

### 3.1 Base System
The standalone, shippable Jetson + STM32 product:
- **Arches-OS** — Yocto/kas board-support build producing the device image
- **Arches-Configuration** — on-device WebConfig UI/daemon (network, updates, backup/restore, vitals)
- **Arches-HQ** — planned cloud fleet-management SaaS (pairs with Configuration)

A `base-system` loop is **scoped only to these three repos**.

### 3.2 IV&V (Integration Verification & Validation)
A layer on top of the base system, purely for testing/validating hardware:
- **Arches-HAL** — hardware abstraction + 35 test modules; owns the canonical proto/gRPC contracts
- **Arches-Client** — gRPC IV&V client running on the Jetson
- **Arches-Server** — gRPC IV&V server running on x86
- **Arches-Dashboard** — standalone dashboard UI (currently unstarted)

**Dependency rule: IV&V inherits from and relies on the Base System, never the reverse.** An `ivv` loop may legitimately touch OS, Configuration, or HQ (e.g. a driver hook, a config setting, wiring a new test end-to-end). A `base-system` loop must never touch HAL/Client/Server/Dashboard — the Orchestrator should treat that as a scope violation and reject/flag the loop rather than execute it (see §9.4, scope-check step).

Outside both categories: **Arches-Hardware** (human-maintained reference, never touched programmatically) and **Arches** itself (the orchestrator, holds no app code, but does gain the `loop/`, `.claude/`, `tools/`, `app/` scaffolding described here).

---

## 4. The Loop Folder Pipeline

### 4.1 Folder-as-state model
A loop's state is *literally* which folder its file sits in — no status field needs to be parsed by tooling to know where something stands. `status:` in the header (see §5.2) is kept in sync as a human-readable mirror, but the folder is the source of truth.

| Folder | Moved here by | Condition |
|---|---|---|
| `backlog/` | Human, manually | Idea captured, not yet groomed; can be freely edited |
| `to-do/` | Human, manually | Human has groomed it and marks it ready to execute |
| `in-progress/` | Engine | `run-loop` trigger fires; engine claims one file from `to-do/` |
| `in-review/` | Engine | Plan→Execute→QA cycle reports all success criteria met |
| `complete/` | Human, manually | Human reviews `in-review/` output and approves |
| `failed/` | Engine | Max revision attempts exhausted without passing QA (see §4.3) |

### 4.2 Trigger model
- **Manual only** — no filesystem watcher, no polling daemon.
- Human runs the slash command `/run-loop` (Claude Code custom command, `.claude/commands/run-loop.md`) or the Makefile target `make loop-run` — these should be equivalent entry points, one for interactive Claude Code sessions, one for scripting/CI.
- On trigger, engine behavior:
  1. List files in `to-do/`, sorted by a `priority:` header field (default: file modification time, oldest first).
  2. Claim the first one — move it to `in-progress/` and fire `on-loop-start.sh`.
  3. Process that single loop to completion (in-review or failed) before optionally claiming another, if `run-loop --all` was passed; default behavior processes **one loop per invocation**.

Suggested command surface:
```bash
make loop-run                 # process exactly one loop from to-do/
make loop-run ARGS="--all"    # drain to-do/ entirely, one loop at a time, sequentially
make loop-status               # print current counts per folder + task titles
```

### 4.3 Revision limit & failure
- The Orchestrator↔QA revision cycle (§9) is capped at a configurable **max attempt count** (default: 4 tries — matches the `try-N` folder convention).
- If QA still reports failing criteria after the max attempts, the Orchestrator:
  1. Writes `final-summary.md` in the task's execution folder, consolidating what was attempted across all tries and the specific blocking failure.
  2. Moves the loop file from `in-progress/` to `failed/`.
  3. Fires `on-loop-failed.sh` (updates Kanban, appends a `FAILED` entry to every touched repo's changelog per §10.1).
- Failed loops are **never auto-retried**. A human reviews `failed/`, and either edits the loop and manually moves it back to `to-do/`, or abandons it.

---

## 5. Loop File Format

### 5.1 Filename convention
`loop/<stage>/<yyyymmdd>-<slug>.md`, e.g. `loop/to-do/20260728-usb3-test-support.md`. The date prefix is when the loop was created (not when it executes), so ordering in `backlog/`/`to-do/` is chronological at a glance.

### 5.2 Header (YAML front matter — required fields)

```yaml
---
title: Add USB 3.0 test scenario support
task_id: null                 # assigned by kanban_sync.py on first sync — see §6.3
category: ivv                 # base-system | ivv
type: feature-improvement     # feature-improvement | new-application
status: to-do                 # mirrors folder; engine updates this on every move
priority: 2                   # lower = higher priority; used to order to-do/ claims
created: 2026-07-28
repos:                        # explicit allow-list the Orchestrator scopes execution to
  - Arches-OS
  - Arches-HAL
  - Arches-Client
  - Arches-Server
  - Arches-Dashboard
---
```

`repos:` is the hard scope boundary — the Orchestrator refuses to touch anything not listed here, and the scope-check step (§9.4) verifies this list is consistent with `category` (e.g. a `base-system` loop listing `Arches-HAL` should be rejected at claim time, before any work starts).

### 5.3 Body — Feature Improvement loops

Full worked example, `20260728-usb3-test-support.md`:

```markdown
## Goal
Add end-to-end validation support for USB 3.0 devices across the IV&V stack, so
manufacturing can confirm USB 3.0 controllers on new boards pass at spec speed
before a unit ships.

## Affected Repositories

### Arches-OS
**Changes required:**
- `meta-arches`: enable the USB 3.0 controller in the device tree overlay for
  the target board.
- Enable the relevant xHCI driver in the kernel config fragment.
- Confirm no conflicting USB 2.0-only config left enabled.

**Success criteria:**
- Image boots with the USB 3.0 controller present and enumerated.

**Test & validation:**
- Flash image to reference hardware; `lsusb -t` shows the controller running
  at SuperSpeed (5 Gbps) with a known-good USB 3.0 test device attached.
- No new dmesg errors/warnings referencing the controller at boot.

### Arches-HAL
**Changes required:**
- New test module `usb3_test` under the existing 35-module set, following the
  uniform CLI convention (`one-shot`, `monitoring`, `long-term`, `monitor-test`,
  `event`).
- Extend `hal_service.proto` with a `Usb3TestResult` message and RPC.

**Success criteria:**
- `usb3_test` builds cleanly under the existing `-Wall -Wextra -Wpedantic -Werror`
  flags; CTest suite includes and passes a unit test for the module's CLI
  surface (mocked device layer).

**Test & validation:**
- `ctest -R usb3_test` passes.
- Manual `one-shot` run against reference hardware returns a populated
  `Usb3TestResult` with measured link speed.

### Arches-Client
**Changes required:**
- Wire the new HAL `usb3_test` module into the client's existing test-module
  dispatch table so it streams results over `client_service.proto`.

**Success criteria:**
- Client lists `usb3_test` in its available-module inventory and can trigger
  and stream a run end-to-end to a listening server.

**Test & validation:**
- CTest coverage for the new dispatch entry.
- Manual run: `arches-client run usb3_test --once` against a local
  Arches-Server instance completes and result appears server-side.

### Arches-Server
**Changes required:**
- Add `usb3_test` result ingestion to the existing SQLite schema/handlers.

**Success criteria:**
- Server persists `Usb3TestResult` rows correctly and exposes them through
  existing result-query paths.

**Test & validation:**
- CTest coverage for the new ingestion path.
- Query the SQLite DB directly after a manual run and confirm the row shape.

### Arches-Dashboard
**Changes required:**
- N/A for this pass — Dashboard is currently an unstarted stub. Loop should
  note this rather than silently skip it: confirm with the Orchestrator's
  scope-check whether Dashboard should be dropped from `repos:` for this
  loop or deferred to a follow-up loop once Dashboard exists.

## Lessons Learned
*(Filled in during/after execution by the Orchestrator — see §10. Also written
back to each affected repo's CLAUDE.md.)*
```

### 5.4 Body — New Application Creation loops

```markdown
## Goal
Create a new lightweight `usb-stress-app` under `app/` — a standalone client+
server pair used to stress-test USB 3.0 throughput continuously, independent
of the main IV&V Client/Server pair.

## New Application Definition
- **Name:** usb-stress-app
- **Purpose:** Continuous USB 3.0 throughput stress testing, separate from
  the pass/fail-oriented IV&V USB 3.0 module.
- **Shape:** client (runs on Jetson) + server (runs on x86), plain TCP, no
  gRPC/proto dependency on Arches-HAL.

## Repository Integration

### app/usb-stress-app (new)
- Scaffold with its own `Makefile` following the same target conventions as
  the 9 existing leaves (build/test/clean/package at minimum).
- Language/stack: <to be decided by Executor unless specified here>.

### Arches-OS
**Changes required:**
- Add a new Yocto recipe under `meta-arches` to fetch and build
  `usb-stress-app` from its new GitHub repo, so it's included in the image.

**Success criteria:**
- `bitbake arches-image` succeeds with the new recipe included; the built
  binary is present in the image's rootfs.

## GitHub Repository Creation
- Org and token come from `.env` (`GITHUB_ORG`, `GITHUB_TOKEN`) — never
  inlined in the loop file.
- New repo name: `Arches-usb-stress-app` (convention: `Arches-<app-name>`,
  matching existing leaf naming).
- Initial push: scaffolded Makefile + stub source + README.

## Lessons Learned
*(filled in post-execution)*
```

---

## 6. Kanban Synchronization Tool

`tools/kanban_sync/kanban_sync.py` — Python CLI + importable module, callable both by a human and by Claude Code sub-agents during execution.

### 6.1 CLI surface

```bash
# Full two-way sync: scan loop/ folders, push all states to the board,
# and pull back any manual board-side moves (if the board supports it).
python kanban_sync.py sync

# Direct, single-task state transition — used by agents mid-execution
# so the board updates immediately rather than waiting for a full scan.
python kanban_sync.py transition --task-id <id> --to in-review

# Register a brand-new loop file that doesn't have a task_id yet.
python kanban_sync.py register --file loop/to-do/20260728-usb3-test-support.md
```

### 6.2 Direction 1 — Filesystem → Kanban (`sync`)
1. Walk `loop/{backlog,to-do,in-progress,in-review,complete,failed}/`.
2. For each loop file: read YAML header, determine state from parent folder name.
3. Upsert to the Kanban board: title, state, category, type, priority (metadata set below in §6.4).
4. Board always reflects filesystem truth after a `sync` call; `sync` is also run automatically as the last step of every hook in `.claude/hooks/`.

### 6.3 Direction 2 — Agent → Kanban (`transition`)
- Used inline during Orchestrator/Executor/QA execution, e.g. immediately after QA passes, before the file is physically moved, so the board reflects intent without waiting on the next full scan.
- Requires a `task_id`. **Task ID assignment:** on first `sync` or explicit `register` call for a loop file that has `task_id: null`, the tool generates one (suggested: short content-hash or incrementing integer backed by a local `tools/kanban_sync/.task_id_counter` file) and writes it back into the loop file's YAML header. From then on the ID is stable for that file's lifetime, including as it moves between folders.

### 6.4 Metadata synced (initial set — extend as needed)
| Field | Source |
|---|---|
| `task_id` | assigned per §6.3 |
| `title` | loop header |
| `state` | parent folder |
| `category` | loop header (`base-system` / `ivv`) |
| `type` | loop header (`feature-improvement` / `new-application`) |
| `repos` | loop header `repos:` list |
| `priority` | loop header |
| `current_try` | count of `try-N/` folders present in the matching `loop/execution/<task-slug>/` |

### 6.5 Config
`tools/kanban_sync/config.yaml` holds board connection details (API base URL, board/list IDs). Credentials themselves (API key/token) live in `.env` at the master repo root, referenced by env var name from `config.yaml`, never committed in plaintext.

---

## 7. Git & Branching Strategy

Builds on the master repo's existing Makefile fan-out targets (init/pull/push/rebase/commit/status/branch/checkout/clean/release across all leaves).

### 7.1 New Makefile targets (additions to the existing fan-out set)

```bash
make branch-create NAME=feature/usb3-test-support   # fans out branch creation
                                                       # to every repo listed in
                                                       # the loop's `repos:` field
make branch-push NAME=feature/usb3-test-support       # pushes that branch in every
                                                       # touched repo to origin
make branch-merge NAME=feature/usb3-test-support \
     TAG=v-usb3-test-support-1                         # merge back + tag, per repo
```

### 7.2 Sequence for a single loop
1. **Claim time:** Orchestrator runs `make branch-create NAME=feature/<slug>` — creates a matching feature branch **only in the repos listed under `repos:`** in the loop header (not a blind fan-out to all 9 — that would create noise branches in untouched repos).
2. **During execution:** Executor commits changes on that branch, per repo, as work in each repo completes. Commit message convention: `[<task_id>] <short description>` so every commit is traceable back to its loop.
3. **On QA pass / loop closes to `in-review`:** Orchestrator runs `make branch-push NAME=feature/<slug>` to push all touched branches upstream together.
4. **On human approval (loop moved to `complete/` by the human):** run `make branch-merge NAME=feature/<slug> TAG=<tag>` — merges each touched repo's branch back to `develop`, tags the merge commit, per repo. Tag naming convention: `<task_id>-<slug>`.

This treats the touched subset of the fleet as **one atomic unit** for the loop, without polluting repos the loop never touched.

---

## 8. New Application Creation Workflow

1. Loop of `type: new-application` lands in `to-do/`, gets claimed as normal.
2. Orchestrator's plan includes an explicit **scaffold step**: create `app/<name>/` with at minimum a `Makefile` matching the conventions of the 9 existing leaves (build/test/clean/package targets), plus whatever stack the loop specifies (or the Executor proposes, if unspecified — flagged in `plan.md` for QA/human visibility either way).
3. Executor implements the app's initial scaffold + whatever minimal functionality the loop describes.
4. Executor implements the loop's **Repository Integration** section against existing repos (e.g. a new Yocto recipe in Arches-OS).
5. **GitHub repo creation**, using `.env`'s `GITHUB_ORG` / `GITHUB_TOKEN`:
   - Create `<GITHUB_ORG>/Arches-<name>` via the GitHub API (or `gh repo create` CLI if available in the execution environment).
   - Push the scaffold as the initial commit on `main`/`develop` per the org's existing convention.
6. From this point the new app is a full peer of the original 9 leaves — future loops can list it under `repos:` like any other.

---

## 9. Orchestration Engine — Agents

### 9.1 Directory & config
- `.claude/agents/orchestrator.md`, `executor.md`, `qa.md` — each a system-prompt/config file defining that agent's role, tools, and (once decided — see §12) model.
- `.claude/hooks/` — shell scripts fired at state transitions, each ending with a `kanban_sync.py sync` call:
  - `on-loop-start.sh` — fires when Orchestrator claims a loop into `in-progress/`. Runs `make branch-create`.
  - `on-loop-review.sh` — fires when loop moves to `in-review/`. Runs `make branch-push`.
  - `on-loop-complete.sh` — fires when human moves loop to `complete/`. Runs `make branch-merge`.
  - `on-loop-failed.sh` — fires when loop moves to `failed/`. Appends `FAILED` entries to changelogs (§10.1).

### 9.2 Main Orchestrator Agent — responsibilities
1. **Claim & scope-check:** read the claimed loop file. Verify `repos:` is consistent with `category` (a `base-system` loop must not list HAL/Client/Server/Dashboard). If inconsistent, halt and route to `failed/` immediately with a scope-violation note — do not attempt execution.
2. **Context assembly:** for every repo in `repos:`, read that repo's `CLAUDE.md` (do's/don'ts + recent changelog entries) so the plan benefits from prior institutional knowledge.
3. **Planning:** write `loop/execution/<slug>/try-N/plan.md` (template §9.5) — one section per repo in `repos:`, each with concrete steps, success criteria (copied/refined from the loop), and how QA should verify.
4. **Dispatch:** hand `plan.md` to the Executor agent.
5. **Review QA output:** read `audit.md`. If all criteria pass, close the loop (move file to `in-review/`, fire `on-loop-review.sh`). If not, either:
   - revise `plan.md` (same try, if the fix is small), or
   - start a new `try-(N+1)/` with an updated plan addressing the audit's specific findings.
6. **Cap enforcement:** after the configured max tries (default 4) without a passing audit, write `final-summary.md`, move the loop to `failed/`, fire `on-loop-failed.sh`.
7. **Record-keeping:** on close (pass or fail), write the Lessons Learned section back into the loop file itself, and trigger the changelog/CLAUDE.md updates (§10) for every touched repo.

### 9.3 Executor Agent — responsibilities
- Input: `plan.md` for the current try.
- Implements each repo's section of the plan, one repo at a time, in that repo's working tree (already on the correct feature branch per §7).
- Commits per repo as sections complete, using the `[<task_id>] <description>` convention.
- Writes `implementation-notes.md` alongside `plan.md` in the same `try-N/` folder — what was actually done, any deviations from the plan and why, any commands run.
- Does **not** self-assess success criteria — that's QA's job, to keep verification independent of the agent that did the work.

### 9.4 QA Agent — responsibilities
- Input: original loop file (for the authoritative success criteria) + `plan.md` + `implementation-notes.md`.
- Runs each repo's **Test & validation** steps from the loop/plan (build, CTest, manual CLI checks as specified).
- Writes `audit.md` (template §9.6): per-repo pass/fail against each stated success criterion, with evidence (command output, specific failures).
- Does not fix anything itself — only reports. Keeps verification honest by never letting the agent that finds a problem also be the one that "fixes" it silently.

### 9.5 `plan.md` template

```markdown
# Plan — <loop title> (try N)

## Scope check
- category: ivv | base-system
- repos in scope: <list, matches loop header>

## Arches-OS
### Steps
1. ...
2. ...
### Success criteria (from loop)
- ...
### How QA will verify
- ...

## Arches-HAL
...
```

### 9.6 `audit.md` template

```markdown
# Audit — <loop title> (try N)

## Arches-OS
- [PASS/FAIL] <criterion 1> — evidence: ...
- [PASS/FAIL] <criterion 2> — evidence: ...

## Arches-HAL
- [PASS/FAIL] ...

## Overall
- Result: PASS | FAIL
- If FAIL: specific blocking issue(s) for the next plan revision to address.
```

### 9.7 Closed-loop cycle

```
to-do/<file>.md
   │  (run-loop trigger)
   ▼
Orchestrator claims → in-progress/, on-loop-start.sh (branch-create, kanban sync)
   │
   ▼
Scope-check  ──fail──▶  failed/  (immediate, no execution attempted)
   │ pass
   ▼
Context assembly (read CLAUDE.md per repo)
   │
   ▼
try-1/plan.md  ─────────────────────────────┐
   │                                        │
   ▼                                        │
Executor → implementation-notes.md          │ revise → try-(N+1)/
   │                                        │
   ▼                                        │
QA → audit.md ───── FAIL ────────────────────┘  (until max tries)
   │ PASS                                        │
   ▼                                              ▼ max tries exceeded
in-review/, on-loop-review.sh (branch-push)   final-summary.md → failed/,
   │                                          on-loop-failed.sh
   ▼ (human reviews)
complete/, on-loop-complete.sh (branch-merge + tag)
```

---

## 10. Repo-Level Record Keeping

### 10.1 Changelog
Each leaf repo (and `app/*` repos) maintains `CHANGELOG.md` at its root. On loop close (pass **or** fail), the Orchestrator appends one entry per touched repo:

```markdown
## 2026-07-28 — [task_id: 0042] Add USB 3.0 test scenario support
- Status: SUCCESS (try 2 of 4)
- Changes: added usb3_test module (one-shot/monitoring/long-term/monitor-test/
  event CLI), extended hal_service.proto with Usb3TestResult.
- Try 1 failure (for reference): initial proto field numbering collided with
  a reserved range; resolved by shifting to the next available field block.
```

Failed loops get the same treatment with `Status: FAILED` and the blocking issue from `final-summary.md`.

### 10.2 CLAUDE.md — Lessons Learned
Each touched repo's `CLAUDE.md` gets a **Do's and Don'ts** section (not a raw log — curated and refined, so it stays useful rather than growing indefinitely):

```markdown
## Do's and Don'ts (maintained by the Loop Engine)

### Proto changes
- DON'T add new fields to `hal_service.proto` without checking the reserved
  field-number ranges documented in the proto file's header comment — this
  caused a failed first attempt on task 0042.
- DO run `protoc --lint` (or the repo's existing lint target) before handing
  a proto change to QA; it would have caught the above immediately.
```

The Orchestrator is responsible for **merging** new lessons into this section (not just appending) — deduplicating against existing entries, refining wording, and removing anything superseded — as part of closing a loop, whether it passed or failed.

---

## 11. `.env` — Required Variables

```bash
# tools/kanban_sync + GitHub repo creation for new-application loops
GITHUB_ORG=<org-name>
GITHUB_TOKEN=<personal access token, repo-creation scope>

# Kanban board API (referenced by tools/kanban_sync/config.yaml)
KANBAN_API_BASE=<board's API base URL>
KANBAN_API_KEY=<token>
```
`.env` must be gitignored at the master repo root. No credential is ever written into a loop file, `plan.md`, `audit.md`, or any changelog.

---

## 12. Explicitly Deferred / To Be Designed Later

These remain open — do not treat anything below as decided:

1. **Kanban task ID generation mechanism** — content-hash vs. incrementing counter vs. board-assigned ID pulled back on first sync (§6.3).
2. **Full long-term Kanban metadata set** — beyond the initial fields in §6.4, e.g. assignee, linked PR URLs, due dates.
3. **Model assignment per agent** — which specific model backs Orchestrator vs. Executor vs. QA. Working assumption to validate: Orchestrator on a stronger reasoning model (cross-repo consequence reasoning), Executor and QA on faster/cheaper models (more mechanical once a plan exists) — not yet confirmed.
4. **Max-try count** — defaulted to 4 in this spec for concreteness; confirm or change.
5. **Dashboard's current stub status** — several example loops above will hit "Dashboard doesn't exist yet" (see §5.3 worked example); decide whether such loops should auto-drop Dashboard from scope or block until a separate loop stands Dashboard up.
6. **New-application stack defaults** — when a `new-application` loop doesn't specify a language/stack, whether the Executor should have a default (e.g. "C++ to match the rest of the fleet unless stated otherwise") or must always ask.

---

*This document reflects the complete state of the design conversation as of 2026-07-28, expanded with concrete directory layouts, file templates, and command signatures to be directly actionable by Claude Code. It is meant to be handed to Claude Code alongside the Arches master repo to begin implementation.*

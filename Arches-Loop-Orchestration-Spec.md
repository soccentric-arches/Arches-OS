# Arches — Multi-Generation Jetson Yocto Branching
## Requirements & Implementation Prompt

**Audience:** LLM coding agent with read/write access to the Arches Yocto build repository.
**Deliverable:** Four mutually incompatible, self-contained build branches — `tx`, `xavier`, `orin`, `thor` — each producing a clean, flashable image for every SoM and developer kit in its generation.

---

## 1. Purpose

NVIDIA Jetson generations are not cross-compatible at the BSP level. Each generation is locked to a distinct L4T/JetPack release, which in turn is locked to a distinct `meta-tegra` branch, which in turn is locked to a distinct Yocto/OE-Core release. A single build tree cannot serve TX, Xavier, Orin and Thor.

This document specifies branching the existing Arches Yocto build system into four generation-scoped branches. Checking out a branch must yield a clean, complete, buildable environment for exactly one generation, with no residue from any other.

## 2. Scope

**In scope**
- Four build branches in the Arches build repo.
- Four matching branches in `meta-arches` (the project configuration/application layer), version-locked to their sibling.
- Per-branch Docker build environment.
- Per-branch pinning of all upstream layers.
- Per-branch build and flash documentation.
- Full SoM and developer kit coverage within each generation.

**Out of scope**
- CI/CD pipelines, runners, artifact registries, and any automation beyond a locally invocable build. Explicitly excluded — do not create, modify, or reference pipeline definitions.
- OTA/update infrastructure, unless already present in the repo, in which case it is carried forward per-branch unchanged.
- Any new application functionality. This is a porting and restructuring exercise.

---

## 3. Step 0 — Mandatory Repository Review (do this first)

Before writing anything, perform a deep review of the existing repository and produce a written findings report. Do not begin implementation until this is complete.

Determine and report:

1. **Current structure** — top-level layout, build entry points, wrapper scripts, existing Docker assets.
2. **Layer inventory** — every layer consumed, its source, current revision, and how it is pinned today (submodule / manifest / kas / `bblayers.conf` path / vendored copy).
3. **Current generation target** — which L4T/JetPack and `meta-tegra` branch the tree is built against today, and which machines are known-good.
4. **`meta-arches` contents** — full inventory: machine configs, distro config, image recipes, bbappends, kernel/device-tree assets, config fragments, package groups, application recipes.
5. **Existing customizations that live outside `meta-arches`** — any patch, edit, or override applied to an upstream layer in place. Enumerate every one; each is technical debt that must be relocated (see §9.1).
6. **Machine coverage gaps** — which SoMs/dev kits in the current generation are configured today versus the full family list in §5.
7. **Build invocation** — exact current commands to configure, build, and flash.
8. **Anything ambiguous or unverifiable** — list it, do not guess.

The report is a required deliverable. Everything after it must be justified against it.

---

## 4. Branch Model

Four branches. Each is a complete, standalone build environment.

| Branch | Generation | Purpose |
|---|---|---|
| `tx` | Tegra X1 / X2 | TX1, TX2 family, Nano family |
| `xavier` | Volta Xavier | AGX Xavier, Xavier NX |
| `orin` | Ampere Orin | AGX Orin, Orin NX, Orin Nano |
| `thor` | Blackwell Thor | AGX Thor |

**Rules**

- Branches are **deliberately incompatible**. No shared history is maintained after the split beyond the common ancestor.
- No branch may reference, include, conditionally import, or fall back to another branch's layers, revisions, or machine configs. No `if generation ==` switching anywhere.
- A fresh clone + checkout of one branch, with no additional arguments, must build a default image for that generation's flagship dev kit.
- No branch may contain machine configs, recipes, or documentation for a generation it does not serve. Delete, do not comment out.
- `master`/`main` holds this document, the top-level README, and the branch index only. It is not buildable.

---

## 5. Generation Matrix

The agent must reproduce this table in the repo README, corrected and completed against the actual pinned `meta-tegra` branch. Values below are the target; **verify every machine name, module part number, and revision against upstream before committing — flag any that cannot be verified rather than inventing them.**

### 5.1 Branch → upstream pins

| Branch | Yocto/OE release | `meta-tegra` branch | L4T | JetPack |
|---|---|---|---|---|
| `tx` | kirkstone | `kirkstone-l4t-r32.7.x` | R32.7.x | 4.6.x |
| `xavier` | kirkstone | `kirkstone` (L4T R35.x line) | R35.6.x | 5.1.x |
| `orin` | scarthgap | `scarthgap` (L4T R36.4.x line) | R36.4.x | 6.2.x |
| `thor` | current OE-Core release matching upstream `LAYERSERIES_COMPAT` | `master`-line Thor branch (R38.x / R39.x) | R38.2.x or later | 7.x |

Notes the agent must confirm and record in each branch README:
- The `tx` line (L4T R32.7.x) is the terminal release for TX1/TX2/Nano. No further upstream releases exist.
- The `xavier` line (L4T R35.x) is the terminal release for Xavier. JetPack 6 dropped Xavier support.
- L4T R38.x supports **Thor only**; Orin machine configs present in that tree are non-functional and must not be used. If the selected Thor pin is an R39.x branch that carries both Orin and Thor machines, Orin machines are still out of scope for the `thor` branch and must be removed from `bblayers`/machine selection and documentation.

### 5.2 Family coverage

Each branch must configure, build, and document **every** SoM and dev kit in its family.

**`tx`**

| SoM | Module P/N | Dev kit / carrier |
|---|---|---|
| Jetson TX1 | P2180 | P2371-2180 dev kit |
| Jetson TX2 | P3310 | P2771-0000 dev kit |
| Jetson TX2i | P3489-0000 | P2771 carrier |
| Jetson TX2 4GB | P3489-0888 | P2771 carrier |
| Jetson TX2 NX | P3636 | P3509 / Nano dev kit carrier |
| Jetson Nano (SD) | P3448-0000 | P3450 dev kit |
| Jetson Nano (eMMC) | P3448-0002 | P3449 carrier |
| Jetson Nano 2GB | P3448-0003 | P3541 dev kit |

**`xavier`**

| SoM | Module P/N | Dev kit / carrier |
|---|---|---|
| AGX Xavier 8/16/32/64GB | P2888 variants | P2972-0000 dev kit |
| AGX Xavier Industrial | P2888-0008 | P2972 carrier |
| Xavier NX (SD) | P3668-0000 | P3509 dev kit |
| Xavier NX (eMMC) | P3668-0001 | P3509 / P3449 carrier |

**`orin`**

| SoM | Module P/N | Dev kit / carrier |
|---|---|---|
| AGX Orin 32GB | P3701-0004 | P3737 carrier / AGX Orin dev kit |
| AGX Orin 64GB | P3701-0005 | P3737 carrier |
| AGX Orin Industrial 64GB | P3701-0008 | P3737 carrier |
| Orin NX 16GB | P3767-0000 | P3768 Orin Nano carrier; P3509 Xavier NX carrier |
| Orin NX 8GB | P3767-0001 | P3768 / P3509 carrier |
| Orin Nano 8GB (incl. Super) | P3767-0003 / -0005 | P3768 dev kit carrier |
| Orin Nano 4GB | P3767-0004 | P3768 carrier |

**`thor`**

| SoM | Module P/N | Dev kit / carrier |
|---|---|---|
| AGX Thor T5000 | verify against pinned branch | P4071 carrier / AGX Thor dev kit |
| AGX Thor T4000 | verify against pinned branch | P4071 carrier |

For each row, the branch must supply: a resolved `MACHINE` value, a build recipe, and a documented flash procedure. Where a module is only reachable through a carrier variant of another machine config, state that explicitly rather than inventing a machine name.

---

## 6. `meta-arches` Layer

`meta-arches` is the single home for all project configuration and application content. It follows the identical four-branch model and is version-locked to its sibling build branch. `meta-arches@orin` is compatible only with the `orin` build branch, and so on.

### 6.1 Required contents, per branch

- **Machine configs** — project machine definitions and carrier variants for every SoM in §5.2, layered over upstream `meta-tegra` machines via includes, never by editing them.
- **Distro config** — the Arches distro, with per-generation feature sets, `PREFERRED_VERSION`/`PREFERRED_PROVIDER` settings, and toolchain constraints appropriate to that L4T's CUDA version.
- **Image recipes** — the Arches image set for that generation.
- **bbappends** — all modifications to upstream `meta-tegra`, `poky`, and third-party recipes.
- **Kernel assets** — defconfig fragments, kernel patches, device tree sources and overlays, per machine.
- **Config fragments** — bootloader/UEFI/extlinux configuration, partition layouts, flash layout overrides.
- **Application and package recipes** — the Arches app stack.
- **Package groups** — per-image and per-machine composition.
- **Build environment** — the branch's `Dockerfile` and container entry scripts.
- **Templates** — `local.conf.sample` and `bblayers.conf.sample` for that generation, resolving to a working default build with no manual editing.
- **Pinned manifest** — the revision lock for every upstream layer (see §8).

### 6.2 Version locking

Each build branch must pin `meta-arches` to the matching branch and to an explicit commit or tag. A build branch that resolves `meta-arches` to a floating branch tip, or to a branch of a different generation, is a failure.

---

## 7. Build Environment

The build is containerized. There is **no host OS requirement, and no host OS may be named anywhere in the repo, scripts, or documentation.** The host provides Docker and nothing else.

Each branch ships its own `Dockerfile` pinning the base image and toolchain that its L4T generation requires:

| Branch | Container base | Rationale |
|---|---|---|
| `tx` | pinned to the base image required by L4T R32.7.x tooling | older CUDA/GCC constraints |
| `xavier` | pinned to the base image required by L4T R35.x tooling | |
| `orin` | pinned to the base image required by L4T R36.4.x tooling | |
| `thor` | pinned to the base image required by the selected R38/R39 tooling | |

Requirements:
- Base image pinned by digest or explicit tag. No `:latest`.
- All host-side packages installed at pinned versions where the L4T tooling is version-sensitive (notably the CUDA host toolchain and GCC).
- Container entry script mounts the source tree, a persistent `sstate-cache`, and a persistent `downloads` dir.
- Building must not require any manual step inside the container beyond invoking the documented command.
- The same `docker build` + `docker run` command shape works across all four branches; only the branch content differs.

---

## 8. Upstream Pinning

- Every upstream layer is pinned to an explicit, immutable revision — commit SHA or signed tag. No branch tips.
- The pinning mechanism must be uniform across all four branches. Carry forward whatever the repo already uses (identified in Step 0); change it only if Step 0 shows the existing mechanism cannot express per-branch locks, and if changed, state the reason.
- A single file per branch is the authoritative source of upstream revisions. It must be readable without running a build.
- Re-cloning at a given commit of a branch must reproduce byte-identical layer checkouts.

---

## 9. Hard Rules

### 9.1 No upstream edits
All customization lands in `meta-arches` via bbappends, config overrides, `.inc` includes, and machine includes. Upstream layers (`poky`, `meta-tegra`, `meta-openembedded`, and any third-party layer) remain pristine at their pinned revisions and are never edited in place, never vendored with local modifications, and never patched by script.

Any in-place upstream modification found during Step 0 must be relocated into `meta-arches` as part of this work, and each relocation listed in the findings report with before/after paths.

### 9.2 No host OS references
Covered in §7. The words describing a required host distribution must not appear in any README, script, comment, or config. Container base images are the only place an OS version is named.

### 9.3 No cross-generation references
No branch contains, imports, or documents another generation's layers, revisions, machines, or images.

### 9.4 No invention
Any machine name, part number, branch name, revision, or upstream capability the agent cannot verify against the actual repository or upstream source must be flagged in a `VERIFY.md` at the branch root, with what was assumed and what needs confirmation. Plausible-looking fabrication is a failure condition.

---

## 10. Per-Branch Deliverables

Each of the four branches must contain:

1. `README.md` — generation scope, the §5.2 family table for that generation only, upstream pins, build command, flash command per machine.
2. `Dockerfile` + container entry script.
3. Pinned upstream manifest.
4. `meta-arches` at the matching branch and pinned revision, with the §6.1 contents complete.
5. `local.conf.sample` and `bblayers.conf.sample` that work unedited.
6. Flash documentation per machine, including which flashing path applies (legacy tegraflash vs. initrd-flash vs. the unified Thor flow) — this differs by generation and must not be copied across branches.
7. `VERIFY.md` if §9.4 applies.
8. `MIGRATION.md` — what changed from the pre-split tree, and what a user of the old tree must do.

---

## 11. Acceptance Criteria

The implementation is accepted only if all of the following hold.

**Structural**
1. Four branches exist with the names in §4, plus a non-buildable `master`.
2. `meta-arches` has four matching branches, each pinned by commit from its sibling.
3. No branch contains any file referencing another generation. A grep for the other three generations' machine prefixes across each branch returns nothing outside `MIGRATION.md`.
4. No upstream layer contains a local modification. Every layer checks out clean against its pinned revision.
5. No host OS version string appears outside a `Dockerfile` base image line.

**Coverage**
6. Every SoM and dev kit in §5.2 has a resolved `MACHINE` value and an entry in its branch README. No row is silently dropped.
7. Each branch's upstream pins match the §5.1 matrix, verified against the actual upstream branch, with any correction documented.

**Buildability**
8. For each branch: clone → checkout → `docker build` → documented build command produces an image for the flagship dev kit with zero manual intervention and zero edits to tracked files.
9. Config templates require no editing to reach a successful build.
10. Builds are reproducible from the pinned manifest alone.

**Documentation**
11. Each branch README is self-contained — a reader needs no other branch to build and flash.
12. Flash procedures are generation-correct, not copy-pasted.
13. The Step 0 findings report is present, and every relocated upstream customization is traceable in it.

**Honesty**
14. `VERIFY.md` exists wherever verification was not possible, and contains no items the agent could have verified but did not.
15. No fabricated machine names, part numbers, branch names, or revisions anywhere.

---

## 12. Assumptions

- The existing Arches build system is functional for its current generation and serves as the reference implementation for structure and conventions.
- `meta-arches` is already well structured; branch it and extend it, do not restructure it.
- Docker is available on the build host; nothing else about the host is assumed or required.
- Hardware for validation may not be available for every SoM. Where a machine cannot be flash-tested, the build must still complete and the untested status must be recorded in the branch README.
- CI/CD is deliberately absent and will be addressed separately. Do not scaffold for it.

---

## 13. Execution Order

1. Step 0 review and findings report. **Stop and present before proceeding.**
2. Propose the branch cut point and the `meta-arches` split plan. **Stop and present before proceeding.**
3. Create `orin` first (closest to the current tree, per Step 0 findings — adjust if the current tree targets a different generation). Prove the full deliverable set on one branch.
4. Then `xavier`, then `tx`, then `thor`.
5. Final pass: verify all acceptance criteria in §11, item by item, with evidence.

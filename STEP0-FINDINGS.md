# Step 0 — Repository Review Findings (fix.md §3)

Review date: 2026-09-02. Reviewer: agent session on `orin` branch, commit `007173d`.
Scope: full Arches-OS tree plus the four already-existing generation branches and
the nested `meta-arches` clone. All upstream layer pins below were read from the
actual local layer checkouts and cross-checked against the upstream remotes
(`git ls-remote`); NVIDIA release mapping was verified against
developer.nvidia.com (Jetson Linux R36.5 = JetPack 6.2.2, production quality).

## 1. Current structure

- Kas-based build. `kas/common.yaml` includes `kas/repos/*.yaml` (one file per
  upstream repo) and is included by each `kas/boards/<board>.yaml`.
- Entry points: root `Makefile` (targets: `build`/`image`, `sdk-image`,
  `esdk-image`, `swu`, `flash`, `shell`, `deploy-*`, `clean*`, `lint`, `test`),
  `scripts/build-all.sh`, `scripts/kas-container` (pinned kas 4.5 wrapper).
- Docker assets: `docker/yocto/` (kas build container, `FROM
  ghcr.io/siemens/kas/kas:4.5`, **tag-pinned only, no digest**), `docker/sdk/`,
  `docker/esdk/`.
- `layers/` (poky, meta-openembedded, meta-tegra, meta-swupdate, meta-rust-bin,
  meta-virtualization) and `meta/meta-arches` are nested git clones managed by
  kas, gitignored, never tracked — per repo policy and the meta-swupdate
  incident documented in `.claude/CLAUDE.md`.
- `build/`, `cache/` (downloads, sstate), `deploy/` are gitignored working dirs.
- `.claude/` contains a validation gate (`validate.sh`, exit codes 0/1–76/77).

## 2. Layer inventory (as pinned today, on `orin`)

| Layer | Source | Branch | Pin today | Mechanism |
|---|---|---|---|---|
| poky | git.yoctoproject.org/poky | scarthgap | `d4576e3c08` (short) | kas commit |
| meta-openembedded | github openembedded | scarthgap | `ae7dfb1224` (short) | kas commit |
| meta-tegra | github OE4T | scarthgap | `d2613418` (short) | kas commit |
| meta-swupdate | github sbabic | scarthgap | `a329ea9` (short) | kas commit |
| meta-rust-bin | github rust-embedded | master | `54721fa1c7a4…` (full) | kas commit |
| meta-virtualization | git.yoctoproject.org | scarthgap | `422dcd49756a…` (full) | kas commit |
| meta-arches | github soccentric-arches | **develop** | **none — floating tip** | kas branch only |

Pinning mechanism is kas `commit:` keys — carried forward unchanged (§8 allows
this; it already expresses per-branch locks). Gaps found: four short SHAs
(must be expanded to full 40-char) and **meta-arches is unpinned**, violating
fix.md §6.2. Full SHAs resolved locally: poky
`d4576e3c081a7ee7b57d48421c4c4f491cb4defe`, meta-openembedded
`ae7dfb12245c7f9b9a353499e2688015bd4e6413`, meta-tegra
`d2613418be82dd95733824a0839c185ec0e02f2d`, meta-swupdate
`a329ea9f9ef4eeb316f2da2dba4a9c1bcb106899`.

## 3. Current generation target

- OE/Yocto **scarthgap** (poky 5.0.18 line), meta-tegra **scarthgap** at
  `d2613418…` carrying **L4T R36.5.0** (all `tegra-binaries` recipes versioned
  `36.5.0`; meta-tegra branch has no separate version suffix) = **JetPack
  6.2.2** (verified against NVIDIA's R36.5 release notes — production release
  supporting all Orin modules and both Orin dev kits).
- fix.md §5.1 assumed R36.4.x/JetPack 6.2.x for `orin`. The actual pin is the
  same JetPack 6.2.x family at R36.5.0. **Correction recorded** here and in the
  branch README/VERIFY rather than inventing an R36.4.x pin.
- Known-good machines: all ten meta-tegra scarthgap machines are configured
  (`jetson-agx-orin-devkit`, `-industrial`, `jetson-orin-nano-devkit`,
  `-nvme`, `p3737-0000-p3701-0004/-0005`, `p3509-a02-p3767-0000`,
  `p3768-0000-p3767-0000/-0001/-0003/-0004`) — 1:1 with the branch's ten kas
  board files. A previous build exists under `build/` (bitbake lock/cooker
  logs); tx-branch history proves the split toolchain builds end-to-end (TX1,
  5,777 tasks, recorded in `tx` branch `VERIFY.md`).

## 4. `meta-arches` contents (nested clone, branch `develop` == `orin`)

- `conf/layer.conf` only — no distro config, no machine confs (uses upstream
  machine names directly; distro is poky with `local_conf_header` policy).
- Image recipes: `arches-image.bb` + 21 domain variants
  (`arches-image-<vertical>.bb`) sharing `arches-image-common.inc`.
- Packagegroups: middleware, cloud, debug, sdk.
- bbappends: `edk2-firmware-tegra-rcmboot_36.5.0.bbappend`,
  `standalone-mm-optee-tegra_36.5.0.bbappend` (R36.5-version-specific),
  `l4t-launcher-extlinux.bbappend` (version-agnostic),
  `linux-jammy-nvidia-tegra_%.bbappend` + kernel fragment
  `arches-security.cfg`.
- WIC layouts: `sdimage-jetson-agx-orin.wks`,
  `sdimage-jetson-orin.wks`, `sdimage-jetson-orin-nvme.wks` (A/B OTA).
- SWUpdate: config recipe + hooks + `sw-description` + keys dir convention.
- Apps: connectivity, home-init, expand-rootfs.
- `arches.inc`: central feature switch file, required from `kas/common.yaml`.

## 5. Customizations outside `meta-arches` (§9.1 sweep)

**None found.** All six upstream layer checkouts are clean (`git status` empty
in each) at their pinned revisions; no vendored copies, no in-place edits, no
patch scripts. `scripts/kas-container` is a verbatim kas 4.5 wrapper. The only
project content outside `meta-arches` is kas config, Makefile, scripts, and
docs — configuration, not upstream modification. **Relocations required: 0.**
Known past in-place incident (orphan gitlinks for `layers/meta-swupdate`,
`layers/meta-raspberrypi`) was already fixed upstream of this work (commit
`617c54f`) and is documented in `.claude/CLAUDE.md`.

## 6. Machine coverage vs fix.md §5.2

- `orin`: 10/10 upstream machines configured; §5.2 orin rows fully covered.
  P/N mapping verified against the L4T R36.5 release notes (P3701-0004/-0005
  on P3737; P3701-0008 industrial; P3767-0000/-0001/-0003/-0004/-0005 on
  P3768; P3509-A02 carrier for Orin NX 16GB). Orin Nano Super = P3767-0005 via
  `jetson-orin-nano-devkit` (+L4T `jetson-orin-nano-devkit-super.conf`
  flash-time power config) — noted in branch docs.
- `tx` branch (already built by prior session): 8 TX-family boards; upstream
  machine name for TX2 NX is `jetson-xavier-nx-devkit-tx2-nx` (upstream naming;
  cross-generation grep exception documented in its VERIFY.md).
- `xavier` branch: **not converted** — still carries the 10 Orin boards and
  orin pins; only `xavier.md` task list exists. Gap: entire generation.
- `thor` branch: **not converted** — same as xavier. Gap: entire generation.
- `main`: still the pre-split (buildable) tree. fix.md §4 requires it to hold
  only the spec doc, README, and branch index.

## 7. Build invocation (current, unchanged on `orin`)

- `make build <board>` → `kas-container build kas/boards/<board>.yaml`
  (kas 4.5 pinned; container built from `docker/yocto/` on demand).
- `make swu <board>` → SWUpdate package (unsigned unless
  `meta/meta-arches/swupdate/keys/` present).
- `make flash <board> DEVICE=/dev/sdX` → bmaptool WIC write (SD-card boards).
- `./kas-container checkout kas/boards/<board>.yaml` → repo composition check.
- Flashing for eMMC machines (AGX Orin etc.) is via the meta-tegra
  `tegraflash`/`initrd-flash` artifact flow shipped in the image deploy dir;
  documentation gap — no per-machine flash doc exists on `orin` yet
  (`doc/BUILD_DEPLOY.md` covers only SD-card bmaptool).

## 8. Ambiguities and open items

- fix.md §5.1 orin row says R36.4.x; actual verified pin is R36.5.0/JetPack
  6.2.2 — correction documented (above).
- fix.md §5.1 thor row is now resolvable against upstream: `master-l4t-r38.2.x`
  and `master-l4t-r38.4.x` branches exist (verified by `git ls-remote`); no
  R39 branch exists, so the §5.2 thor note's "R39.x" alternative is moot.
  OE release for Thor = whatever `master-l4t-r38.4.x` declares in
  `LAYERSERIES_COMPAT` (to be read when the thor branch is cut).
- fix.md §5.1 xavier row pins `kirkstone` (L4T R35.x); upstream also offers
  `scarthgap-l4t-r35.x`. fix.md's choice (`kirkstone`) is followed; the
  alternative is recorded in the xavier branch notes.
- L4T R32.7.x terminal status for TX and R35.x terminal status for Xavier are
  fix.md assertions consistent with NVIDIA's release history; not
  independently re-verified against NVIDIA pages for this report.
- No target hardware is attached to this environment; flash/boot validation
  cannot be executed — recorded as untested in each branch README/VERIFY.
- `.pi/` (agent extensions/skills) and `.claude/` (validation gate) are repo
  tooling, tracked on all branches; left untouched.

## Branch cut point and `meta-arches` split (§13 step 2, adjusted to reality)

The prior session already cut the branches: `orin` (this branch, closest to
the pre-split tree — correct choice per §13.3), `tx` (converted **and
build-proven**: kas checkout resolved, bitbake parse clean, TX1 image +
tegraflash artifacts, per its `VERIFY.md`; meta-arches@tx pinned `b21894b…`),
`xavier` and `thor` (branch stubs still carrying orin content), and
`meta-arches` branches `orin`/`tx`/`xavier`/`thor` (xavier/thor currently
identical to orin content = placeholders). Remaining work, in order:
complete `orin` deliverables (pins, samples, Dockerfile digest, README,
FLASH, MIGRATION, VERIFY, manifest), audit/fix `tx` residue (Makefile board
table/default, completion script, `docker/tx/entrypoint.sh` missing, stale
scarthgap comment), then convert `xavier`, then `thor`, then strip `main`.
`master`/`main` restructuring per §4 happens last so each build branch is
proved first.

## Verification method note

Layer SHAs read from local checkouts at the exact pins; machine inventory read
from `layers/meta-tegra/conf/machine/` at the pin; upstream branch inventory
via `git ls-remote origin` inside `layers/meta-tegra`; L4T↔JetPack mapping via
NVIDIA Jetson Linux R36.5 release page and release notes PDF (RN_10698-r36.5.0).
Nothing in this report is asserted without one of those sources.
# Orin branch migration guide

What changed from the pre-split Arches-OS tree, and what you must do.

## What the pre-split tree was

One buildable tree (today's `main` branch): poky + meta-openembedded +
meta-tegra, all scarthgap, meta-arches floating on `develop`, ten Orin kas
board files, `main` acting as the single source of truth.

## What changed on this branch

- **meta-arches is now pinned.** `kas/repos/meta-arches.yaml` selects the
  `orin` branch of `soccentric-arches/meta-arches` at commit
  `ecb913231dbada98cadef66f487248f729f8aeb0` instead of floating `develop`.
  A rebuild re-checks out meta-arches to that commit automatically (kas
  checkout); any local meta-arches hack you carried must be re-landed as an
  upstreamable change on the `meta-arches` `orin` branch, never in place.
- **All upstream layer pins expanded to full 40-char commit SHAs** in
  `kas/repos/*.yaml`. No revision changed — only representation. Rebuilds
  resolve to the identical commits as before.
- **Build container pinned by digest** (`docker/yocto/Dockerfile`): same kas
  4.5 image, now addressed immutably.
- **Templates added:** `local.conf.sample` and `bblayers.conf.sample` at the
  branch root, for direct bitbake use without kas. Unchanged for kas users.
- **Docs made Orin-only:** README, FLASH.md (per-machine, initrd-flash +
  SD/bmaptool), VERIFY.md. Generic content remains in `doc/BUILD_DEPLOY.md`.
- Machines, recipes, image set, and WIC layouts are unchanged relative to the
  pre-split tree — this branch *is* the pre-split generation, completed.

## What a user of the old tree must do

1. Commit or stash local changes, then: `git checkout orin && git pull`.
2. Re-run the standard build: `make build jetson-agx-orin-devkit`. kas will
   check out meta-arches at the pinned commit; do not edit
   `meta/meta-arches` in place afterwards.
3. If you previously built for a non-Orin target from the shared tree (TX,
   Xavier, Thor experiments): those no longer exist here by design. Use the
   `tx`, `xavier`, or `thor` branch of this repository.
4. Flashing: follow `FLASH.md` (initrd-flash for internal storage, bmaptool
   for SD media). If you previously flashed only SD cards via
   `make flash DEVICE=…`, eMMC targets now use the initrd-flash package flow.
5. `main` is no longer a buildable tree; it holds the spec document and the
   branch index only.

## Other branches

`tx` — Tegra X1/X2/Nano (kirkstone, L4T R32.7.x, legacy tegraflash).
`xavier` — AGX Xavier / Xavier NX (kirkstone, L4T R35.x).
`thor` — AGX Thor (master-l4t-r38.x line).
None of them share pins, machines, or images with this branch.
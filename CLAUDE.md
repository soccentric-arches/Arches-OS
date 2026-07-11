# CLAUDE.md — Arches-OS
Master SoCcentric CLAUDE.md applies. This file adds local knowledge only.

Arches-OS is the Yocto + kas build for the **NVIDIA Jetson** platform (Arches
project). All customization lives in `meta/meta-arches` (kas-managed clone of
`SiliconCentric/meta-arches`). Upstream layers are **never** patched.

- Build: `make build`  (or `make build jetson-orin-nano` — board is a positional arg)
- Test:  `make test`   (fast host-side checks: docker/curl present + every
  `kas/boards/*.yaml` has a `machine:` field. NOT a Yocto build — completes in <1s)
- Lint:  `make lint`   (fast: `make -p -q` parse-checks the Makefile, then
  `python3 yaml.safe_load`s every kas yaml. NOT a build)
- Help:  `make help`
- Shell in build container: `make shell jetson-orin-nano`
- Clean: `make clean` (removes `build/`); `make clean-all` also removes caches + `deploy/`

## Architecture

**Two nested git repos.** This repo (Arches-OS) only holds the Makefile, kas
configs, and Dockerfiles — it contains **no Yocto recipes**. The actual project
layer is a *separate* git repo:

- `meta/meta-arches/` → its own `.git`, remote
  `git@github.com:SiliconCentric/meta-arches.git`, branch `master`. Recipe
  changes (new packages, bbappends, sw-description, wks) are committed **here
  and pushed to meta-arches**, never to Arches-OS. Kas clones/updates it per
  `kas/repos/meta-arches.yaml`; the working tree is gitignored from Arches-OS
  (`meta/` is in `.gitignore`).
- `layers/` → the 4 upstream layers (poky, meta-openembedded, meta-tegra,
  meta-swupdate) kas checks out. Also gitignored. Never patch.

The image recipe is `arches-image` (`meta-arches/recipes-core/images/arches-image.bb`,
based on `core-image-base`) — this is `IMAGE_TARGET` and the default `target:`
in `kas/common.yaml`. `meta-arches` layer: priority 10, `LAYERDEPENDS = core
tegra`, `LAYERSERIES_COMPAT = scarthgap`. Default board `jetson-orin-nano`
maps to MACHINE `jetson-orin-nano-devkit` (UEFI + extlinux boot, no U-Boot).

## Boards (11 configs in `kas/boards/`)

Board is a positional arg, not `BOARD=`. The Makefile auto-derives `MACHINE`
from the `machine:` line in the chosen yaml.

- **SD card** (default): `jetson-orin-nano`
- **eMMC** (AGX Orin family): `jetson-agx-orin-devkit`,
  `jetson-agx-orin-devkit-industrial`, `p3737-0000-p3701-0004`,
  `p3737-0000-p3701-0005`
- **NVMe**: `jetson-orin-nano-devkit-nvme`, `p3509-a02-p3767-0000`,
  `p3768-0000-p3767-0000`, `p3768-0000-p3767-0001`,
  `p3768-0000-p3767-0003`, `p3768-0000-p3767-0004`

KAS image: `arches-kas:latest` (built from `docker/yocto/`). kas release pinned
to 4.5 via `kas-container`. Build runs inside Docker; `build/`, `downloads/`,
`sstate-cache/` are bind-mounted host dirs (gitignored).

## OTA / SWUpdate signing

`make swu` is **unsigned by default** (expected when
`meta/meta-arches/swupdate/keys/swupdate-private.pem` is absent — UEFI-boot
boards like Orin Nano also ship without a `.dtb`). To sign, drop an RSA-4096
private key at that path; the Makefile then generates `sw-description.sig` and
packs a signed `.swu`. Override the version with `make swu SWU_VERSION=1.2.3`.

## Helper scripts (repo root, not part of the make flow)

- `patch_health.py` — patches a *sibling* component: fixes `{{}}` → `{}` and a
  duplicate `#include` in `../Arches-Server/.../HealthController.cc`. No-op if
  Arches-Server isn't checked out. Crosses component boundaries — run knowingly.
- `delete_branches.sh` — deletes every local+remote branch except the protected
  set (`develop`, `master`, `release`, `release-v0.0.2`). Destructive.

## Do
- **kas manages `layers/` — never track its contents.** `layers/` is in
  `.gitignore`. The 5 kas repos (poky, meta-openembedded, meta-tegra,
  meta-swupdate, meta-arches) are checked out by kas into `layers/` (and
  `meta/meta-arches`), defined in `kas/repos/*.yaml`.
- **Quick repo-setup check without a full build:** `./kas-container checkout
  kas/boards/<board>.yaml` runs only the kas checkout phase (clone/fetch/checkout
  repos) — fast, no bitbake. Use it to verify layer setup.
- **Recovery if `make build` clobbers the repo root** (kas checks a repo out at
  root instead of `layers/<repo>`): the Arches-OS `.git` objects/refs survive
  (kas *augments* the existing `.git`, it does not destroy it). Recover with:
  `git checkout develop` → `git remote set-url origin
  git@github.com:SiliconCentric/Arches-OS.git` → `git fetch origin --prune` →
  `git branch -D scarthgap`. Verify `git rev-parse develop` == `297f259` and
  `origin` == SiliconCentric/Arches-OS.
- **Verify the build progresses before walking away:** `make build` is 8000+
  bitbake tasks (hours). Confirm it reaches "Running task N of 8148" in the log,
  then let it run separately.
- `make build` is resumable — killing it mid-build is safe; rerun `make build`.
- **All build-artifact targets verified working (2026-07-10):** `make build`,
  `swu`, `sdk`, `esdk`, `sdk-image`, `esdk-image`, `kas-image`, `shell`,
  `flash` (dry), `deploy-*`, `ensure-*`, `lint`, `test`, `check-board` (all 11
  boards). `make rebuild-image` shares the `build` path (adds `cleansstate`).
  Skipped: `make completion` (edits `~/.bashrc`), `make clean*` (destructive).
- **`make swu` takes a few minutes** — it gzips the full rootfs.ext4 (28 GB
  logical / ~1.1 GB real, sparse). The unsigned `.swu` (~364 MB) is expected
  when `meta/meta-arches/swupdate/keys/` is absent; missing `.dtb` is expected
  for UEFI-boot boards (Orin Nano).

## Don't
- **NEVER use a recursive `?=` `$(shell date)` for a version that must stay
  constant across a multi-minute recipe *and* a recursive sub-make.** `make swu`
  had `SWU_VERSION ?= $(shell date +%Y%m%d%H%M)` — it re-ran `date` on every
  expansion, so the `sw-description` version (sed before the gzip), the `.swu`
  filename (cpio after), and the `deploy-swu` lookup (a separate sub-make)
  drifted to different minutes and deploy failed ("...1523.swu" built vs
  "...1525.swu not found"). Fix: freeze with `:=` and pass `SWU_VERSION` to the
  `deploy-swu` sub-make (mirroring `DEPLOY_TS`).
- **NEVER leave orphan gitlink (submodule) entries in the tree for `layers/`
  paths.** This repo previously tracked `layers/meta-swupdate` and
  `layers/meta-raspberrypi` as gitlinks (mode 160000) with NO `.gitmodules`.
  Running `make build` with those present caused kas to clone `meta-swupdate`
  AT THE REPO ROOT, overwriting the Arches-OS `.git` origin (→ sbabic/meta-
  swupdate), HEAD (→ scarthgap), and tracked files. Fix applied: `git rm --cached
  layers/meta-swupdate layers/meta-raspberrypi` (committed `617c54f`, 2026-07-10).
  Submodules are forbidden by the master CLAUDE.md anyway.
- **`layers/meta-raspberrypi` was spurious** — Arches is Jetson, not RPi. It was
  a leftover from Acadia (the RPi reference project) and not in any kas config.
- Don't run `make build` to completion inside an interactive session unless you
  have hours to spare — kick it off in the background and monitor the log.
- **Default branch is `main`, not `develop`.** `origin/HEAD` → `main`; both
  `main` and `develop` exist and are kept at the same commit. The master
  workflow (§9) assumes fix PRs branch off `develop` — in this repo use `main` as
  the base unless told otherwise.
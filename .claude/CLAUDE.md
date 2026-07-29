# CLAUDE.md - Arches-OS

Master SoCcentric CLAUDE.md applies. This file adds local knowledge only.

Arches-OS is the Yocto + kas build for the NVIDIA Jetson platform (Arches project). All customization lives in `meta/meta-arches` (kas-managed clone of `SiliconCentric/meta-arches`). Upstream layers are never patched.

# Commands

* Build: `make build` (or `make build jetson-orin-nano` - board is a positional arg)
* Test: `make test`
* Lint: `make lint`
* Help: `make help`
* Shell in build container: `make shell jetson-orin-nano`
* Clean: `make clean` (removes `build/`); `make clean-all` also removes caches + `deploy/`

KAS image: `arches-kas:latest` (built from `docker/yocto/`). kas release pinned to 4.5 via `scripts/kas-container`. Build runs inside Docker; `build/`, `cache/downloads/`, and `cache/sstate-cache/` are bind-mounted host dirs (gitignored).

# Do

* kas manages `layers/` - never track its contents. `layers/` is in `.gitignore`. The 5 kas repos (poky, meta-openembedded, meta-tegra, meta-swupdate, meta-arches) are checked out by kas into `layers/` (and `meta/meta-arches`), defined in `kas/repos/*.yaml`.
* Quick repo-setup check without a full build: `./kas-container checkout kas/boards/<board>.yaml` runs only the kas checkout phase (clone/fetch/checkout repos) - fast, no bitbake. The root command delegates to the maintained copy in `scripts/`.
* Recovery if `make build` clobbers the repo root (kas checks a repo out at root instead of `layers/<repo>`): the Arches-OS `.git` objects/refs survive (kas augments the existing `.git`, it does not destroy it). Recover with: `git checkout develop` -> `git remote set-url origin git@github.com:SiliconCentric/Arches-OS.git` -> `git fetch origin --prune` -> `git branch -D scarthgap`. Verify `git rev-parse develop` == `297f259` and `origin` == SiliconCentric/Arches-OS.
* Verify the build progresses before walking away: `make build` is 8000+ bitbake tasks (hours). Confirm it reaches "Running task N of 8148" in the log, then let it run separately.
* `make build` is resumable - killing it mid-build is safe; rerun `make build`.
* All build-artifact targets verified working (2026-07-10): `make build`, `swu`, `sdk`, `esdk`, `sdk-image`, `esdk-image`, `kas-image`, `shell`, `flash` (dry), `deploy-*`, `ensure-*`, `lint`, `test`, `check-board` (all 11 boards). `make rebuild-image` shares the `build` path (adds `cleansstate`). Skipped: `make completion` (edits `~/.bashrc`), `make clean*` (destructive).
* `make swu` takes a few minutes - it gzips the full rootfs.ext4 (28 GB logical / ~1.1 GB real, sparse). The unsigned `.swu` (~364 MB) is expected when `meta/meta-arches/swupdate/keys/` is absent; missing `.dtb` is expected for UEFI-boot boards (Orin Nano).

# Don't

* NEVER use a recursive `?=` `$(shell date)` for a version that must stay constant across a multi-minute recipe AND a recursive sub-make. `make swu` had `SWU_VERSION ?= $(shell date +%Y%m%d%H%M)` - it re-ran `date` on every expansion, so the `sw-description` version (sed before the gzip), the `.swu` filename (cpio after), and the `deploy-swu` lookup (a separate sub-make) drifted to different minutes and deploy failed ("...1523.swu" built vs "...1525.swu not found"). Fix: freeze with `:=` and pass `SWU_VERSION` to the `deploy-swu` sub-make (mirroring `DEPLOY_TS`).
* NEVER leave orphan gitlink (submodule) entries in the tree for `layers/` paths. This repo previously tracked `layers/meta-swupdate` and `layers/meta-raspberrypi` as gitlinks (mode 160000) with NO `.gitmodules`. Running `make build` with those present caused kas to clone `meta-swupdate` AT THE REPO ROOT, overwriting the Arches-OS `.git` origin (-> sbabic/meta-swupdate), HEAD (-> scarthgap), and tracked files. Fix applied: `git rm --cached layers/meta-swupdate layers/meta-raspberrypi` (committed `617c54f`, 2026-07-10). Submodules are forbidden by the master CLAUDE.md anyway.
* `layers/meta-raspberrypi` was spurious - Arches is Jetson, not RPi. It was a leftover from an earlier reference template and not in any kas config.
* Don't run `make build` to completion inside an interactive session unless you have hours to spare - kick it off in the background and monitor the log.

# Validation gate - .claude/validate.sh

```
./.claude/validate.sh quick   # seconds: kas YAML + Makefile parse, board `machine:` fields, orphan-gitlink guard, prerequisite check
./.claude/validate.sh full    # + `make validate`; the hours-long image build only with `ARCHES_VALIDATE_BUILD_IMAGE=1`
```

Exit codes follow the fleet contract: `0` pass, `1`-`76` fail, `77` means a check never ran (missing toolchain) - which is not a pass. Runs automatically via the `Stop` hook in `.claude/settings.json`, on demand via `/validate`, and as part of any loop the engine executes here.

Human-owned: the Loop Engine runs this script and never edits it. If a check is wrong, fix it yourself or raise it in the loop's Lessons Learned.

<!-- BEGIN loop-engine -->
## Do's and Don'ts (maintained by the Loop Engine)

*Appended by the Loop Engine on loop close; curated by a human when approving a loop out of `in-review/`. Nothing outside this fence is engine-writable.*

<!-- END loop-engine -->

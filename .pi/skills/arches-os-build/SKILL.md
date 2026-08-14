---
name: arches-os-build
description: Yocto + kas image build for NVIDIA Jetson (Arches-OS). Use when working with kas board/repo config, meta-arches recipes, SWUpdate packaging, kernel config fragments, device-tree overlays, or the build/lint/test/validate workflow in the Arches-OS repository.
---

# Arches-OS Build Skill

Yocto + kas image build for the Jetson platform. Produces the OS that Client, Configuration, and the HAL/gRPC middleware all run inside.

## Repository Layout

```
meta/meta-arches/          # All Arches customization (soccentric-arches/meta-arches)
kas/repos/*.yaml           # 5 kas repos: poky, meta-openembedded, meta-tegra, meta-swupdate, meta-arches
kas/boards/<board>.yaml    # Per-board config (11 boards)
kas/common.yaml            # Shared kas config
layers/                    # Checked out by kas — gitignored, never tracked
scripts/                   # All scripts including kas-container
docker/yocto/              # Builds arches-kas:latest Docker image
build/                     # Build output — gitignored
cache/downloads/           # BitBake download cache — gitignored
cache/sstate-cache/        # BitBake sstate cache — gitignored
```

## Commands

```bash
# Fast sanity gate (seconds, no Docker needed)
./.claude/validate.sh quick

# Full validation (adds kas checkout via Docker)
./.claude/validate.sh full

# Kas checkout only (verifies repo composition without BitBake)
./kas-container checkout kas/boards/<board>.yaml

# Build targets
make build <board>              # Full image build (hours, resumable)
make shell <board>              # Shell inside build container
make swu                        # Package SWUpdate artifact
make lint                       # Makefile + kas YAML checks
make test                       # Test targets
make clean                      # Remove build/
make clean-all                  # Remove build/ + caches + deploy/

# BitBake inside container (after make shell)
bitbake-layers show-recipes <pn>   # Confirm recipe parses
bitbake -c fetch <pn>              # Verify fetch succeeds
bitbake -c unpack <pn>             # Verify SRC_URI/S layout
bitbake <pn>                       # Build recipe standalone
```

## Do

- Put all Arches-specific code in `meta/meta-arches/` — never patch upstream layers
- Keep `layers/` untracked; let kas manage it
- Use `.bbappend` files to extend upstream recipes
- Validate with `./.claude/validate.sh quick` before claiming done
- For long builds: kick off in background, confirm log reaches "Running task N of 8148", then let it run separately
- Use `make shell <board>` for interactive container work
- Freeze `SWU_VERSION` with `:=` (not `?=`) to prevent drift across recursive sub-makes

## Do Not

- Never edit `layers/` contents — kas manages them
- Never add submodules or gitlinks under `layers/` — this can clobber the repo root's `.git`
- Never use recursive `?= $(shell date)` for version values — use `:=` instead
- Never add `meta-raspberrypi` — Arches is Jetson-only
- Never run `make build` to completion inside an interactive session (it takes hours)
- Never edit `.claude/validate.sh`, `.claude/lib/`, `.claude/hooks/`, `.claude/commands/`, or `.claude/settings.json` — those are human-owned

## Adding a New Recipe from a Git URL

1. Place under `meta/meta-arches/recipes-<category>/<pn>/<pn>_<version>.bb`
2. Convert SSH/git URL to BitBake fetcher syntax:
   - `git@github.com:ORG/REPO.git` → `git://git@github.com/ORG/REPO.git;protocol=ssh;branch=<branch>`
3. Pin `SRCREV` to a specific commit hash (never `AUTOREV`)
4. Fill in `LICENSE`, `LIC_FILES_CHKSUM`, `DEPENDS`/`RDEPENDS`, `do_install`/`FILES:${PN}`
5. Validate with BitBake inside container (narrowest first):
   ```bash
   bitbake-layers show-recipes <pn>   # parses recipe
   bitbake -c fetch <pn>              # verifies SSH/git fetch
   bitbake -c unpack <pn>             # verifies source layout
   bitbake <pn>                       # standalone build
   ```

## Kernel Config Fragments

Drop a `.cfg` file into `meta/meta-arches/recipes-kernel/linux/files/<name>.cfg`, then add `<name>` to `ARCHES_KERNEL_FEATURES` in `meta/meta-arches/arches.inc`.

## Device-Tree Overlays

1. Copy `recipes-kernel/nvidia-kernel-oot/files/example-overlay.dts.template` to `<name>.dts`
2. Add `<name>` to `ARCHES_DEVICETREE_OVERLAY_SOURCES` (makes it buildable)
3. Add `<name>` to `ARCHES_DEVICETREE_OVERLAYS` (applied at boot) or `ARCHES_FLASH_OVERLAYS` (applied from SPI)

## Recovery: Clobbered Repo Root

If kas checks out a repo at root instead of `layers/<repo>`:

```bash
git checkout develop
git remote set-url origin git@github.com:soccentric-arches/Arches-OS.git
git fetch origin --prune
git branch -D scarthgap
```

## Validation Gate Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1-76 | A check failed — report which one |
| 77 | Check never ran (missing toolchain) — not a pass |

## Mandatory

- [ ] All changes are in `meta/meta-arches/` or `scripts/` — never in upstream layers
- [ ] No `layers/` paths are tracked as gitlinks (mode 160000)
- [ ] `./.claude/validate.sh quick` passes
- [ ] `make lint` and `make test` pass for Makefile/kas-YAML changes
- [ ] Any `SWU_VERSION` uses frozen `:=` assignment, not recursive `?=`
- [ ] No generated files, caches, credentials, or private keys in source control
- [ ] Final diff is limited to the requested behavior

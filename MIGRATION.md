# TX Migration

The TX branch is intentionally separate from the Orin tree. TX uses Yocto
kirkstone, Jetson Linux R32.7.6, the legacy tegraflash flow, and cboot or U-Boot;
the Orin tree uses a newer BSP and UEFI/extlinux assumptions.

The branch changes are:

- kas repositories point to TX-compatible kirkstone and R32.7.6 commits.
- Orin board entries are removed and eight verified TX board entries are added.
- The TX image emits `ext4` and `tegraflash` artifacts.
- Orin UEFI bbappends and Orin WIC layouts are removed from `meta-arches`.
- The kernel configuration append matches the R32 `linux-tegra` recipe.
- The TX `meta-arches` layer declares kirkstone compatibility and is pinned by
  the root kas manifest.
- Container, build-template, flash, verification, and migration documents are
  branch-local.

SWUpdate files are carried forward because update infrastructure is outside the
generation-porting scope. Their Orin-specific slot behavior remains an explicit
verification item in `VERIFY.md` and must not be treated as TX hardware support.

What a user of the pre-split tree must do:

1. `git checkout tx` (commit or stash local changes first).
2. If `build/` contains residue from a non-TX generation build, remove
   `build/conf/templateconf.cfg` (or run `make clean-build`) before the first
   kas run — a stale `templateconf.cfg` from a scarthgap build breaks the
   kirkstone TEMPLATECONF probe (see `VERIFY.md`).
3. Build with `make build` (defaults to `jetson-tx1-devkit`).
4. Flash via `TX_FLASH.md` — the WIC/bmaptool flow from the old tree does not
   apply to this generation.
5. Any local `meta/meta-arches` hacks must be re-landed on the `meta-arches`
   `tx` branch (pinned at `b21894b…`); never edit the nested clone in place.

2026-09-02 audit additions: file-relative kas includes fixed to repo-relative
(kas 4.5 checkout verified), `docker/tx/` orphan Dockerfile removed and the
build container digest-pinned in `docker/yocto/`, Makefile board table and
flash target made TX-correct (flash now points to `TX_FLASH.md`).
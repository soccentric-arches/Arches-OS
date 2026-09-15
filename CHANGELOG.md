# Changelog

Maintained by the Loop Engine. One entry per loop that touched this repo,
newest first, appended on loop close (pass or fail) and committed on the loop's
own feature branch. See the master repo's `Arches-Loop-Orchestration-Spec-v2.md` §11.1.

Entries written by hand are fine; the engine inserts directly under this header.

## 2026-09-15

### Summary

Wired both Arches-Configuration's WebConfig and Arches-Instrumentation's yocto
layer into the kas layer set, correcting two stale claims: Task.md D-08 marked
Instrumentation wiring "DONE" when it never was, and D-09/root CLAUDE.md described
Configuration's meta-webconfig layer as already existing (it didn't — authored
fresh in Arches-Configuration in this change). WebConfig now installs on every
board; Instrumentation is wired but not yet in any IMAGE_INSTALL, since its
COMPATIBLE_MACHINE list doesn't cover any of this repo's actual Jetson boards.
Done ahead of the Task.md B-01 ownership decision (Configuration vs
Instrumentation), per explicit human direction — does not resolve B-01.

### Files changed

- `kas/repos/arches-configuration.yaml`: New — fetches Arches-Configuration's
  meta-webconfig subdirectory as a layer.
- `kas/repos/arches-instrumentation.yaml`: New — fetches Arches-Instrumentation's
  yocto subdirectory as a layer.
- `kas/common.yaml`: Added both new repo includes.
- `meta/meta-arches/recipes-core/images/arches-image-common.inc`: Added
  `IMAGE_INSTALL:append` for `webconfigd webconfig-static webconfig-schemas
  webconfig-manifest`. Instrumentation intentionally not added here — see summary.

## 2026-09-08

### Summary

Wired the Jetson Nano SD-card flashing instructions to deploy alongside the flash bundle in `deploy/images/BOARD_TS/`, so the doc ships with the artifact it documents. Fixed dangling references to the previously-deleted `TX_FLASH.md`.

### Files changed

- `Makefile`: Added `FLASH_SDCARD_DOC` variable; `deploy-images` now copies `FLASH_SDCARD.md` into `deploy/images/BOARD_TS/` for the Nano SD-card boards (`jetson-nano-devkit`, `jetson-nano-2gb-devkit`) alongside the tegraflash bundle; `flash` target now prints the correct per-board procedure (`dosdcard.sh` with a pointer to the doc for Nano boards, `doflash.sh` USB recovery mode for others) instead of referencing the deleted `TX_FLASH.md`.
- `meta/meta-arches/recipes-core/images/FLASH_SDCARD.md`: Noted that this file is automatically copied into `deploy/images/<board>_<timestamp>/` by `make build`/`make deploy-images`.
- `README.md`: Replaced two dangling references to the deleted `TX_FLASH.md` with the current bundle-extraction/flash procedure and a pointer to `FLASH_SDCARD.md`.
- `CHANGELOG.md`: Recorded this change with its dated summary and per-file details.

## 2026-09-08

### Summary

Documented the supported, safety-checked procedure for creating Jetson Nano SD-card boot media from a built image bundle.

### Files changed

- `meta/meta-arches/recipes-core/images/FLASH_SDCARD.md`: Added build, bundle-extraction, device-verification, and `dosdcard.sh` flashing instructions for Nano SD-card boards; documented recovery-mode exclusions and prohibited incorrect WIC write methods.
- `CHANGELOG.md`: Recorded this documentation change with its dated summary and per-file details.

## 2026-09-08

### Summary

Established a mandatory release-readiness change-log rule for all repository changes.

### Files changed

- `.claude/CLAUDE.md`: Added Rule 1 requiring dated summaries and a per-file change description in this changelog before work is completed.
- `CHANGELOG.md`: Recorded the new mandatory change-log policy and its affected file.

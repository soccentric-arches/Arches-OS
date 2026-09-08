# Changelog

Maintained by the Loop Engine. One entry per loop that touched this repo,
newest first, appended on loop close (pass or fail) and committed on the loop's
own feature branch. See the master repo's `Arches-Loop-Orchestration-Spec-v2.md` §11.1.

Entries written by hand are fine; the engine inserts directly under this header.

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

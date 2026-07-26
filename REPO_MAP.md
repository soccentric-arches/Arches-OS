# Arches-OS

**Remote:** `git@github.com:SiliconCentric/Arches-OS.git`
**Parent project:** [Arches](../Arches.md) (target hardware: **NVIDIA Jetson** (Tegra family, L4T/JetPack OS) application processor with an **STM32** real-time co-processor.)
**Leaf type:** `<Project>-OS`
**Status:** REAL — actively built out

No top-level README, but a working `kas` + Docker Yocto build for **NVIDIA Jetson** with an extensive operational `CLAUDE.md`.

**Board:** default `jetson-orin-nano` (positional arg to `make build`). All platform customization lives in a kas-managed `meta/meta-arches` layer (clone of `SiliconCentric/meta-arches`); upstream layers (`poky`, `meta-openembedded`, `meta-tegra`, `meta-swupdate`) are checked out by kas into a **gitignored** `layers/` directory and must never be hand-edited or tracked.

**Targets:** `make build` (~8000+ bitbake tasks, hours, resumable if interrupted), `make test`, `make lint`, `make shell [board]`, `make swu` (OTA package — gzips the full rootfs, ~364MB unsigned if `meta/meta-arches/swupdate/keys/` is absent), `make sdk`/`esdk`/`sdk-image`/`esdk-image`, `make flash`, `make deploy-*`, `make clean`/`clean-all`.

**KAS image:** `arches-kas:latest` (built from `docker/yocto/`), kas release pinned to 4.5 via `scripts/kas-container`. `build/`, `cache/downloads/`, `cache/sstate-cache/` are gitignored bind-mounted host dirs.

**Known incident (documented in CLAUDE.md):** this repo previously tracked `layers/meta-swupdate` and `layers/meta-raspberrypi` as orphan gitlink (submodule, mode 160000) entries with no `.gitmodules`. Running `make build` with those present caused kas to clone `meta-swupdate` **at the repo root**, overwriting this repo's own `.git` origin/HEAD/tracked files. Fixed via `git rm --cached` (commit `617c54f`, 2026-07-10); recovery steps are documented if it recurs. `layers/meta-raspberrypi` was a leftover from the Acadia (Raspberry Pi) template and was never wired into any kas config — Arches is Jetson, not RPi.

**Nested git clones (not submodules):** `layers/poky`, `layers/meta-openembedded`, `layers/meta-tegra`, `layers/meta-swupdate`, `meta/meta-arches` — each is a separate `.git` checked out by kas.

---
Part of the `Arches` project in the `project-managers` fleet. See `docs/project-managers.md` for the full 9-project / 8-leaf hierarchy and shared conventions.

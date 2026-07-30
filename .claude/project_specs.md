# Arches-OS — specs

Parent project: Arches (target hardware: NVIDIA Jetson, Tegra family, L4T/JetPack OS, with an STM32 real-time co-processor)
Leaf type: `<Project>-OS`

## What this is

Arches-OS is the Yocto + kas build for the NVIDIA Jetson platform (Arches project). All customization lives in `meta/meta-arches` (kas-managed clone of `SiliconCentric/meta-arches`). Upstream layers are never patched.

KAS image: `arches-kas:latest` (built from `docker/yocto/`). kas release pinned to 4.5 via `scripts/kas-container`. Build runs inside Docker; `build/`, `cache/downloads/`, and `cache/sstate-cache/` are bind-mounted host dirs (gitignored).

kas manages `layers/` — never track its contents. `layers/` is in `.gitignore`. The 5 kas repos (poky, meta-openembedded, meta-tegra, meta-swupdate, meta-arches) are checked out by kas into `layers/` (and `meta/meta-arches`), defined in `kas/repos/*.yaml`.

Part of the Arches project in the project-managers fleet. See `docs/project-managers.md` for the full 9-project / 8-leaf hierarchy and shared conventions.

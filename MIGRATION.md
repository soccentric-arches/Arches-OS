# Thor branch migration guide

What changed from the pre-split Arches-OS tree, and what you must do.

## What the pre-split tree was

One buildable tree (today's `main` branch): poky + meta-openembedded +
meta-tegra, all scarthgap, meta-arches floating on `develop`, ten Orin kas
board files. It could not build for Thor: the BSP pins, kernel recipe,
image types, and flashing flow were Orin-specific.

## What changed on this branch

- **Generation pins:** meta-tegra moved to `master-l4t-r38.4.x` @ `83f51cb2…`
  (L4T R38.4.0 / JetPack 7.x — Thor-only; NVIDIA dropped Orin support from
  the R38 line). OE-Core is **whinlatter**, consumed as **split repositories**
  (openembedded-core, bitbake 2.18, meta-yocto) because the poky combo repo
  retired its master/whinlatter line upstream. meta-openembedded and
  meta-swupdate track their whinlatter-compatible branches. meta-arches is
  pinned to the `thor` branch at `1e8009c…`.
- **Boards:** the ten Orin kas board files are removed; two verified Thor
  machines are configured (`jetson-agx-thor-devkit` flagship default,
  `jetson-agx-thor-t4000`).
- **meta-arches retargeted:** whinlatter compatibility; EDK2 GCC-LTO
  workaround retargeted to `edk2-firmware-tegra-rcmboot_38.4.0` and
  `edk2-nvidia-standalone-mm_38.4.0` (renamed upstream from
  `standalone-mm-optee-tegra` on R38); kernel append renamed to
  `linux-noble-nvidia-tegra_%.bbappend` (R38 kernel is
  `linux-noble-nvidia-tegra_6.8`); Orin A/B WIC layouts removed.
- **Image/flash flow:** `ext4 tegraflash-tar` image types; the unified
  initrd-flash flow flashes the NVMe-only dev kit; deploy collects
  `.tegraflash-tar` + rootfs images; `make flash` points at `FLASH.md`.
- **Build container digest-pinned** in `docker/yocto/Dockerfile`.
- **Templates added:** `local.conf.sample`, `bblayers.conf.sample`.

## What a user of the old tree must do

1. Commit or stash local changes, then: `git checkout thor && git pull`.
2. If `build/` contains residue from another generation's build, remove
   `build/conf/templateconf.cfg` (or `make clean-build`) before the first
   kas run — a stale `templateconf.cfg` from another OE release breaks the
   TEMPLATECONF probe (see `VERIFY.md`).
3. Build: `make build` (defaults to `jetson-agx-thor-devkit`).
4. Flash: follow `FLASH.md` (unified initrd-flash; NVMe rootfs).
5. Any local `meta/meta-arches` hacks must be re-landed on the `meta-arches`
   `thor` branch; never edit the nested clone in place.
6. `main` is no longer a buildable tree; it holds the spec document and the
   branch index only.

## Other branches

`tx` — Tegra X1/X2/Nano (kirkstone, L4T R32.7.x, legacy tegraflash).
`xavier` — AGX Xavier / Xavier NX (kirkstone, L4T R35.6.4).
`orin` — AGX/Orin NX/Nano (scarthgap, L4T R36.5.0).
None of them share pins, machines, or images with this branch.
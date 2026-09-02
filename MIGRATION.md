# Xavier branch migration guide

What changed from the pre-split Arches-OS tree, and what you must do.

## What the pre-split tree was

One buildable tree (today's `main` branch): poky + meta-openembedded +
meta-tegra, all scarthgap, meta-arches floating on `develop`, ten Orin kas
board files. It could not build for Xavier: the BSP pins, kernel recipe,
bootloader appends, and image outputs were Orin-specific.

## What changed on this branch

- **Generation pins:** meta-tegra moved to `kirkstone` @ `47519b99…`
  (L4T R35.6.4 / JetPack 5.1.6); poky, meta-openembedded, and meta-swupdate
  moved to their kirkstone branches at full commit pins; meta-virtualization
  is not consumed on this generation; meta-arches is pinned to the
  `xavier` branch at `1a485e7…`.
- **Boards:** the ten Orin kas board files are removed; four verified Xavier
  machines are configured (`jetson-agx-xavier-devkit`,
  `jetson-agx-xavier-industrial`, `jetson-xavier-nx-devkit`,
  `jetson-xavier-nx-devkit-emmc`).
- **meta-arches retargeted:** kirkstone compatibility declared; EDK2 GCC-LTO
  workaround retargeted to `standalone-mm-optee-tegra_35.6.4`; the
  `edk2-firmware-tegra-rcmboot` append dropped (no such recipe on R35);
  kernel append renamed to `linux-tegra_%.bbappend` (R35 kernel recipe is
  `linux-tegra_5.10`); Orin A/B WIC layouts removed.
- **Image/flash flow:** `ext4 tegraflash` image types; deploy collects
  `.tegraflash.tar.gz` + `.rootfs.ext4`; `make flash` points at `FLASH.md`
  (initrd-flash / dosdcard), not bmaptool.
- **Build container digest-pinned** in `docker/yocto/Dockerfile` (same kas
  4.5 base as the other branches; the digest is the pin, not a tag).
- **Templates added:** `local.conf.sample`, `bblayers.conf.sample`.

## What a user of the old tree must do

1. Commit or stash local changes, then: `git checkout xavier && git pull`.
2. If `build/` contains residue from another generation's build, remove
   `build/conf/templateconf.cfg` (or `make clean-build`) before the first
   kas run — a stale `templateconf.cfg` breaks the TEMPLATECONF probe
   across OE releases (see `VERIFY.md`).
3. Build: `make build` (defaults to `jetson-agx-xavier-devkit`).
4. Flash: follow `FLASH.md`. The old tree's WIC/bmaptool flow does not
   apply to this generation.
5. Any local `meta/meta-arches` hacks must be re-landed on the `meta-arches`
   `xavier` branch; never edit the nested clone in place.
6. `main` is no longer a buildable tree; it holds the spec document and the
   branch index only.

## Other branches

`tx` — Tegra X1/X2/Nano (kirkstone, L4T R32.7.x, legacy tegraflash).
`orin` — AGX/Orin NX/Nano (scarthgap, L4T R36.5.0, UEFI + initrd-flash).
`thor` — AGX Thor (master-l4t-r38.x line).
None of them share pins, machines, or images with this branch.
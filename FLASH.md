# Flash procedures — Orin generation

These procedures are specific to the Orin generation (L4T R36.5.0, UEFI +
extlinux boot, A/B-capable layout). They are **not** the TX legacy-tegraflash
flow, the Xavier R35 flow, or the Thor unified flow; do not copy them across
branches.

All flashing happens from the build output in
`build/tmp/deploy/images/<MACHINE>/`. Put the target in **USB recovery mode**
(FORCE_RECOVERY button while powering) before the USB-dependent flows.

## 1. SD-card media — WIC + bmaptool

Applies to: `jetson-orin-nano-devkit` when booting from the SD card slot
(P3767-0005 dev kit module on P3768), and any target where you intend to boot
from removable SD media written outside the device.

The build produces `*.wic.bz2` + `*.wic.bmap` in the deploy directory.

```sh
make flash jetson-orin-nano DEVICE=/dev/sdX
```

The Makefile validates that `DEVICE` is a block device and writes the newest
WIC with its bmap. This is destructive to the target device.

Equivalent manual command:

```sh
bmaptool copy --bmap <image>.wic.bmap <image>.wic.bz2 /dev/sdX
```

## 2. Internal storage (eMMC / module) — initrd-flash

Applies to: `jetson-agx-orin-devkit`, `jetson-agx-orin-devkit-industrial`,
`p3737-0000-p3701-0004`, `p3737-0000-p3701-0005`, `p3768-0000-p3767-0000`,
`p3768-0000-p3767-0001`, `p3768-0000-p3767-0003`, `p3768-0000-p3767-0004`,
`p3509-a02-p3767-0000`, and `jetson-orin-nano-devkit-nvme` (NVMe rootfs).

The build produces a flash package containing meta-tegra's `initrd-flash`
script and the per-machine flash configuration. Procedure:

1. Build the image for the machine (`make build <board>`).
2. Enter USB recovery mode on the target.
3. From the deploy directory, run the packaged `initrd-flash` script:

```sh
cd build/tmp/deploy/images/<MACHINE>
sudo ./initrd-flash
```

Reference: `layers/meta-tegra/docs/initrd-flashing-support.md` at the pinned
commit (host prerequisites: `sgdisk`, `udisksctl`; disable desktop automount;
`bmaptool` is used automatically when present, which the build container also
ships for host-side use).

- For NVMe/external-rootfs targets (e.g. `jetson-orin-nano-devkit-nvme`),
  initrd-flash handles the external-device flow; see the same upstream doc
  for the rootfs-on-external-device configuration options.

## 3. OTA (after first flash)

A/B slot layout is baked into the WIC files (`meta/meta-arches/wic/`). The
OTA update artifact is produced by:

```sh
make swu <board>
```

output at `deploy/swu/<board>_<ts>/`. Signing requires
`meta/meta-arches/swupdate/keys/` (absent keys ⇒ unsigned artifact, by
design). Install/rollback behavior on a live target is untested — see
`VERIFY.md`.

## Untested status

No physical target was available in the environment where this branch was
prepared. Every procedure above follows the meta-tegra documentation and
generated artifact names at the pinned commit but has not been executed
against hardware. Update `VERIFY.md` when a target is validated.
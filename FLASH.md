# Flash procedures — Thor generation

Specific to the Thor generation (L4T R38.4.0 / JetPack 7.x, UEFI boot,
**NVMe-only rootfs** — the Thor dev kit has no internal storage). These are
**not** the TX legacy-tegraflash flow, the Xavier R35 flow, or the Orin R36
flow; do not copy them across branches.

All flashing happens from the build output in
`build/tmp/deploy/images/<MACHINE>/`. Put the target in **USB recovery mode**
before flashing.

## 1. Unified initrd-flash (both Thor machines)

Applies to: `jetson-agx-thor-devkit` (T5000, P3834-0008) and
`jetson-agx-thor-t4000` (P3834-0000).

Both machines declare no internal storage (`TEGRaFLASH_NO_INTERNAL_STORAGE =
1` in the pinned BSP) with the rootfs on NVMe — so **initrd-flash is the
flash path**, per the meta-tegra flashing matrix (NVMe rootfs →
`initrd-flash`).

The build produces the `.tegraflash-tar` flash package containing the
signing helper, flash XML, and `initrd-flash` tooling:

1. Build the image for the machine (`make build <board>`).
2. Enter USB recovery mode.
3. Extract the flash package and run the flow:

```sh
cd build/tmp/deploy/images/<MACHINE>
mkdir -p /tmp/tegraflash-<MACHINE>
tar -xf *.tegraflash-tar -C /tmp/tegraflash-<MACHINE>
cd /tmp/tegraflash-<MACHINE>
sudo ./initrd-flash
```

Reference: `layers/meta-tegra/docs/initrd-flashing-support.md` and
`docs/Flashing-the-Jetson-Dev-Kit.md` at the pinned commit (host
prerequisites: `sgdisk`, `udisksctl`; disable desktop automount; `bmaptool`
is used automatically when present).

## 2. OTA (after first flash)

The SWUpdate infrastructure is carried forward unchanged (`make swu
<board>`). A/B rootfs slot behavior on R38 Thor with the carried-forward
scripts is unvalidated — see `VERIFY.md`.

## Untested status

No physical target was available in the environment where this branch was
prepared. Every procedure above follows the pinned meta-tegra documentation
and generated artifact names but has not been executed against hardware.
Update `VERIFY.md` when a target is validated.
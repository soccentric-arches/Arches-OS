# Arches-OS — TX generation branch

Arches-OS build tree for the **NVIDIA Tegra X1/X2 generation** only:
Jetson TX1, TX2 family, and Nano family, on **L4T R32.7.6 / JetPack 4.6.6**,
Yocto **kirkstone**, `meta-tegra` **kirkstone-l4t-r32.7.x**.

This branch is deliberately incompatible with the `xavier`, `orin`, and `thor`
branches. It contains no machine configs, recipes, pins, or documentation for
any other generation. See `MIGRATION.md` if you are coming from the pre-split
tree.

## Generation facts

| Item | Value |
|---|---|
| Yocto/OE release | kirkstone (poky 4.0.x line) |
| meta-tegra branch | kirkstone-l4t-r32.7.x, commit `94e3db3146dc273ec1df463426c0fcaeacc51b5f` |
| L4T | R32.7.6 (terminal release for TX1/TX2/Nano — no further upstream releases) |
| JetPack | 4.6.6 |
| Boot flow | cboot (TX1/TX2) or U-Boot (Nano family), legacy boot |
| Flash flow | legacy tegraflash package (`doflash.sh` / `dosdcard.sh`) — see "Flash" below |
| Image output | ext4 + tegraflash package (no WIC) |

## Family coverage (all TX-generation SoMs and dev kits)

| SoM | Module P/N | Dev kit / carrier | MACHINE | Flash path |
|---|---|---|---|---|
| Jetson TX1 | P2180 | P2371-2180 / P2597 dev kit | `jetson-tx1-devkit` | doflash.sh |
| Jetson TX2 | P3310 | P2771-0000 dev kit | `jetson-tx2-devkit` | doflash.sh |
| Jetson TX2 4GB | P3489-0888 | P2771 carrier | `jetson-tx2-devkit-4gb` | doflash.sh |
| Jetson TX2i | P3489 | P2771 carrier | `jetson-tx2-devkit-tx2i` | doflash.sh |
| Jetson TX2 NX | P3636 | P3509 / Nano dev kit carrier | `jetson-xavier-nx-devkit-tx2-nx` | doflash.sh |
| Jetson Nano (SD) | P3448-0000 | P3450 dev kit / P3449 carrier | `jetson-nano-devkit` | dosdcard.sh |
| Jetson Nano (eMMC) | P3448-0002 | P3449 carrier | `jetson-nano-devkit-emmc` | doflash.sh |
| Jetson Nano 2GB | P3448-0003 | P3542-0000 dev kit | `jetson-nano-2gb-devkit` | dosdcard.sh |

Notes:
- Every `MACHINE` above is a machine config shipped by meta-tegra
  kirkstone-l4t-r32.7.x at the pinned commit. This branch adds no machine
  aliases of its own.
- The TX2 NX machine name `jetson-xavier-nx-devkit-tx2-nx` is the **upstream
  meta-tegra name** for the TX2 NX machine on the R32.7.x line; the "xavier"
  substring is upstream naming, not a cross-generation dependency (documented
  in `VERIFY.md`).
- Nano 2GB carrier: the pinned BSP's device tree names the carrier
  `p3542-0000`; fix.md's "P3541" appears upstream only as the U-Boot
  defconfig name (`p3541-0000_defconfig`). Resolution recorded in `VERIFY.md`.

## Upstream pins (authoritative manifest: `PINS.md`, machine-readable: `kas/repos/*.yaml`)

| Layer | Branch | Commit |
|---|---|---|
| poky | kirkstone | `445a6223929b9a7a62b575093659e3d9e1aba982` |
| meta-openembedded | kirkstone | `ce8539c941f6fcbecaca4d16640ac105c0595589` |
| meta-tegra | kirkstone-l4t-r32.7.x | `94e3db3146dc273ec1df463426c0fcaeacc51b5f` |
| meta-swupdate | kirkstone | `f115c13978a2263fc5d89a2e3cc8bc79ce66f9a2` |
| meta-rust-bin | master | `54721fa1c7a4edaba7fb63cdbcaf0c6253c5fa3a` |
| meta-arches | tx | `b21894b76d86e64ba2133cdd637580eae303b559` |

## Build

The build is fully containerized; the host provides Docker and nothing else.

```sh
# flagship dev kit (jetson-tx1-devkit), zero arguments:
docker build -t arches-kas:latest docker/yocto
make build

# any other machine in the table above:
make build jetson-tx2-devkit
```

`make build <board>` resolves to `scripts/kas-container` (kas 4.5) running
`kas build kas/boards/<board>.yaml` in the digest-pinned container, with the
source tree, `cache/downloads`, and `cache/sstate-cache` bind-mounted and
persistent. No edits to tracked files are needed.

Build validation on this branch: kas checkout resolves all six pinned repos;
bitbake parses cleanly; a full TX1 build completed (5,777 tasks) producing
`arches-image` rootfs + `.tegraflash.tar.gz` — recorded in `VERIFY.md`.

## Flash

TX-generation flashing is **not** WIC/bmaptool-based. Build the image, then
extract the per-machine `.tegraflash.tar.gz` from
`build/tmp/deploy/images/<MACHINE>/` (or `deploy/images/<board>_<timestamp>/`)
and run `doflash.sh` (USB recovery mode) or `dosdcard.sh` (Nano SD / Nano 2GB
SD image creation). For the Nano SD-card boards, see
`meta/meta-arches/recipes-core/images/FLASH_SDCARD.md`, which `make
deploy-images` also copies alongside the bundle.

**Hardware validation status:** the TX1 image build and tegraflash package
generation are verified; physical recovery-mode flashing and boot for every
board remain untested (no target hardware in the preparation environment) —
see `VERIFY.md`.

## Validation gate

`./.claude/validate.sh quick` (seconds) or `full` (adds build + tests) must
pass before any change is claimed complete. Exit code 77 is not a pass.
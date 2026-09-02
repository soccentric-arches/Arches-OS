# Arches-OS — Orin generation branch

Arches-OS build tree for the **NVIDIA Ampere Orin generation** only:
AGX Orin, Orin NX, and Orin Nano SoMs and developer kits, on
**L4T R36.5.0 / JetPack 6.2.2**, Yocto **scarthgap**, `meta-tegra` **scarthgap**.

This branch is deliberately incompatible with the `tx`, `xavier`, and `thor`
branches. It contains no machine configs, recipes, pins, or documentation for
any other generation, and cannot be made to build for one. See `MIGRATION.md`
if you are coming from the pre-split tree.

## Generation facts

| Item | Value |
|---|---|
| Yocto/OE release | scarthgap (poky 5.0.18 line) |
| meta-tegra branch | scarthgap, commit `d2613418be82dd95733824a0839c185ec0e02f2d` |
| L4T | R36.5.0 |
| JetPack | 6.2.2 (production quality) |
| Boot flow | UEFI + extlinux (no U-Boot) |
| Flash flow | initrd-flash for internal/eMMC targets; WIC + bmaptool for SD-card media |
| Terminal status | R36.x is an active, maintained line (not terminal) |

fix.md targeted L4T R36.4.x for this branch; the actual verified pin delivers
R36.5.0, the newest production release of the same JetPack 6.2.x family. This
correction is recorded here and in `VERIFY.md`.

## Family coverage (all Orin SoMs and dev kits)

| SoM | Module P/N | Dev kit / carrier | MACHINE | Flash path |
|---|---|---|---|---|
| AGX Orin 32GB | P3701-0004 | P3737-0000 carrier / AGX Orin dev kit | `jetson-agx-orin-devkit`, `p3737-0000-p3701-0004` | initrd-flash |
| AGX Orin 64GB | P3701-0005 | P3737-0000 carrier | `jetson-agx-orin-devkit`, `p3737-0000-p3701-0005` | initrd-flash |
| AGX Orin Industrial 64GB | P3701-0008 | P3737-0000 carrier | `jetson-agx-orin-devkit-industrial` | initrd-flash |
| Orin NX 16GB | P3767-0000 | P3768 carrier; P3509-A02 Xavier NX carrier | `p3768-0000-p3767-0000`, `p3509-a02-p3767-0000` | initrd-flash |
| Orin NX 8GB | P3767-0001 | P3768 carrier | `p3768-0000-p3767-0001` | initrd-flash |
| Orin Nano 8GB (incl. Super) | P3767-0003 / P3767-0005 (dev kit SD) | P3768 dev kit carrier | `jetson-orin-nano-devkit`, `p3768-0000-p3767-0003`, `jetson-orin-nano-devkit-nvme` | SD: WIC/bmaptool; eMMC/NVMe: initrd-flash |
| Orin Nano 4GB | P3767-0004 | P3768 carrier | `p3768-0000-p3767-0004` | initrd-flash |

Notes:
- Every `MACHINE` above is a machine config shipped by meta-tegra scarthgap at
  the pinned commit (verified in `layers/meta-tegra/conf/machine/` at review
  time). This branch adds no machine aliases of its own.
- **Orin Nano Super** is the P3767-0005 dev kit module on P3768; it builds with
  `jetson-orin-nano-devkit`. The Super (boosted-power) flash configuration is
  applied at flash time (L4T `jetson-orin-nano-devkit-super.conf`), not via a
  separate MACHINE.
- The AGX Orin dev kit default machine (`jetson-agx-orin-devkit`) covers the
  P3701-0000 dev kit module and is the flashing target config for P3701-0004 /
  -0005 production modules on the dev kit carrier (per the L4T R36.5 release
  notes); the explicit `p3737-0000-p3701-000X` machines select the production
  modules directly.

## Upstream pins (authoritative manifest: `PINS.md`, machine-readable: `kas/repos/*.yaml`)

| Layer | Branch | Commit |
|---|---|---|
| poky | scarthgap | `d4576e3c081a7ee7b57d48421c4c4f491cb4defe` |
| meta-openembedded | scarthgap | `ae7dfb12245c7f9b9a353499e2688015bd4e6413` |
| meta-tegra | scarthgap | `d2613418be82dd95733824a0839c185ec0e02f2d` |
| meta-swupdate | scarthgap | `a329ea9f9ef4eeb316f2da2dba4a9c1bcb106899` |
| meta-rust-bin | master | `54721fa1c7a4edaba7fb63cdbcaf0c6253c5fa3a` |
| meta-virtualization | scarthgap | `422dcd49756aef2c780146d54ccb39477759267a` |
| meta-arches | orin | `ecb913231dbada98cadef66f487248f729f8aeb0` |

## Build

The build is fully containerized; the host provides Docker and nothing else.
No host OS requirement exists anywhere in this tree.

```sh
# flagship dev kit (jetson-agx-orin-devkit), zero arguments:
docker build -t arches-kas:latest docker/yocto
make build jetson-agx-orin-devkit

# any other machine in the table above:
make build p3768-0000-p3767-0003
```

`make build <board>` resolves to `scripts/kas-container` (kas 4.5) running
`kas build kas/boards/<board>.yaml` in the digest-pinned container, with the
source tree, `cache/downloads`, and `cache/sstate-cache` bind-mounted and
persistent. No edits to tracked files are needed for any machine. The full
artifact set (image, SDK, eSDK, OTA, deploy) is in `doc/BUILD_DEPLOY.md` and
`make help`.

The build is ~8000+ bitbake tasks (hours); it is resumable — rerunning
`make build` resumes.

## Flash

Per-machine flash procedures live in `FLASH.md`. Summary: SD-card media
(Orin Nano dev kit SD image) uses `make flash <board> DEVICE=/dev/sdX`
(bmaptool WIC write); every internal-storage target (AGX Orin family, Orin
NX/Nano eMMC, NVMe) uses the **initrd-flash** flow from the meta-tegra flash
package produced by the build.

**Hardware validation status: no board flashing/boot has been executed in
this environment.** All machines in the table are configured and expected to
build; flash and boot behavior is recorded as untested in `VERIFY.md` until a
target validates it.

## Validation gate

`./.claude/validate.sh quick` (seconds) or `full` (adds build + tests) must
pass before any change is claimed complete. Exit code 77 is not a pass.
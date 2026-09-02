# Arches-OS — Xavier generation branch

Arches-OS build tree for the **NVIDIA Volta Xavier generation** only:
AGX Xavier and Xavier NX SoMs and developer kits, on
**L4T R35.6.4 / JetPack 5.1.6**, Yocto **kirkstone**, `meta-tegra` **kirkstone**.

This branch is deliberately incompatible with the `tx`, `orin`, and `thor`
branches. It contains no machine configs, recipes, pins, or documentation for
any other generation. See `MIGRATION.md` if you are coming from the pre-split
tree.

## Generation facts

| Item | Value |
|---|---|
| Yocto/OE release | kirkstone (poky 4.0.x line) |
| meta-tegra branch | kirkstone, commit `47519b99e34475ee9e3e8840da5f1111ab7dee0f` |
| L4T | R35.6.4 (terminal release line for Xavier — JetPack 6 dropped Xavier) |
| JetPack | 5.1.6 (production quality) |
| Boot flow | UEFI + extlinux (JetPack 5 bootloader) |
| Flash flow | initrd-flash / tegraflash package from the deploy directory; SD image for Xavier NX via the flash package tooling |
| Image output | ext4 + tegraflash package (no WIC) |

## Family coverage (all Xavier SoMs and dev kits)

| SoM | Module P/N | Dev kit / carrier | MACHINE | Flash path |
|---|---|---|---|---|
| AGX Xavier 8/16/32GB (dev kit modules) | P2888-0001 / P2888-0004 | P2972-0000 dev kit | `jetson-agx-xavier-devkit` | initrd-flash / doflash.sh |
| AGX Xavier 64GB | P2888-0005 | P2972-0000 dev kit | `jetson-agx-xavier-devkit` | initrd-flash / doflash.sh |
| AGX Xavier Industrial (32GB) | P2888-0008 | P2972 carrier | `jetson-agx-xavier-industrial` | initrd-flash / doflash.sh |
| Xavier NX (SD, dev kit) | P3668-0000 | P3518-0000 dev kit | `jetson-xavier-nx-devkit` | dosdcard / flash package |
| Xavier NX (eMMC, commercial) | P3668-0001 | P3509 / P3449 carrier | `jetson-xavier-nx-devkit-emmc` | initrd-flash / doflash.sh |
| Xavier NX 16GB (eMMC, commercial) | P3668-0003 | P3509 carrier | `jetson-xavier-nx-devkit-emmc` | initrd-flash / doflash.sh |

Notes:
- Every `MACHINE` above is a machine config shipped by meta-tegra kirkstone at
  the pinned commit. This branch adds no machine aliases of its own.
- fix.md's "P3509 / P3449 carrier" rows are reachable through the upstream
  `jetson-xavier-nx-devkit-emmc` machine (the BSP flashing configuration
  covers the commercial modules on those carriers); no separate carrier
  machine exists upstream on this line — stated here rather than inventing
  one.
- P3668-0003 (Xavier NX 16GB commercial) is covered by
  `jetson-xavier-nx-devkit-emmc` per the L4T R35.6.4 documentation; it is not
  listed in fix.md's family table and is recorded here for completeness.
- The upstream `clara-agx-xavier-devkit` machine (Clara AGX, medical variant)
  exists in the pinned BSP but is outside this branch's product scope
  (not in fix.md's family table); it is not configured.

## Upstream pins (authoritative manifest: `PINS.md`, machine-readable: `kas/repos/*.yaml`)

| Layer | Branch | Commit |
|---|---|---|
| poky | kirkstone | `445a6223929b9a7a62b575093659e3d9e1aba982` |
| meta-openembedded | kirkstone | `ce8539c941f6fcbecaca4d16640ac105c0595589` |
| meta-tegra | kirkstone | `47519b99e34475ee9e3e8840da5f1111ab7dee0f` |
| meta-swupdate | kirkstone | `f115c13978a2263fc5d89a2e3cc8bc79ce66f9a2` |
| meta-rust-bin | master | `54721fa1c7a4edaba7fb63cdbcaf0c6253c5fa3a` |
| meta-arches | xavier | `93adab339d80d7edf40dec1482d1319d1678404c` |

fix.md's xavier row ("kirkstone, L4T R35.x") is matched exactly by this pin
set; the alternative upstream line (`scarthgap-l4t-r35.x`) was considered and
recorded in `VERIFY.md`.

## Build

The build is fully containerized; the host provides Docker and nothing else.

```sh
# flagship dev kit (jetson-agx-xavier-devkit), zero arguments:
docker build -t arches-kas:latest docker/yocto
make build

# any other machine in the table above:
make build jetson-xavier-nx-devkit
```

`make build <board>` resolves to `scripts/kas-container` (kas 4.5) running
`kas build kas/boards/<board>.yaml` in the digest-pinned container, with the
source tree, `cache/downloads`, and `cache/sstate-cache` bind-mounted and
persistent. No edits to tracked files are needed.

## Flash

Xavier-generation flashing is **not** WIC/bmaptool-based. See `FLASH.md`:
the build produces tegraflash packages in
`build/tmp/deploy/images/<MACHINE>/`; internal-storage targets flash with
`initrd-flash` (R35 supports initrd flashing natively) or `doflash.sh`;
Xavier NX SD media is produced by the flash package's SD-card tooling.

**Hardware validation status: no board flashing/boot has been executed in
the environment where this branch was prepared.** All machines are
configured and expected to build; flash and boot behavior is recorded as
untested in `VERIFY.md` until a target validates it.

## Validation gate

`./.claude/validate.sh quick` (seconds) or `full` (adds build + tests) must
pass before any change is claimed complete. Exit code 77 is not a pass.
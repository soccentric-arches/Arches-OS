# Arches-OS — Thor generation branch

Arches-OS build tree for the **NVIDIA Blackwell Thor generation** only:
Jetson AGX Thor T5000 and T4000, on **L4T R38.4.0 / JetPack 7.x**, OE-Core
**whinlatter**, `meta-tegra` **master-l4t-r38.4.x**.

This branch is deliberately incompatible with the `tx`, `xavier`, and `orin`
branches. L4T R38.x **does not support Orin** (NVIDIA: "Version 38.4 of
Jetson Linux does not support the Jetson Orin product family"); the Orin
machine configs that exist in the pinned meta-tegra tree are non-functional
here and are not configured, referenced, or documented on this branch.

## Generation facts

| Item | Value |
|---|---|
| OE-Core release | whinlatter (5.3), consumed as split repos (see below) |
| meta-tegra branch | master-l4t-r38.4.x, commit `83f51cb2b3d179f00feb1fbdf0fdb4a65151ae81` |
| L4T | R38.4.0 (Thor-only generation) |
| JetPack | 7.x (7.1 line; verified against NVIDIA's R38.4 GA developer guide and JetPack 7.1 announcements) |
| Boot flow | UEFI + extlinux |
| Flash flow | unified initrd-flash from the `tegraflash-tar` package — the Thor dev kit rootfs is **NVMe** (no internal storage) |
| Image output | flash package (`.tegraflash-tar`) + rootfs (ext4 / ext4.simg) |

### Why the OE-Core repos are split on this branch

The `poky` combo repository retired its `master` branch upstream and carries
no whinlatter line. This branch therefore consumes OE-Core, bitbake, and
meta-yocto as **separate pinned repositories** (whinlatter release, bitbake
2.18 — satisfying whinlatter's minimum of 2.15.2). Every other layer pins
unchanged in mechanism.

## Family coverage (all Thor SoMs and dev kits)

| SoM | Module P/N | Dev kit / carrier | MACHINE | Flash path |
|---|---|---|---|---|
| AGX Thor T5000 128GB (dev kit module) | P3834-0008 | AGX Thor dev kit (P4071-0000 carrier; NVIDIA kit P4070), NVMe | `jetson-agx-thor-devkit` | initrd-flash (NVMe) |
| AGX Thor T4000 64GB | P3834-0000 | P4071-0000 carrier, NVMe | `jetson-agx-thor-t4000` | initrd-flash (NVMe) |

Notes:
- Module P/Ns verified against the NVIDIA Jetson Linux R38.4 developer guide
  device table (T5000 128GB = P3834-0008 dev-kit module; T4000 64GB =
  commercial module) and against the pinned meta-tegra machine configs
  (`jetson-agx-thor-devkit.conf`: "P3834-0008 module in P4071-0000 carrier
  with NVMe"; `jetson-agx-thor-t4000.conf`: "P3834-0000 module in P4071-0000
  carrier with NVMe").
- Both machines boot from NVMe (`TEGRaFLASH_NO_INTERNAL_STORAGE = "1"` in the
  pinned BSP); the unified initrd-flash flow is the only flash path.
- The upstream `clara-agx-xavier-devkit` and all Orin machines exist in the
  pinned BSP tree but are outside this branch's product scope; not configured.

## Upstream pins (authoritative manifest: `PINS.md`, machine-readable: `kas/repos/*.yaml`)

| Layer | Branch | Commit |
|---|---|---|
| openembedded-core | whinlatter | `8751ec83421192fc0f8495fb95798f9eb7be77a0` |
| bitbake | 2.18 | `0ad6c1c34a5e07a5f8dd66ab248c1e7b37b69fa9` |
| meta-yocto | whinlatter | `3f2e6b6fadfa542f0fe3738375a2f9fcbd4c1f6e` |
| meta-openembedded | whinlatter | `f52f32952cb9717949f8bc3d3ccf6c4c5a59521f` |
| meta-tegra | master-l4t-r38.4.x | `83f51cb2b3d179f00feb1fbdf0fdb4a65151ae81` |
| meta-swupdate | master | `5e069ecc5c5d3567186880748a3a5480f7235dde` |
| meta-rust-bin | master | `54721fa1c7a4edaba7fb63cdbcaf0c6253c5fa3a` |
| meta-arches | thor | `60df5ddf0ede70146b38045c3629a57e3115ac5a` |

## Build

The build is fully containerized; the host provides Docker and nothing else.

```sh
# flagship dev kit (jetson-agx-thor-devkit), zero arguments:
docker build -t arches-kas:latest docker/yocto
make build

# the T4000 machine:
make build jetson-agx-thor-t4000
```

`make build <board>` resolves to `scripts/kas-container` (kas 4.5) running
`kas build kas/boards/<board>.yaml` in the digest-pinned container, with the
source tree, `cache/downloads`, and `cache/sstate-cache` bind-mounted and
persistent. No edits to tracked files are needed.

## Flash

Thor uses the **unified initrd-flash flow** (see `FLASH.md`): the build
produces a `.tegraflash-tar` package in `build/tmp/deploy/images/<MACHINE>/`;
the dev kit and T4000 targets flash to NVMe via `initrd-flash`.

**Hardware validation status: no board flashing/boot has been executed in
the environment where this branch was prepared.** The machines are
configured and expected to build; flash and boot behavior is recorded as
untested in `VERIFY.md` until a target validates it.

## Validation gate

`./.claude/validate.sh quick` (seconds) or `full` (adds build + tests) must
pass before any change is claimed complete. Exit code 77 is not a pass.
# PINS — authoritative upstream revision manifest (TX branch)

This file is the human-readable lock for every upstream layer consumed by the
`tx` branch. The machine-readable authority is `kas/repos/*.yaml` (consumed by
kas at checkout); the two are kept in sync and both list full immutable commit
SHAs. Re-cloning this branch at a given commit reproduces byte-identical layer
checkouts via `./kas-container checkout kas/boards/<board>.yaml`.

| Layer | URL | Branch | Commit (immutable) | Role |
|---|---|---|---|---|
| poky | https://git.yoctoproject.org/poky | kirkstone | `445a6223929b9a7a62b575093659e3d9e1aba982` | OE-Core, bitbake, meta-poky |
| meta-openembedded | https://github.com/openembedded/meta-openembedded | kirkstone | `ce8539c941f6fcbecaca4d16640ac105c0595589` | meta-oe, python, networking, multimedia, filesystems |
| meta-tegra | https://github.com/OE4T/meta-tegra | kirkstone-l4t-r32.7.x | `94e3db3146dc273ec1df463426c0fcaeacc51b5f` | NVIDIA BSP, L4T R32.7.6 / JetPack 4.6.6 |
| meta-swupdate | https://github.com/sbabic/meta-swupdate | kirkstone | `f115c13978a2263fc5d89a2e3cc8bc79ce66f9a2` | SWUpdate OTA framework |
| meta-rust-bin | https://github.com/rust-embedded/meta-rust-bin | master | `54721fa1c7a4edaba7fb63cdbcaf0c6253c5fa3a` | prebuilt Rust 1.85 toolchain (webconfigd MSRV) |
| meta-arches | git@github.com:soccentric-arches/meta-arches.git | tx | `b21894b76d86e64ba2133cdd637580eae303b559` | project layer — version-locked to this branch |

Container base image (build tooling, not a Yocto layer):

| Image | Digest | Note |
|---|---|---|
| ghcr.io/siemens/kas/kas | `sha256:1bf421652ed769134ec401add491ae6bc6f7b7c6f26c8b1fe12d15e318355563` | kas 4.5 tag, digest-resolved; pinned in `docker/yocto/Dockerfile` |

Rules enforced on this branch: no floating branch pins, no `:latest` base
images, no local modification of any upstream layer (all customization lives
in `meta-arches` via bbappends/config). Any pin change must update
`kas/repos/*.yaml` and this file in the same commit.
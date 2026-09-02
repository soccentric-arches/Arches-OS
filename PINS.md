# PINS — authoritative upstream revision manifest (Orin branch)

This file is the human-readable lock for every upstream layer consumed by the
`orin` branch. The machine-readable authority is `kas/repos/*.yaml` (consumed
by kas at checkout); the two are kept in sync and both list full immutable
commit SHAs. Re-cloning this branch at a given commit reproduces byte-identical
layer checkouts via `./kas-container checkout kas/boards/<board>.yaml`.

| Layer | URL | Branch | Commit (immutable) | Role |
|---|---|---|---|---|
| poky | https://git.yoctoproject.org/poky | scarthgap | `d4576e3c081a7ee7b57d48421c4c4f491cb4defe` | OE-Core, bitbake, meta-poky (yocto-5.0.18 line) |
| meta-openembedded | https://github.com/openembedded/meta-openembedded | scarthgap | `ae7dfb12245c7f9b9a353499e2688015bd4e6413` | meta-oe, python, networking, multimedia, filesystems |
| meta-tegra | https://github.com/OE4T/meta-tegra | scarthgap | `d2613418be82dd95733824a0839c185ec0e02f2d` | NVIDIA BSP, L4T R36.5.0 / JetPack 6.2.2 |
| meta-swupdate | https://github.com/sbabic/meta-swupdate | scarthgap | `a329ea9f9ef4eeb316f2da2dba4a9c1bcb106899` | SWUpdate OTA framework |
| meta-rust-bin | https://github.com/rust-embedded/meta-rust-bin | master | `54721fa1c7a4edaba7fb63cdbcaf0c6253c5fa3a` | prebuilt Rust 1.85 toolchain (webconfigd MSRV) |
| meta-virtualization | https://git.yoctoproject.org/meta-virtualization | scarthgap | `422dcd49756aef2c780146d54ccb39477759267a` | container runtime support |
| meta-arches | git@github.com:soccentric-arches/meta-arches.git | orin | `a8efd070b3fdf4d0a2835c20732dd9e0f7df36fa` | project layer — version-locked to this branch |

Container base image (build tooling, not a Yocto layer):

| Image | Digest | Note |
|---|---|---|
| ghcr.io/siemens/kas/kas | `sha256:1bf421652ed769134ec401add491ae6bc6f7b7c6f26c8b1fe12d15e318355563` | kas 4.5 tag, digest-resolved; pinned in `docker/yocto/Dockerfile` |

Rules enforced on this branch: no floating branch pins, no `:latest` base
images, no local modification of any upstream layer (all customization lives
in `meta-arches` via bbappends/config). Any pin change must update
`kas/repos/*.yaml` and this file in the same commit.
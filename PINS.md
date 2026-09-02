# PINS — authoritative upstream revision manifest (Thor branch)

This file is the human-readable lock for every upstream layer consumed by the
`thor` branch. The machine-readable authority is `kas/repos/*.yaml` (consumed
by kas at checkout); the two are kept in sync and both list full immutable
commit SHAs. Re-cloning this branch at a given commit reproduces byte-identical
layer checkouts via `./kas-container checkout kas/boards/<board>.yaml`.

Note: this branch consumes OE-Core as **split repositories** — the poky combo
repo retired its master/whinlatter line upstream.

| Layer | URL | Branch | Commit (immutable) | Role |
|---|---|---|---|---|
| openembedded-core | https://git.openembedded.org/openembedded-core | whinlatter | `8751ec83421192fc0f8495fb95798f9eb7be77a0` | OE-Core meta (whinlatter 5.3) |
| bitbake | https://git.openembedded.org/bitbake | 2.18 | `0ad6c1c34a5e07a5f8dd66ab248c1e7b37b69fa9` | BitBake 2.18.0 (≥ whinlatter min 2.15.2) |
| meta-yocto | https://git.yoctoproject.org/meta-yocto | whinlatter | `3f2e6b6fadfa542f0fe3738375a2f9fcbd4c1f6e` | meta-poky (poky distro) + meta-yocto-bsp |
| meta-openembedded | https://git.openembedded.org/meta-openembedded | whinlatter | `f52f32952cb9717949f8bc3d3ccf6c4c5a59521f` | meta-oe, python, networking, multimedia, filesystems |
| meta-tegra | https://github.com/OE4T/meta-tegra | master-l4t-r38.4.x | `83f51cb2b3d179f00feb1fbdf0fdb4a65151ae81` | NVIDIA BSP, L4T R38.4.0 / JetPack 7.x (Thor-only) |
| meta-swupdate | https://github.com/sbabic/meta-swupdate | master | `5e069ecc5c5d3567186880748a3a5480f7235dde` | SWUpdate OTA framework (whinlatter-compatible line) |
| meta-rust-bin | https://github.com/rust-embedded/meta-rust-bin | master | `54721fa1c7a4edaba7fb63cdbcaf0c6253c5fa3a` | prebuilt Rust 1.85 toolchain (webconfigd MSRV) |
| meta-arches | git@github.com:soccentric-arches/meta-arches.git | thor | `095425fa836b804f0c2328022d4cdfafdaad8c92` | project layer — version-locked to this branch |

Container base image (build tooling, not a Yocto layer):

| Image | Digest | Note |
|---|---|---|
| ghcr.io/siemens/kas/kas | `sha256:1bf421652ed769134ec401add491ae6bc6f7b7c6f26c8b1fe12d15e318355563` | kas 4.5 tag, digest-resolved; pinned in `docker/yocto/Dockerfile` |

Rules enforced on this branch: no floating branch pins, no `:latest` base
images, no local modification of any upstream layer (all customization lives
in `meta-arches` via bbappends/config). Any pin change must update
`kas/repos/*.yaml` and this file in the same commit.
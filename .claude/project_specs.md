# Arches-OS — specs

Target: NVIDIA Jetson (Tegra, L4T/JetPack).
Stack: Yocto + kas, built inside Docker.

The image build for the Jetson platform. The substrate Client, Configuration and the HAL/gRPC
middleware all run inside.

## Layout

* `meta/meta-arches` — all Arches customization. A kas-managed clone of `SiliconCentric/meta-arches`. Upstream layers are never patched.
* `kas/repos/*.yaml` — defines the 5 kas repos: poky, meta-openembedded, meta-tegra, meta-swupdate, meta-arches.
* `kas/boards/<board>.yaml` — per-board config. 11 boards.
* `layers/` — checked out by kas. Gitignored, never tracked.
* `scripts/` — all scripts, including the maintained `kas-container` copy.
* `docker/yocto/` — builds the `arches-kas:latest` image. kas release pinned to 4.5.
* `build/`, `cache/downloads/`, `cache/sstate-cache/` — host bind mounts, gitignored.

## Coupling

The dependency on the rest of the fleet is implicit, not code-level: this image provisions the
gRPC/Protobuf/libgpiod middleware (`packagegroup-arches-middleware`) that Client, Server and the
HAL's on-device pieces need at runtime, and pulls in Arches-Configuration as the `meta-webconfig`
layer. Grepping this repo for "HAL" or "STM32" will not find the coupling.

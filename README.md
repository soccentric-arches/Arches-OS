# Arches OS — NVIDIA Jetson Yocto BSP

A fully containerised Yocto/OpenEmbedded build system targeting the **NVIDIA Jetson Orin™ Nano Super Developer Kit**. Every build runs inside a Docker container via [kas](https://kas.readthedocs.io), so your host machine never needs Yocto dependencies installed.

Key features:
- **One `make` command** builds a flashable SD card image for the Jetson Orin Nano Super
- **A/B OTA updates** via SWUpdate with a built-in web UI — boot-slot switching via extlinux.conf
- **Systemd** init with DHCP Ethernet, Wi-Fi (M.2 Key E card), and Bluetooth out of the box
- **gRPC + Protobuf** (C++ runtime, compiler, and Python bindings) pre-installed
- **Persistent `/home` partition** that survives OTA updates
- **Standard and extensible SDK** generation for cross-compilation
- **Bash tab-completion** for all `make` targets

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Supported Boards](#supported-boards)
4. [Hardware Overview](#hardware-overview)
5. [Project Structure](#project-structure)
6. [Makefile Reference](#makefile-reference)
7. [KAS Configuration](#kas-configuration)
8. [Image Contents](#image-contents)
9. [Partition Layout (Jetson Orin Nano)](#partition-layout-jetson-orin-nano)
10. [OTA Updates with SWUpdate](#ota-updates-with-swupdate)
11. [SDK / Cross-Compilation](#sdk--cross-compilation)
12. [SDK Docker Images](#sdk-docker-images)
13. [First-Boot Services](#first-boot-services)
14. [Customising the Image](#customising-the-image)
15. [Bash Tab-Completion](#bash-tab-completion)
16. [Tips & Troubleshooting](#tips--troubleshooting)

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Docker | 20.10+ |
| GNU Make | 4.0+ |
| curl | any recent |
| bmaptool | for `make flash` |

No Yocto host dependencies (Python, BitBake, etc.) are required — everything runs inside the container.

---

## Quick Start

```bash
# 1. Clone the repository
git clone <this-repo> arches && cd arches

# 2. (Optional) install bash tab-completion
make completion && source ~/.bashrc

# 3. Build for Jetson Orin Nano Super (default)
make image jetson-orin-nano

# 4. Flash to SD card (insert SD card, verify device path)
make flash jetson-orin-nano DEVICE=/dev/sdX
```

The first build downloads all sources and populates the sstate cache — this takes a while. Subsequent builds reuse the shared cache and are much faster.

Insert the flashed SD card into the Jetson Orin Nano Developer Kit's microSD slot and power on. The UEFI firmware on the eMMC will detect and boot from the SD card.

---

## Supported Boards

| Board | Yocto `MACHINE` | SoC / Notes |
|-------|-----------------|-------------|
| `jetson-orin-nano` *(default)* | `jetson-orin-nano-devkit` | Orin (Cortex-A78AE), 40 TOPS AI, A/B OTA |

Additional Tegra-based boards can be added by creating a corresponding `kas/boards/<board>.yaml` with the appropriate `machine:` field from [meta-tegra](https://github.com/OE4T/meta-tegra).

---

## Hardware Overview

### NVIDIA Jetson Orin™ Nano Super Developer Kit

| Feature | Specification |
|---------|---------------|
| Module | Jetson Orin Nano (8 GB) |
| CPU | 6× Cortex-A78AE @ 1.5 GHz |
| GPU | 1024-core NVIDIA Ampere |
| AI Performance | 40 TOPS |
| Memory | 8 GB LPDDR5 |
| Storage (module) | 16 GB eMMC (UEFI firmware — not modified by this BSP) |
| Storage (boot) | microSD card (this BSP targets SD card boot) |
| Storage (expansion) | M.2 Key M NVMe SSD slot |
| Networking | 2× Gigabit Ethernet (RJ45) |
| WiFi / BT | M.2 Key E slot — requires WiFi card (e.g. Intel AX200/AX210) |
| USB | 4× USB 3.2 Type-A, 1× USB-C |
| Serial debug | UART via Micro-USB J14 (115200 8N1) |
| Camera | 2× MIPI CSI-2 (22-pin) |
| Display | DisplayPort 1.4 |

> **Note:** The Jetson Orin Nano Super stores UEFI firmware on the eMMC module. This BSP writes to the SD card only; the eMMC is never touched.

---

## Project Structure

```
arches/
├── Makefile                       # Top-level build orchestration
├── kas-container                  # kas helper script (auto-downloaded)
├── arches-make-completion.bash    # Bash tab-completion script
│
├── kas/
│   ├── common.yaml                # Shared: repos, layers, local_conf defaults
│   ├── boards/
│   │   └── jetson-orin-nano.yaml  # Jetson Orin Nano Super — machine + WKS override
│   └── repos/
│       ├── poky.yaml
│       ├── meta-openembedded.yaml
│       ├── meta-tegra.yaml        # NVIDIA Tegra BSP layer (OE4T/meta-tegra, scarthgap)
│       ├── meta-swupdate.yaml
│       └── meta-arches.yaml       # Arches project-specific layer
│
├── docker/
│   ├── yocto/                     # KAS Yocto build container (Dockerfile)
│   ├── sdk/                       # Standard SDK Docker image
│   └── esdk/                      # Extensible SDK Docker image
│
├── meta/
│   └── meta-arches/               # Arches project-specific Yocto layer
│       ├── conf/layer.conf        # Layer registration (depends: core, tegra)
│       ├── recipes-core/
│       │   ├── images/
│       │   │   └── arches-image.bb           # Main image recipe
│       │   └── arches-home-init/             # Persistent /home first-boot init
│       ├── recipes-connectivity/
│       │   └── arches-connectivity/          # systemd-networkd, wpa_supplicant
│       ├── recipes-swupdate/
│       │   └── arches-swupdate-config/       # SWUpdate daemon + extlinux slot switch
│       ├── recipes-support/
│       │   └── expand-rootfs/               # First-boot partition expansion
│       ├── swupdate/
│       │   ├── sw-description               # OTA bundle manifest (@@VERSION@@ token)
│       │   ├── pre-install.sh               # A/B slot detection
│       │   └── post-install.sh              # extlinux.conf update
│       └── wic/
│           └── sdimage-jetson-orin.wks      # A/B OTA SD card partition layout
│
├── layers/                        # Cloned by kas (not committed)
│   ├── poky/
│   ├── meta-openembedded/
│   ├── meta-tegra/                # NVIDIA Tegra BSP
│   └── meta-swupdate/
│
├── build/                         # BitBake build directory (not committed)
├── downloads/                     # Source tarballs shared across builds
└── sstate-cache/                  # Shared state cache
```

---

## Makefile Reference

### Board Selection

```bash
make image  jetson-orin-nano
make sdk    jetson-orin-nano
make esdk   jetson-orin-nano
make shell  jetson-orin-nano
make flash  jetson-orin-nano DEVICE=/dev/sdb
```

The default board is `jetson-orin-nano` when no board is specified.

### Yocto Build Targets

| Target | Description |
|--------|-------------|
| `image` | Build Yocto SD card image for `BOARD` — alias for `build` |
| `build` *(default)* | Ensure KAS container, build Yocto image, deploy to `deploy/images/` |
| `rebuild-image` | Clean sstate for `IMAGE_TARGET`, then rebuild |
| `sdk` | Build cross-toolchain SDK installer → `deploy/sdk/` (no Docker image) |
| `esdk` | Build extensible SDK installer → `deploy/esdk/` (no Docker image) |
| `shell` | Interactive kas/BitBake shell inside the build container |
| `swu` | Package a `.swu` OTA bundle from the latest `rootfs.ext4` |
| `flash` | Flash the latest `.wic.bz2` to `DEVICE` using bmaptool |

### Docker Image Targets

| Target | Description |
|--------|-------------|
| `kas-image` | Build/rebuild the KAS Yocto build container (`docker/yocto/`) |
| `ensure-image` | Build KAS image only if absent (used internally) |
| `sdk-image` | **Full chain**: `bitbake populate_sdk` → stage → `docker build` → deploy |
| `ensure-sdk-image` | Run `sdk-image` chain only when the image is absent |
| `esdk-image` | **Full chain**: `bitbake populate_sdk_ext` → stage → `docker build` → deploy |
| `ensure-esdk-image` | Run `esdk-image` chain only when the image is absent |

### Deployment Targets

| Target | Destination |
|--------|-------------|
| `deploy-images` | `deploy/images/BOARD_YYYYMMDD_HHMMSS/` |
| `deploy-sdk` | `deploy/sdk/BOARD_YYYYMMDD_HHMMSS/` |
| `deploy-esdk` | `deploy/esdk/BOARD_YYYYMMDD_HHMMSS/` |
| `deploy-swu` | `deploy/swu/BOARD_YYYYMMDD_HHMMSS/` |

### Clean Targets

| Target | Description |
|--------|-------------|
| `clean` | Remove `build/` |
| `clean-docker` | Remove all three Docker images (kas, sdk, esdk) |
| `clean-all` | Remove `build/`, `downloads/`, `sstate-cache/` |

---

## KAS Configuration

### `kas/common.yaml` — shared baseline

Defines all external layer repos (pinned to `scarthgap`) and the common `local.conf` settings:

- `INIT_MANAGER = "systemd"`
- `IMAGE_FSTYPES = "wic.bz2 wic.bmap ext4"`
- Shared `DL_DIR` / `SSTATE_DIR` paths (bind-mounted by the container)
- `CONF_VERSION = "2"` (required by Poky sanity checks)
- `LICENSE_FLAGS_ACCEPTED += " commercial"` (NVIDIA proprietary BSP components)

### `kas/boards/jetson-orin-nano.yaml` — board override

Sets `machine: jetson-orin-nano-devkit` and points to the `sdimage-jetson-orin.wks` partition layout.

**Adding a new Tegra board:**

```yaml
# kas/boards/my-jetson-board.yaml
header:
  version: 14
  includes:
    - ../common.yaml

machine: <tegra-machine-name-from-meta-tegra>
```

Then run `make build my-jetson-board`.

---

## Image Contents

The image is `arches-image` (`meta-arches/recipes-core/images/arches-image.bb`, based on `core-image-base`) with the following additions:

### Connectivity (`arches-connectivity`)
- **Ethernet** — DHCP via systemd-networkd on both GbE ports (`10-eth.network`, matching `eth*`, `en*`, `enp*`)
- **Wi-Fi** — wpa_supplicant for M.2 Key E WiFi cards (`20-wlan.network`, matching `wlan*`, `wlp*`, `wlx*`)
- **Bluetooth** — bluez5 with rfkill / iw tools (requires BT-capable combo card)
- Edit `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf` to configure SSID / PSK

### OTA (`swupdate`, `arches-swupdate-config`)
- SWUpdate daemon with Mongoose web server on **port 8080**
- A/B slot switching updates `/boot/extlinux/extlinux.conf` (UEFI boot chain)
- Boot-check service that logs the active slot on every boot
- Production mode is fail-closed: use `ARCHES_SECURE_BOOT=1`, provide
  `ARCHES_SWUPDATE_PUBLIC_KEY` in the KAS configuration, and sign bundles with
  `SWU_PRIV_KEY`; unsigned `.swu` files are rejected by `make swu`

### Bootloader, kernel, and SDK customization
- `ARCHES_EXTLINUX_APPEND` adds board or product boot arguments to the
  generated extlinux configuration
- `ARCHES_KERNEL_CONFIG_FRAGMENTS` accepts deployment-provided kernel config
  fragments in addition to the Arches hardening fragment
- Middleware, cloud/telemetry, target debugging, profiling, ptest, and SDK
  support are enabled in the shared KAS profile and flow into both SDK types
- `make sdk` and `make esdk` export development headers, debug symbols, source,
  ptest runner, gdbserver, perf, trace-cmd, and valgrind support

### gRPC + Protobuf
- `protobuf`, `protobuf-compiler`, `protobuf-lite`, `grpc`
- `python3-grpcio`, `python3-protobuf`

### Hardware Interface Tools
- **I2C**: `i2c-tools`, `python3-smbus`, `python3-smbus2`
- **SPI**: `spitools`, `python3-spidev`
- **GPIO**: `libgpiod`, `libgpiod-tools`, `python3-gpiod`
- **UART/Serial**: `picocom`, `minicom`, `python3-pyserial`
- **USB**: `usbutils`
- **PCIe/NVMe**: `pciutils`, `nvme-cli`, `sg3-utils`, `hdparm`, `mtd-utils`
- **CAN bus**: `can-utils`
- **System inspection**: `lshw`, `ethtool`, `devmem2`, `cpupower`, `sysstat`, `strace`, `v4l-utils`, `evtest`

### User Account
- Username: **`arches`** / Password: **`arches`**
- Member of the `sudo` group
- Home directory on the persistent `/home` partition (p4)

### Kernel
- Linux kernel provided by `meta-tegra` (`linux-tegra`) — NVIDIA-patched kernel for Jetson Orin

---

## Partition Layout (Jetson Orin Nano)

The WKS file (`meta-arches/wic/sdimage-jetson-orin.wks`) creates a four-partition A/B layout on the **SD card** (`/dev/mmcblk1`):

```
┌──────────────────────────────────────────────────────────────────────────┐
│  p1  /boot    256 MB   FAT32   kernel Image, DTBs, extlinux/extlinux.conf│
│  p2  /        8192 MB  ext4    rootfs-a  ← active slot                  │
│  p3  (none)   8192 MB  ext4    rootfs-b  ← standby slot                 │
│  p4  /home    512 MB*  ext4    persistent home                           │
└──────────────────────────────────────────────────────────────────────────┘
* Expanded to fill the card on first boot by arches-home-init.service
```

The Jetson eMMC (`/dev/mmcblk0`) holds UEFI firmware and is **never written** by this BSP.

---

## OTA Updates with SWUpdate

### Generating a `.swu` package

```bash
make swu                                    # version = current timestamp
make swu SWU_VERSION=1.2.3                  # explicit version string
```

Output: `build/jetson-orin-nano-<VERSION>.swu`

### Delivering the update

**Web UI (recommended):**
```
http://<device-ip>:8080
```

**CLI push:**
```bash
swupdate-client -v <device-ip> build/jetson-orin-nano-<VERSION>.swu
```

### How it works

1. **pre-install.sh** — identifies the active root slot (`/dev/mmcblk1p2` = slot-a, `/dev/mmcblk1p3` = slot-b) and creates `/dev/swupdate-inactive` pointing at the other slot.
2. The SWUpdate `raw` handler streams `rootfs.ext4.gz` directly onto the inactive partition.
3. **post-install.sh** — resolves the `PARTUUID` of the new partition, remounts `/boot` read-write, patches `root=PARTUUID=…` in `/boot/extlinux/extlinux.conf`, then restores read-only.
4. SWUpdate triggers a reboot; UEFI + extlinux boots the new slot.
5. **swupdate-bootcheck.service** — runs once after reboot, confirms the system is healthy, logs the active slot.

---

## SDK / Cross-Compilation

### Standard SDK

```bash
make sdk jetson-orin-nano
# Installer: deploy/sdk/jetson-orin-nano_YYYYMMDD_HHMMSS/
```

```bash
./poky-glibc-x86_64-*.sh -d ~/arches-sdk
source ~/arches-sdk/environment-setup-*
aarch64-poky-linux-gcc --version
```

### Extensible SDK (eSDK)

```bash
make esdk jetson-orin-nano
# Installer: deploy/esdk/jetson-orin-nano_YYYYMMDD_HHMMSS/
```

```bash
devtool add my-recipe ~/src/my-project
```

---

## SDK Docker Images

### SDK image

```bash
make sdk-image jetson-orin-nano
docker run --rm -it arches-sdk:latest
# source /opt/poky/sdk/environment-setup-*
```

### eSDK image

```bash
make esdk-image jetson-orin-nano
docker run --rm -it arches-esdk:latest
# source /opt/poky/esdk/environment-setup-*
```

---

## First-Boot Services

### `arches-home-init.service`
The persistent `/home` partition (p4) is empty at flash time. On first boot this service creates `/home/arches`, populates it from `/etc/skel`, expands p4 to fill the available SD card space, and marks itself done.

### `expand-rootfs.service`
Available for single-partition (non-A/B) deployments to grow the root filesystem. In the default A/B layout the rootfs slots are fixed-size.

---

## Customising the Image

### Adding packages

Edit `meta/meta-arches/recipes-core/images/arches-image.bb`:

```bitbake
IMAGE_INSTALL:append = " my-package another-package"
```

Then:
```bash
make rebuild-image jetson-orin-nano
```

### Adding a new recipe

Place it under `meta/meta-arches/recipes-<category>/<name>/<name>.bb`. The layer's `conf/layer.conf` auto-discovers all `recipes-*/*/*.bb` files.

### Configuring Wi-Fi credentials

On the target:
```
/etc/wpa_supplicant/wpa_supplicant-wlan0.conf
```

Or bake into the image at `meta/meta-arches/recipes-connectivity/arches-connectivity/files/wpa_supplicant-wlan0.conf`.

### Pinning or updating the kernel

The Jetson kernel (`linux-tegra`) is provided by `meta-tegra`. To pin to a specific version, add a bbappend in `meta/meta-arches/recipes-kernel/` or update `commit:` in `kas/repos/meta-tegra.yaml`.

---

## Bash Tab-Completion

```bash
make completion   # appends source line to ~/.bashrc
source ~/.bashrc
```

---

## Tips & Troubleshooting

### First-boot sequence

1. UEFI (eMMC) → scans SD card (`/dev/mmcblk1`) for `/boot/extlinux/extlinux.conf`
2. Kernel boots from `/dev/mmcblk1p2` (rootfs-a)
3. `arches-home-init.service` creates `/home/arches` and expands p4
4. Login: `arches` / `arches`

### Serial console (UART debug)

Connect Micro-USB to J14 on the carrier board:
```
/dev/ttyUSB0   115200 8N1
```

### Interactive BitBake shell

```bash
make shell jetson-orin-nano
# Inside:
bitbake arches-image
bitbake -c devshell my-recipe
bitbake-layers show-layers
```

### Inspecting build logs

```bash
cat build/tmp/work/<arch>/<recipe>/<version>/temp/log.do_<task>.*
```

### Docker images are stale

```bash
make kas-image                           # force-rebuild KAS container
make sdk-image jetson-orin-nano          # rebuild SDK Docker image
make clean-docker                        # remove kas + sdk + esdk images
```

### Freeing disk space

```bash
make clean        # removes build/ (~50–100 GB)
make clean-all    # also removes downloads/ and sstate-cache/
```

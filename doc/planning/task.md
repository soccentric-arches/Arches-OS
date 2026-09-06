# Arches-OS Jetson Hardware Enablement Review

**Board/SoC:** NVIDIA Jetson AGX Orin (primary) / Jetson Orin Nano (secondary) — Ampere-architecture SoC with a 12-core Cortex-A78AE CPU cluster, 2048-core Ampere GPU with 64 tensor cores (AGX Orin 64GB), 2x NVDLA (Deep Learning Accelerator) engines, a PVA (Programmable Vision Accelerator), dedicated NVENC/NVDEC video codec blocks, and Jetson Linux (L4T) R36.5.0 / JetPack 6.2.2.

**Current `MACHINE` targets (from `kas/boards/*.yaml`):**
- `jetson-agx-orin-devkit` — primary, default in `build/conf/local.conf` (`MACHINE ??= "jetson-agx-orin-devkit"`)
- `jetson-orin-nano-devkit`, `jetson-orin-nano-devkit-nvme`, `jetson-agx-orin-devkit-industrial` — secondary devkit variants
- `p3768-0000-p3767-000{0,1,3,4}`, `p3737-0000-p3701-000{4,5}`, `p3509-a02-p3767-0000` — production Orin NX/Nano module+carrier combos

This is a planning document only. **No code, recipes, or configs were changed while producing it.**

---

## Current State (vanilla gaps)

**What's already wired up:**
- Base BSP via `meta-tegra` (kernel `linux-jammy-nvidia-tegra`, UEFI/`l4t-launcher-extlinux` boot, device-tree, kernel config fragments through `arches.inc`)
- A/B OTA via SWUpdate (`arches-swupdate-config`, `arches-rauc-shim`, per-board `.wks` partition layouts under `meta/meta-arches/wic/`)
- Networking: Ethernet DHCP + WiFi + Bluetooth (`arches-connectivity`), WireGuard, hostapd/dnsmasq AP mode, PTP/GPS time-sync (`arches-timesync`)
- gRPC/Protobuf middleware (`arches-hal`, `packagegroup-arches-middleware`)
- Baseline hardware I/O tooling: `i2c-tools`, `spitools`/`python3-spidev`, `libgpiod`, `picocom`/`minicom`, `usbutils`, `pciutils`/`nvme-cli`/`sg3-utils`, `can-utils`
- WebConfig on-device UI (`packagegroup-arches-webconfig`) covering polkit, WireGuard, AP mode, nftables, mmc-utils, CAN, PTP/GPS, RAUC-CLI-compatible slot status
- Generic diagnostics: `lshw`, `ethtool`, `devmem2`, `cpupower`, `watchdog`, `sysstat`, `iotop`, `strace`, `v4l-utils`, `evtest`
- Kernel config fragments for WireGuard, USB-ACM (STM32 companion MCU), PPS (GPS), CAN-FD, plus generic hardening/tracing (`arches-security.cfg`)
- Domain image variants (`arches-image-{robotics,drones-uav,...}`) install plain `opencv` + stock `gstreamer1.0-plugins-{base,good,bad}` — **no NVIDIA hardware acceleration**

**Confirmed available in `layers/meta-tegra` but NOT referenced anywhere in `meta/meta-arches` (verified by `grep -ril` across the layer — zero hits outside boilerplate license-rule matches):**
- Full CUDA 12.6 toolkit (`recipes-devtools/cuda/*`: `cuda-toolkit`, `cuda-driver`, `cuda-cudart`, `cuda-nvcc`, `cuda-gdb`, `cuda-nvprof`, etc.)
- cuDNN (`recipes-devtools/cudnn/`)
- TensorRT 10.3 (`recipes-devtools/gie/tensorrt-{core,trtexec,plugins,samples}`, `external/meta-python/.../python3-tensorrt`)
- VPI (Vision Programming Interface, `recipes-devtools/vpi/libnvvpi3`) and CUPVA / PVA SDK (`recipes-devtools/cupva/pva-sdk`)
- DLA compiler + runtime (`tegra-libraries-dla-compiler`, `libcudla`)
- NVIDIA-accelerated GStreamer plugin set (`recipes-multimedia/gstreamer/gstreamer1.0-plugins-nv{vidconv,v4l2camerasrc,arguscamerasrc,jpeg,eglgles,compositor,tee,videosinks,drmvideosink,ipcpipeline}`) — this is the actual NVENC/NVDEC/ISP hardware path; the stock `gstreamer1.0-plugins-good/bad` the domain images use today is software-only
- `libargus`/`argus-samples` (camera pipeline) and `tegra-argus-daemon` (`nvargus-daemon`)
- `tegra-nvfancontrol` (PWM fan control) and `tegra-nvpower`/`tegra-nvpmodel` (power-mode / `nvpmodel` tooling)
- `optee-os`, `optee-client`, `optee-test` (secure boot / Trusted Execution Environment)
- `libnvidia-container`, `nvidia-container-toolkit`, `nvidia-docker` (`external/virtualization-layer/recipes-containers/`) plus `docker-moby` bbappend
- No `jetson_clocks` or `tegrastats` recipe was found by name — these ship as part of `nvidia-l4t-tools`/BSP binary packages already pulled by the kernel/BSP recipes, not as separate meta-tegra recipes; needs a runtime check on target once one recipe pulls the L4T tools package to confirm command availability.

**Net finding:** the BSP layer already contains essentially the entire Jetson AI/vision/container stack — none of it is currently opted into any `arches-image*` or packagegroup. This is a "flip the switches" gap, not a "write new recipes from scratch" gap, except where noted below (secure boot key provisioning, OTA/bootloader redundancy specifics, and any genuinely new Arches-side glue).

---

## Features Checklist

### AI / GPU Compute
- [ ] CUDA 12.6 runtime + toolkit on target — `cuda-cudart`, `cuda-toolkit`/`cuda-compiler`/`cuda-nvcc` (dev images), `cuda-libraries` (runtime images); provided as-is by `meta-tegra/recipes-devtools/cuda/*`, currently uninstalled
- [ ] cuDNN — `meta-tegra/recipes-devtools/cudnn/`; required by any DNN inference workload beyond TensorRT-only pipelines
- [ ] TensorRT 10.3 (core + `trtexec` + plugins, Python bindings) — `meta-tegra/recipes-devtools/gie/tensorrt-*` and `external/meta-python/.../python3-tensorrt`; the standard inference-optimization path for IV&V AI workloads
- [ ] DLA (Deep Learning Accelerator, 2x engines) enablement — `tegra-libraries-dla-compiler`, `libcudla`; offloads INT8/FP16 inference from the GPU, matters for power-constrained continuous inference
- [ ] PVA (Programmable Vision Accelerator) + VPI — `tegra-libraries-pva`, `cupva`/`pva-sdk`, `libnvvpi3`; hardware-accelerated classical CV (stereo, optical flow, feature tracking) offloaded from CPU/GPU
- [ ] `packagegroup-arches-ai` (new, Arches-side) — a packagegroup analogous to the existing `packagegroup-arches-{middleware,cloud,debug,sdk}` pattern, gated by a new `ARCHES_AI_COMPUTE` flag in `arches.inc`/`kas/common.yaml`, so AI stack size is opt-in per board/product profile the same way middleware/cloud/debug already are

### Camera / Video / Codec
- [ ] Hardware-accelerated GStreamer plugin set (`gstreamer1.0-plugins-nvvidconv`, `-nvv4l2camerasrc`, `-nvarguscamerasrc`, `-nvjpeg`, `-nveglgles`, `-nvcompositor`, `-nvvideosinks`, `-nvdrmvideosink`) — replaces/augments the current plain `gstreamer1.0-plugins-{base,good,bad}` used in `arches-image-robotics.bb` / `arches-image-drones-uav.bb`, which get no NVENC/NVDEC/ISP acceleration today
- [ ] `libargus` + `argus-samples` + `tegra-argus-daemon` (`nvargus-daemon` service) — the actual MIPI CSI-2 camera capture stack (up to 8x4K on AGX Orin); required for any camera pipeline beyond raw V4L2
- [ ] `libv4l2-nvvidconv-wrapper` — bridges plain V4L2 apps to the hardware `nvvidconv` scaler/colorspace-converter path
- [ ] NVENC/NVDEC exposure confirmation — verify `gstreamer1.0-plugins-nvvideo4linux2` (nvv4l2decoder/encoder elements) is actually pulled by any image; currently absent from all `arches-image*` recipes
- [ ] DisplayPort output validation on target — no explicit gap found in recipes (comes via kernel/DRM + BSP), but not exercised by any current image; worth a smoke-test checklist item, not necessarily a new recipe

### Connectivity
- [ ] PCIe Gen4 x8 (AGX) / NVMe M.2 already covered by `pciutils`/`nvme-cli` in `arches-image.bb` — no gap; note only, not an action item
- [ ] 10GbE — no explicit gap identified in recipes (driver comes from kernel/BSP); confirm on hardware that AGX Orin's 10GbE interface is not lost by the current `arches-connectivity.cfg` kernel fragment set, since that fragment only adds WireGuard/USB-ACM/PPS/CAN and doesn't touch NIC drivers
- [ ] USB 3.2 — covered by `usbutils`; no gap
- [ ] CAN bus — kernel config (`CONFIG_CAN*`, CAN-FD) and `can-utils` already present; no gap

### Storage / Boot
- [ ] eMMC/NVMe on-module storage tooling — `mmc-utils`/`nvme-cli`/`hdparm` already present; no gap
- [ ] Confirm `jetson_clocks` and `tegrastats` binaries are actually delivered to the rootfs — neither appears as a discrete meta-tegra recipe; they likely ship inside an `nvidia-l4t-tools`-equivalent binary package already depended on by the BSP. Needs a build-time verification step (not a recipe to write, but a checklist item to confirm before assuming they're present)
- [ ] Secure Boot / OP-TEE integration — `optee-os`, `optee-client`, `optee-test`, `standalone-mm-optee-tegra` all exist in `meta-tegra` and are referenced only via a bbappend stub (`recipes-bsp/uefi/standalone-mm-optee-tegra_36.5.0.bbappend`); `ARCHES_SECURE_BOOT` flag exists in `kas/common.yaml`/`arches.inc` and gates SWUpdate key provisioning in `arches-image.bb`, but the OP-TEE/TA (trusted application) side of secure boot isn't wired to that flag — worth confirming whether `ARCHES_SECURE_BOOT=1` currently does anything beyond installing a SWUpdate public key

### GPIO / Sensors / CAN
- [ ] I2C/SPI/UART/GPIO — `i2c-tools`, `spitools`, `libgpiod`, `picocom`/`minicom`, `python3-{smbus,smbus2,spidev,gpiod,periphery,pyserial}` already present across `arches-image.bb`; no gap
- [ ] CAN bus tooling — `can-utils` present, kernel CAN-FD fragment present; no gap

### Power / Thermal
- [ ] `nvpmodel` power-mode tooling (MAXN vs. power-capped profiles) — `tegra-nvpower`/`tegra-nvpmodel` exist in `meta-tegra/recipes-bsp/tegra-binaries/` but are not installed by any `arches-image*` recipe; needed so deployed units can switch power profiles instead of being locked to whatever the BSP default is
- [ ] `nvfancontrol` PWM fan control daemon — `tegra-nvfancontrol` (with its own systemd service/init script) exists in meta-tegra, not installed anywhere in `meta-arches`; without it the fan runs open-loop / BSP default rather than the closed-loop thermal profile NVIDIA ships
- [ ] `jetson_clocks` max-performance helper — see Storage/Boot item above re: confirming delivery; if absent, would need to be pulled in via whatever L4T tools package provides it

### Security
- [ ] OP-TEE Trusted Execution Environment wiring — see Storage/Boot OP-TEE item; currently only a bbappend stub, not confirmed end-to-end with `ARCHES_SECURE_BOOT`
- [ ] Kernel hardening fragment (`arches-security.cfg`) already covers module signing, stack protector, `dmesg` restriction — no gap, note only
- [ ] SWUpdate image signing already gated by `ARCHES_SECURE_BOOT` + `ARCHES_SWUPDATE_PUBLIC_KEY` in `arches-image.bb` — no gap, note only

### Containers / Deployment
- [ ] `nvidia-container-toolkit` + `libnvidia-container` — exist in `meta-tegra/external/virtualization-layer/recipes-containers/`, not installed by any `arches-image*` recipe; this is the piece that lets a container (Docker/Podman) get GPU passthrough, which is the standard way IV&V teams deploy swappable AI inference workloads onto a Jetson fleet without rebuilding the base OS image
- [ ] `docker` (via `docker-moby` bbappend in the same `virtualization-layer`) or `nvidia-docker` convenience wrapper — same directory, same gap; note the `nvidia-docker` package is the older-style wrapper, `nvidia-container-toolkit` is the modern `--gpus` / CDI-based path — worth deciding which one Arches standardizes on rather than shipping both
- [ ] A new `packagegroup-arches-containers` (or fold into a broader `packagegroup-arches-ai`) gated by its own `ARCHES_*` flag, following the existing packagegroup + `bb.utils.contains` pattern in `arches-image.bb`/`arches.inc`

### Debug / Diagnostics
- [ ] `tegrastats` (NVIDIA's `jtop`/`htop`-equivalent live SoC utilization tool: GPU/CPU/DLA/PVA/memory/power rails) — see Storage/Boot note; needs confirmation it's actually present since `packagegroup-arches-debug` currently only has generic tools (`gdb`, `perf`, `strace`, `ltrace`, `valgrind`, `lsof`, `sysstat`)
- [ ] `jtop` (community `jetson-stats` Python package) as a friendlier alternative/companion to raw `tegrastats` — not present in meta-tegra (it's a PyPI package, would need a Python recipe or `python3-pip`-based install path); worth a decision on whether to recipe it or rely on raw `tegrastats`
- [ ] JTAG/debug UART — hardware-level, no OS-side recipe gap identified; note only for hardware bring-up documentation, not a Yocto action item
- [ ] GPU/CUDA-aware debugging — `cuda-gdb` exists in `meta-tegra/recipes-devtools/cuda/` (see AI/GPU Compute section) but is also relevant here for a `packagegroup-arches-debug` addition once CUDA is enabled

### OTA / Update
- [ ] Current OTA path is SWUpdate-based A/B (`arches-swupdate-config`, per-board `.wks` A/B partition layout, `arches-rauc-shim` for RAUC-CLI compatibility) — this is intentionally NOT the Jetson-native redundancy scheme (NVIDIA's own A/B rootfs + bootloader redundancy via `nv_update_engine`/`l4t-launcher`); confirm this is a deliberate architectural choice (SWUpdate managing rootfs A/B independently of NVIDIA's own boot-slot redundancy) rather than an oversight, since running two independent redundancy mechanisms on the same boot chain can be a source of subtle failure modes worth documenting explicitly
- [ ] `l4t-launcher-extlinux` bbappend exists (`meta/meta-arches/recipes-bsp/uefi/l4t-launcher-extlinux.bbappend`) — confirm its contents don't conflict with the SWUpdate-managed extlinux config that `ARCHES_EXTLINUX_APPEND` in `arches.inc` also touches
- [ ] Bootloader/firmware update path (UEFI/edk2, `edk2-firmware-tegra-rcmboot` bbappend present) — confirm whether SWUpdate's OTA payload includes bootloader/firmware updates or only rootfs, since a rootfs-only OTA scheme won't patch BSP/bootloader-level CVEs

---

## Summary for planning

The highest-leverage next step is **not** new Yocto engineering — it's auditing which of the already-vendored `meta-tegra` capabilities (CUDA/TensorRT/DLA/PVA, NVIDIA GStreamer plugins, `nvidia-container-toolkit`, `nvpmodel`/`nvfancontrol`) should be promoted into new `packagegroup-arches-*` groups and gated behind new `ARCHES_*` flags in `arches.inc`, following the exact pattern already established by `packagegroup-arches-{middleware,cloud,debug,sdk}`. The only areas that look like they need genuinely new investigation (not just flipping a switch) are: (1) confirming `jetson_clocks`/`tegrastats` delivery, (2) completing the OP-TEE/secure-boot wiring beyond the SWUpdate key step, and (3) reconciling the SWUpdate-managed A/B scheme against Jetson's own native boot-redundancy mechanism.

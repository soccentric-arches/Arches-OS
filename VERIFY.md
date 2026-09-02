# Xavier branch — verification record

## Verified against sources

- All six pins are full 40-char commit SHAs, resolved from the actual
  upstream remotes (`git ls-remote` / fetched refs), not from fix.md:
  - poky kirkstone `445a6223929b9a7a62b575093659e3d9e1aba982`
  - meta-openembedded kirkstone `ce8539c941f6fcbecaca4d16640ac105c0595589`
  - meta-tegra kirkstone `47519b99e34475ee9e3e8840da5f1111ab7dee0f`
  - meta-swupdate kirkstone `f115c13978a2263fc5d89a2e3cc8bc79ce66f9a2`
  - meta-rust-bin `54721fa1c7a4edaba7fb63cdbcaf0c6253c5fa3a`
  - meta-arches xavier `93adab339d80d7edf40dec1482d1319d1678404c`
- meta-tegra kirkstone @ the pin carries **L4T R35.6.4** (all
  `tegra-binaries`/UEFI recipes versioned `35.6.4` in the checkout) =
  **JetPack 5.1.6** (verified against NVIDIA's Jetson Linux 35.6.4 release
  page and JetPack 5.1.6 page — production quality, supports AGX Xavier and
  Xavier NX production modules and dev kits).
- Machine inventory read from the pinned branch:
  `jetson-agx-xavier-devkit`, `jetson-agx-xavier-industrial`,
  `jetson-xavier-nx-devkit`, `jetson-xavier-nx-devkit-emmc` all exist as
  machine configs (verified in `layers/meta-tegra/conf/machine/`).
- Module P/Ns verified against the L4T R35.6.4 developer guide device table:
  AGX Xavier P2888-0001/-0004 (dev kit), -0005 (64GB), -0008 (Industrial
  32GB, kit P2972-0000); Xavier NX P3668-0000 (dev kit SD), P3668-0001
  (commercial eMMC), P3668-0003 (16GB commercial).
- Kernel recipe on the pinned branch is `linux-tegra_5.10.bb`; the
  meta-arches append targets `linux-tegra_%.bbappend` accordingly.
- EDK2 recipes on the pinned branch: `edk2-firmware-tegra_35.6.4.bb`,
  `standalone-mm-optee-tegra_35.6.4.bb`, `l4t-launcher-extlinux.bb`; the
  meta-arches appends match (rcmboot variant absent on R35 — append
  dropped).
- fix.md's xavier row (kirkstone / L4T R35.6.x / JetPack 5.1.x) is matched:
  35.6.4 / JetPack 5.1.6, the newest production point release of that line.
- kas 4.5 checkout resolves all six pinned repos (validated).

## Documented deviations / decisions

- fix.md lists the Xavier NX eMMC carrier as "P3509 / P3449". Upstream has
  no separate P3509 machine on this branch; the commercial modules are
  reachable through `jetson-xavier-nx-devkit-emmc`. Documented in the README
  rather than inventing a machine name.
- fix.md's family table omits P3668-0003 (Xavier NX 16GB commercial);
  covered by `jetson-xavier-nx-devkit-emmc` and noted in the README.
- fix.md says "AGX Xavier Industrial — P2972 carrier": the pinned BSP
  exposes `jetson-agx-xavier-industrial` directly; used as-is.
- The upstream `clara-agx-xavier-devkit` machine exists in the pinned BSP
  but is outside fix.md's family table (Clara is a medical-vertical
  variant); not configured on this branch.
- fix.md's alternative Xavier line `scarthgap-l4t-r35.x` exists upstream;
  fix.md's explicit choice of `kirkstone` was followed so the Xavier branch
  shares the OE release with the TX line. Switching to the scarthgap-based
  R35 line would be a pin-only change if ever wanted.
- The EDK2 GCC-LTO `apply_tools_def_updates` workaround was retargeted from
  `_36.5.0` to `_35.6.4` unchanged. Whether R35.6.4's EDK2 build exhibits
  the same LTO/GenFw incompatibility was **not** verified by a build; the
  override is a no-op-safe sed pass but its necessity is unconfirmed.

## Cannot be verified in this environment (no target hardware; no full build run)

- **No board has been flashed or booted.** All flash procedures in
  `FLASH.md` follow the pinned meta-tegra docs and generated artifact names
  but are untested against hardware.
- **No full image build was executed for this branch.** kas checkout +
  config validation passed; a full bitbake run (hours) remains the
  operator's validation step. The kirkstone toolchain itself is proven by
  the tx branch's completed build, but the Xavier BSP download and compile
  steps have not been exercised.
- SWUpdate carried-forward scripts' slot/rollback behavior on R35 (nvbootctrl
  A/B on Xavier) is unverified.
- Xavier NX SD first-boot QSPI update requirement (documented by NVIDIA for
  modules never running JetPack 5.x) is documented but not testable here.
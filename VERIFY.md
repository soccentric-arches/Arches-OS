# Thor branch — verification record

## Verified against sources

- All pins are full 40-char commit SHAs resolved from the actual upstream
  remotes (`git ls-remote`), not from fix.md:
  - openembedded-core whinlatter `8751ec83421192fc0f8495fb95798f9eb7be77a0`
  - bitbake 2.18 `0ad6c1c34a5e07a5f8dd66ab248c1e7b37b69fa9` (2.18.0 ≥ the
    whinlatter `BB_MIN_VERSION` 2.15.2, read from oe-core's sanity.conf)
  - meta-yocto whinlatter `3f2e6b6fadfa542f0fe3738375a2f9fcbd4c1f6e`
  - meta-openembedded whinlatter `f52f32952cb9717949f8bc3d3ccf6c4c5a59521f`
    (declares walnascar+whinlatter compat)
  - meta-tegra master-l4t-r38.4.x `83f51cb2b3d179f00feb1fbdf0fdb4a65151ae81`
    (declares `whinlatter wrynose` compat)
  - meta-swupdate master `5e069ecc5c5d3567186880748a3a5480f7235dde`
    (declares whinlatter+wrynose compat; no whinlatter branch exists)
  - meta-rust-bin `54721fa1c7a4edaba7fb63cdbcaf0c6253c5fa3a` (declares
    whinlatter compat)
  - meta-arches thor `095425fa836b804f0c2328022d4cdfafdaad8c92` (pushed)
- meta-tegra master-l4t-r38.4.x @ the pin carries **L4T R38.4.0** (all
  `tegra-binaries` recipes versioned `38.4.0`).
- Thor machines read from the pinned branch: `jetson-agx-thor-devkit`
  ("P3834-0008 module in P4071-0000 carrier with NVMe"),
  `jetson-agx-thor-t4000` ("P3834-0000 module in P4071-0000 carrier with
  NVMe"). Module names verified against the NVIDIA Jetson Linux R38.4
  developer guide device table: **T5000 128GB = P3834-0008** (dev-kit
  module), **T4000 64GB = P3834-0000** (commercial). The dev kit is NVMe-only
  (`TEGRaFLASH_NO_INTERNAL_STORAGE = 1`), so initrd-flash is the flash path
  per the meta-tegra flashing matrix.
- L4T R38.x Thor-only status verified against NVIDIA ("Version 38.4 of
  Jetson Linux does not support the Jetson Orin product family"); the Orin
  machine configs in the pinned BSP are therefore out of scope here and are
  not configured anywhere in this branch.
- Kernel recipe on the pinned branch is `linux-noble-nvidia-tegra_6.8.bb`;
  the meta-arches append targets `linux-noble-nvidia-tegra_%.bbappend`.
- R38 UEFI recipes: `edk2-firmware-tegra-rcmboot_38.4.0.bb`,
  `edk2-nvidia-standalone-mm_38.4.0.bb` (renamed upstream from
  `standalone-mm-optee-tegra`), `l4t-launcher-extlinux.bb`; the meta-arches
  appends match.
- Flash image type on the pinned branch is `tegraflash-tar`
  (`classes-recipe/image_types_tegra.bbclass`), read directly.
- fix.md §5.1 thor row said "master-line Thor branch (R38.x/R39.x)":
  upstream offers `master-l4t-r38.2.x` and `master-l4t-r38.4.x`; the newer
  R38.4.x line was chosen. No R39 branch exists upstream (verified by
  `git ls-remote`), so fix.md's R39 alternative was moot.

## Documented decisions

- **OE series choice:** meta-tegra declares `whinlatter wrynose`. poky (the
  combo repo) retired its master branch upstream and has no
  whinlatter/wrynose branch or final whinlatter tag — only 5.3_M2 milestones.
  This branch therefore consumes the **split repositories** (oe-core +
  bitbake + meta-yocto) at whinlatter, which is what upstream's retirement
  notice directs. wrynose was rejected because it has no poky/meta-yocto
  counterpart at all.
- The EDK2 GCC-LTO `apply_tools_def_updates` workaround was retargeted to
  both R38.4.0 EDK2 recipes. Whether R38's EDK2 exhibits the same LTO/GenFw
  incompatibility was **not** verified by a build; the override is
  no-op-safe but its necessity is unconfirmed.

## Cannot be verified in this environment (no target hardware; no full build run)

- **No board has been flashed or booted.** The initrd-flash procedure follows
  the pinned meta-tegra docs but is untested against hardware.
- **No full image build was executed for this branch.** kas checkout +
  config validation pass; a full bitbake run (hours, ~8000+ tasks on the
  other branches) remains the operator's validation step. The
  whinlatter-era OE-Core + split-repo layout has not been exercised by a
  real build in this repository yet.
- SWUpdate carried-forward scripts' A/B slot behavior on R38 Thor is
  unverified.
- Whether every package in the Arches packagegroups has a whinlatter-era
  recipe (e.g. newer meta-openembedded layer renames) is not verified until
  a parse/build runs; a focused `bitbake -p` parse is the first validation
  step on real hardware-infrastructure.
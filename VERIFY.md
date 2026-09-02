# Orin branch — verification record

## Build validation (2026-09-02)

- Full build of `arches-image` for `jetson-agx-orin-devkit` executed in the
  pinned container: **8,732 tasks, all succeeded** — artifacts produced
  (`.rootfs.ext4`, `.rootfs.wic.bz2` + `.bmap`, `.rootfs.tegraflash.tar.gz`,
  manifest, SPDX).
- First pass exposed 9 QA errors (nonzero bitbake exit despite all tasks
  succeeding): allarch packagegroups depending on dynamically-renamed package
  names (paho-mqtt-cpp, protobuf family, libgpiod). Root cause:
  packagegroup.bbclass snapshots PACKAGE_ARCH at parse time; the recipes set
  MACHINE_ARCH after the inherit. Fixed in meta-arches@orin `a8efd07…` by
  setting PACKAGE_ARCH before the inherit; rebuild clean.
- Benign parse-time advisory (pre-existing, carried forward):
  meta-virtualization included without `virtualization` in DISTRO_FEATURES.

## Verified against sources

- All seven pins in `kas/repos/*.yaml` are full 40-char commit SHAs, read from
  the local layer checkouts at the exact revisions (not invented).
- meta-tegra `scarthgap` @ `d2613418be82dd95733824a0839c185ec0e02f2d` carries
  **L4T R36.5.0** — read from the versioned `tegra-binaries*36.5.0` recipes in
  the checkout.
- **Jetson Linux 36.5 = JetPack 6.2.2, production quality**, supporting all
  Orin production modules and both Orin dev kits — NVIDIA Jetson Linux R36.5
  release page and release notes (RN_10698-r36.5.0).
- fix.md §5.1 targeted L4T R36.4.x for this branch; the actual verified pin
  delivers R36.5.0 — same JetPack 6.2.x family, newer point release.
  **Documented correction**, not a silent substitution.
- All ten `MACHINE` values exist as machine configs in
  `layers/meta-tegra/conf/machine/` at the pin, and map 1:1 to the ten
  `kas/boards/*.yaml` files.
- Module P/N mapping (P3701-0004/-0005/-0008, P3767-0000/-0001/-0003/-0004/
  -0005, carriers P3737-0000/P3768-0000/P3509-A02) — L4T R36.5 release notes
  flashing-configuration section.
- Upstream meta-tegra branch inventory (for §5.1 resolution): `git ls-remote`
  shows `master-l4t-r38.2.x` and `master-l4t-r38.4.x` for Thor and
  `scarthgap-l4t-r35.x` as the Xavier alternative; **no R39 branch exists**.
- Build container digest `sha256:1bf42165…` resolved from
  `ghcr.io/siemens/kas/kas:4.5` via `docker buildx imagetools inspect` on the
  review date; matches the digest pinned on the `tx` branch.
- Build evidence for the shared tooling: the `tx` branch `VERIFY.md` records a
  completed kas checkout, clean bitbake parse, and a full TX1 image build with
  the same kas/kas-container plumbing this branch uses.

## Cannot be verified in this environment (no target hardware attached)

- **No board has been flashed or booted.** All flash procedures in `FLASH.md`
  follow the pinned meta-tegra documentation and generated artifact names but
  are untested against hardware.
- **No full image build was executed in this session** for the orin branch
  (the build is hours-long; `build/` retains evidence of earlier scarthgap
  activity, not a validation of the current pin set). The quick gate and kas
  checkout validate composition; a full build remains the operator's step.
- Orin Nano **Super** mode behavior (P3767-0005): build uses
  `jetson-orin-nano-devkit`; the Super flash configuration is a flash-time
  concern per L4T release notes. Untested on hardware.
- **SWUpdate slot/rollback behavior on A/B Orin layout** — carried forward
  from the pre-split tree unchanged; install + rollback on a live target is
  unverified.
- `p3509-a02-p3767-0000` (Orin NX 16GB on the P3509-A02 Xavier NX carrier):
  machine exists upstream and is pinned, but no carrier board was available
  to verify the boot media/UART assumptions beyond upstream documentation.
- meta-arches@orin content completeness against fix.md §6.1: distro config is
  policy-in-kas (poky + `local_conf_header`), not a named Arches distro. This
  matches the pre-split tree and §12's "do not restructure meta-arches";
  flagged in case a named distro is wanted later.
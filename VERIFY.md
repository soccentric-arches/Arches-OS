# TX Verification Record

Verified for the TX branch:

- Yocto kirkstone commit `445a6223929b9a7a62b575093659e3d9e1aba982`.
- meta-openembedded kirkstone commit `ce8539c941f6fcbecaca4d16640ac105c0595589`.
- meta-swupdate kirkstone commit `f115c13978a2263fc5d89a2e3cc8bc79ce66f9a2`.
- meta-tegra `kirkstone-l4t-r32.7.x` commit `94e3db3146dc273ec1df463426c0fcaeacc51b5f`.
- Jetson Linux R32.7.6 and JetPack 4.6.6 release metadata.
- Eight machine names and their module/carrier mappings in `tx.md`.
- Eight kas board files and their corrected relative includes.
- The TX layer commit `b21894b76d86e64ba2133cdd637580eae303b559`.
- The TX container base digest — now pinned in `docker/yocto/Dockerfile`
  (the orphaned `docker/tx/` Dockerfile was removed; it referenced a missing
  `entrypoint.sh` and was not wired into the Makefile).

Verified by the TX1 build:

- Clean kas checkout resolved every pinned repository.
- BitBake parsed all recipes with zero parse errors.
- The image completed all 5,777 scheduled tasks.
- `arches-image` rootfs, image QA, ext4, and tegraflash tasks succeeded.
- A TX1 `.rootfs.ext4` and `.tegraflash.tar.gz` package were generated.

Still requiring a target:

- Physical recovery-mode flashing and boot for every board.
- Target-side connectivity, hardware discovery, and OTA behavior.
- The existing SWUpdate scripts, which remain carried forward and are not
  asserted to provide TX slot switching.

Amendments (2026-09-02 audit pass):

- The claim "corrected relative includes" above was wrong: the board files
  still used file-relative (`../common.yaml`) includes, which kas 4.5 resolves
  incorrectly. Fixed to repo-relative (`kas/common.yaml`) and re-verified with
  a kas 4.5 checkout of all six pinned repos.
- Kas 4.5 against a `build/` directory carrying residue from another
  generation branch fails at the TEMPLATECONF probe (`templateconf.cfg` from
  a scarthgap build names a template that kirkstone poky does not have).
  Fix: remove `build/conf/templateconf.cfg` (or `make clean-build`) when
  switching generation branches. Recorded in `MIGRATION.md`.
- fix.md's Nano 2GB carrier claim ("P3541") is contradicted by the pinned
  BSP: the device tree is `tegra210-p3448-0003-p3542-0000.dtb` (carrier
  P3542-0000) while `p3541-0000_defconfig` is the U-Boot defconfig name.
  This branch documents the carrier as P3542-0000 per the BSP devicetree.
- The TX2 NX machine name `jetson-xavier-nx-devkit-tx2-nx` is the upstream
  meta-tegra machine name on the R32.7.x line — an unavoidable, documented
  naming collision, not a cross-generation reference.
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
- The TX container base digest in `docker/tx/Dockerfile`.

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
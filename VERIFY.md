# TX Verification Record

Verified for the TX branch:

- Yocto kirkstone commit `445a6223929b9a7a62b575093659e3d9e1aba982`.
- meta-openembedded kirkstone commit `ce8539c941f6fcbecaca4d16640ac105c0595589`.
- meta-swupdate kirkstone commit `f115c13978a2263fc5d89a2e3cc8bc79ce66f9a2`.
- meta-tegra `kirkstone-l4t-r32.7.x` commit `94e3db3146dc273ec1df463426c0fcaeacc51b5f`.
- Jetson Linux R32.7.6 and JetPack 4.6.6 release metadata.
- Eight machine names and their module/carrier mappings in `tx.md`.
- Eight kas board files and their corrected relative includes.
- The TX layer commit `fc1106e7d0c53bd4e71e23e3c840455413437862`.
- The TX container base digest in `docker/tx/Dockerfile`.

Still requiring a build or target:

- BitBake parse after kas checks out the TX layer set.
- CUDA 10.2 and GCC 8 recipe integration.
- Generated tegraflash package contents.
- Physical recovery-mode flashing and boot for every board.
- Target-side connectivity, hardware discovery, and OTA behavior.
- The existing SWUpdate scripts, which remain carried forward and are not
  asserted to provide TX slot switching.
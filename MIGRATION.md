# TX Migration

The TX branch is intentionally separate from the Orin tree. TX uses Yocto
kirkstone, Jetson Linux R32.7.6, the legacy tegraflash flow, and cboot or U-Boot;
the Orin tree uses a newer BSP and UEFI/extlinux assumptions.

The branch changes are:

- kas repositories point to TX-compatible kirkstone and R32.7.6 commits.
- Orin board entries are removed and eight verified TX board entries are added.
- The TX image emits `ext4` and `tegraflash` artifacts.
- Orin UEFI bbappends and Orin WIC layouts are removed from `meta-arches`.
- The kernel configuration append matches the R32 `linux-tegra` recipe.
- The TX `meta-arches` layer declares kirkstone compatibility and is pinned by
  the root kas manifest.
- Container, build-template, flash, verification, and migration documents are
  branch-local.

SWUpdate files are carried forward because update infrastructure is outside the
generation-porting scope. Their Orin-specific slot behavior remains an explicit
verification item in `VERIFY.md` and must not be treated as TX hardware support.
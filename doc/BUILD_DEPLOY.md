# Arches-OS Build and Deployment

## Purpose and scope

Arches-OS builds the Arches embedded Linux image and developer artifacts with Kas/Yocto, Docker, and board-specific configuration. The root Makefile owns image, SDK/eSDK, OTA, flash, deployment, and cleanup workflows.

## Prerequisites

Install Docker, `make`, curl, `bmaptool`, `cpio`, and sufficient disk/network capacity for Yocto downloads and sstate. Use the repository's `kas/` configuration and board definitions. Hardware flashing requires a correctly identified block device and operator permission. OTA signing additionally requires private SWUpdate keys.

## Setup

Run `make kas-container-script` to fetch the pinned Kas container helper if it is absent. Select a supported board with the Makefile's `BOARD` variable and verify `check-board`; the associated Kas YAML must exist and derive a valid `MACHINE`. The Docker/Kas image is prepared with `make kas-image` or automatically by dependent targets.

## Build and compile

- `make build` performs the board image build through Kas/BitBake.
- `make image BOARD=<board>` is an alias for `build`.
- `make kas-image` builds the KAS Yocto build container.
- `make shell BOARD=<board>` opens the Kas build shell.
- `make sdk-image BOARD=<board>` runs `bitbake -c populate_sdk`, stages the installer, builds the SDK Docker image, and deploys SDK artifacts.
- `make esdk-image BOARD=<board>` performs the corresponding `populate_sdk_ext` eSDK workflow.

`make check-board` is a cheap configuration check and should precede board-specific builds.

## Test and lint

The Makefile exposes `test`, `lint`, and `validate` as validation targets where configured by this repository; run `make help` to see the current aggregate behavior. Yocto/Kas builds are the primary compile validation. Board boot, services, peripherals, and OTA behavior require manual target verification.

## Packaging and artifacts

Image artifacts are collected by `make deploy-images` from `build/tmp/deploy/images/$(MACHINE)` into `deploy/images/<board>_<timestamp>/`, including `.wic.bz2` and `.wic.bmap`. SDK installers are collected by `make deploy-sdk`; eSDK installers by `make deploy-esdk`. `make swu BOARD=<board>` creates an OTA `.swu`; it is signed only when the configured private key is present.

## Deployment, install, and run

- `make flash BOARD=<board> DEVICE=/dev/sdX` validates the block device and flashes the newest compressed WIC with its bmap. This is destructive and requires explicit hardware confirmation.
- `make swu BOARD=<board>` packages the root filesystem, boot image, DTB, install hooks, and SWUpdate description, then deploys it with `deploy-swu`.
- `make deploy-images`, `make deploy-sdk`, `make deploy-esdk`, and `make deploy-swu` stage local release artifacts; they do not publish to a cloud registry.
- `make deploy`/`make deploy-*` behavior is conditional on the current Makefile variables and artifact availability; inspect `make help` before invoking a release workflow.

Signing keys, board credentials, artifact storage credentials, and production rollout are conditional and must never be committed.

## Cleanup

Use `make clean` for the configured build cleanup, `make clean-build` for build outputs, `make clean-docker` for Docker artifacts, and `make clean-all` for the full cleanup path. Confirm shared download and sstate directory policies before deleting caches.

## Hardware, cloud, and manual verification caveats

Yocto compilation does not prove the image boots on the selected board. Verify board identity, boot media, serial console, networking, services, device permissions, and rollback behavior manually. `flash` writes a block device; `swu` signing and installation require a real target and private-key handling. No cloud deployment is implemented by the Makefile.

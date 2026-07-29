---
description: Package the latest built rootfs into a .swu OTA update
argument-hint: [board] (default jetson-agx-orin-devkit)
allowed-tools: Bash(make swu:*)
---

Package a .swu OTA update from the most recently built rootfs.ext4 for the
board (requires a prior successful make build):

!`make swu ${ARGUMENTS}`

Report the resulting .swu path and size, and whether it was signed (RSA key
present at meta/meta-arches/swupdate/keys/) or unsigned. An unsigned .swu
is expected unless signing keys have been generated
(scripts/generate-swu-keys.sh).

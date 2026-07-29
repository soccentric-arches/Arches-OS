---
description: Remove build/ only (keeps download/sstate caches and deploy/)
allowed-tools: Bash(make clean:*)
---

Remove just the build/ output directory, preserving cache/downloads/,
cache/sstate-cache/, and deploy/ so the next build can reuse them:

!`make clean`

Confirm build/ is gone and remind the user this does not touch caches or
deploy/. For removing caches too, use make clean-all directly (destructive —
requires explicit user confirmation, do not run it from this command).

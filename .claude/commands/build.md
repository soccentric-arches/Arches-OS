---
description: Build the Yocto SD card image for a board (hours; runs in background)
argument-hint: [board] (default jetson-agx-orin-devkit)
allowed-tools: Bash(make build:*)
---

Kick off the full image build for the given board. This is an 8000+ bitbake
task build that takes hours — launch it in the background (e.g. redirect to a
log file and disown, or use an async terminal) rather than waiting inline:

!`echo "Reminder: run 'make build ${ARGUMENTS}' in the background and tail the log; do not block this session on it."`

Once launched, confirm the build reaches "Running task N of 8148" (or similar)
in the log before considering it under way, then report status without
polling continuously. `make build` is resumable — it is safe to stop and rerun.

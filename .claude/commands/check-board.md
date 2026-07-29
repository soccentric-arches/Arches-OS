---
description: Validate a board has a kas config and a derivable MACHINE
argument-hint: [board]
allowed-tools: Bash(make check-board:*)
---

Validate the board config without starting a build:

!`make check-board ${ARGUMENTS}`

Report the resolved board/machine, or the list of available boards if it
failed.

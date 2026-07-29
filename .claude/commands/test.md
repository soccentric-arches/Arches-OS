---
description: Verify build prerequisites (docker, curl) and board configs
allowed-tools: Bash(make test:*)
---

Run the repo's prerequisite/board-config test target:

!`make test`

Report PASS/FAIL and list anything missing (e.g. docker, curl) or any board
config that failed validation.

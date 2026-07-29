---
description: Lint the Makefile syntax and all kas YAML configs
allowed-tools: Bash(make lint:*)
---

Run the repo's lint target:

!`make lint`

Report PASS/FAIL. On failure, name the specific file or syntax error and stop
— do not attempt fixes unless asked.

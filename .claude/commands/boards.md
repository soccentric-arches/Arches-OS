---
description: List available board configs (kas/boards/*.yaml) and their MACHINE
allowed-tools: Bash(ls:*), Bash(grep:*), Bash(awk:*)
---

List every supported board and the Yocto MACHINE it derives to:

!`for f in kas/boards/*.yaml; do b=$(basename "$f" .yaml); m=$(grep '^machine:' "$f" | awk '{print $2}'); printf '%-40s %s\n' "$b" "$m"; done`

Present this as a table (board → machine). Note the default board is
`jetson-agx-orin-devkit` (see Makefile `BOARD ?=`), and boards are passed
positionally, e.g. `make build jetson-orin-nano`.

---
description: Fast repo-setup check for a board (kas checkout only, no bitbake)
argument-hint: [board] (default jetson-agx-orin-devkit)
allowed-tools: Bash(./kas-container checkout:*)
---

Run only the kas checkout phase (clone/fetch/checkout the 5 kas repos into
`layers/` and `meta/meta-arches`) — fast, no bitbake:

!`./kas-container checkout kas/boards/${ARGUMENTS:-jetson-agx-orin-devkit}.yaml`

Report whether the checkout succeeded and which repos/branches were checked
out. If it fails, do not attempt to fix `layers/` by hand — see the
meta-arches-rules skill.

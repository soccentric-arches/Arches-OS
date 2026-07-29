---
description: Repo + build state snapshot (git status, board, cache/build sizes)
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(du -sh:*), Bash(ls:*)
---

Gather a quick snapshot of repository and build state:

Git state:
!`git status --short --branch`

Build/cache/deploy directory sizes (may be slow on first run — sizes are
approximate):
!`du -sh build cache deploy 2>/dev/null || true`

Deployed artifacts:
!`ls -1 deploy/images deploy/sdk deploy/esdk deploy/swu 2>/dev/null`

Summarize: current branch/dirty state, whether build/, cache/downloads/,
cache/sstate-cache/, and deploy/ exist and their approximate sizes, and
what's already been deployed.

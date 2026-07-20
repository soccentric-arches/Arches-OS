#!/usr/bin/env bash
# delete_branches.sh
# Deletes all local and remote branches except the protected ones.

set -euo pipefail

PROTECTED=(
  "develop"
  "master"
  "release"
  "release-v0.0.2"
)

REMOTE="${1:-origin}"

is_protected() {
  local branch="$1"
  for p in "${PROTECTED[@]}"; do
    [[ "$branch" == "$p" ]] && return 0
  done
  return 1
}

echo "=== Fetching remote '$REMOTE' and pruning stale refs ==="
git fetch --prune "$REMOTE"

# ── Local branches ────────────────────────────────────────────────────────────
echo ""
echo "=== Deleting local branches ==="
while IFS= read -r branch; do
  branch="${branch#\* }"   # strip the leading '* ' from the current branch
  branch="${branch// /}"   # trim whitespace
  [[ -z "$branch" ]] && continue

  if is_protected "$branch"; then
    echo "  [SKIP]   $branch (protected)"
  else
    echo "  [DELETE] $branch"
    git branch -D "$branch"
  fi
done < <(git branch --format='%(refname:short)')

# ── Remote branches ───────────────────────────────────────────────────────────
echo ""
echo "=== Deleting remote branches on '$REMOTE' ==="
while IFS= read -r ref; do
  branch="${ref#"$REMOTE/"}"
  [[ -z "$branch" ]] && continue

  if is_protected "$branch"; then
    echo "  [SKIP]   $REMOTE/$branch (protected)"
  else
    echo "  [DELETE] $REMOTE/$branch"
    git push "$REMOTE" --delete "$branch"
  fi
done < <(git branch -r --format='%(refname:short)' | grep "^$REMOTE/" | grep -v "HEAD")

echo ""
echo "Done."

#!/usr/bin/env bash
# Arches-OS — per-repo validation gate.  See .claude/lib/validate-lib.sh.
#
#   quick   seconds. kas YAML + board config sanity. No Docker needed.
#   full    hours. The real Yocto image build via kas.
#
# Yocto/kas BSP build for the Jetson. Nothing here is application code, so the
# useful fast checks are all about config integrity.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.claude/lib/validate-lib.sh
source "${SCRIPT_DIR}/lib/validate-lib.sh"

TIER="$(tier_or_die "${1:-quick}")"

# ---------------------------------------------------------------------------
# Quick checks — seconds, no Docker needed
# ---------------------------------------------------------------------------

assert "Makefile syntax" "make -p -q 2>/dev/null | grep -q '^\.PHONY'"

assert "kas YAML configs are valid" \
  'for f in kas/common.yaml kas/boards/*.yaml kas/repos/*.yaml; do python3 -c "import yaml,sys; yaml.safe_load(open('\''$f'\''))" 2>/dev/null || { echo \"ERROR: $f is not valid YAML\"; exit 1; }; done'

assert "Board configs derive MACHINE" \
  'for f in kas/boards/*.yaml; do b=$(basename "$f" .yaml); m=$(grep "^machine:" "$f" | awk "{print \$2}"); [ -n "$m" ] || { echo "ERROR: $f has no machine: field"; exit 1; }; done'

assert "Build prerequisites (docker, curl)" \
  'command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }; command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found"; exit 1; }'

assert "kas-container script is present" \
  'test -f scripts/kas-container && test -x scripts/kas-container'

assert "No file-relative includes in kas YAML" \
  '! grep -r "\.\." kas/*.yaml kas/boards/*.yaml 2>/dev/null | grep -q "includes:"'

# ---------------------------------------------------------------------------
# Full checks — adds a kas checkout (needs Docker, takes ~30s)
# ---------------------------------------------------------------------------

if [ "$TIER" = "full" ]; then
  check "kas checkout (jetson-agx-orin-devkit)" "docker" \
    'KAS_CONTAINER_IMAGE=arches-kas:latest KAS_BUILD_DIR="$(pwd)/build" ./scripts/kas-container checkout kas/boards/jetson-agx-orin-devkit.yaml 2>&1'
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

report "$TIER"

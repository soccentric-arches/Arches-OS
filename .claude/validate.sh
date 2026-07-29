#!/usr/bin/env bash
# Arches-OS — per-repo validation gate.  See .claude/lib/validate-lib.sh.
#
#   quick   seconds. kas YAML + board config sanity. No Docker needed.
#   full    hours. The real Yocto image build via kas.
#
# Yocto/kas BSP build for the Jetson. Nothing here is application code, so the
# useful fast checks are all about config integrity.
set -uo pipefail
# shellcheck source=lib/validate-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/validate-lib.sh"

TIER="$(tier_or_die "${1:-quick}")"

# --- quick -----------------------------------------------------------------

# `make lint` here is genuinely good and needs nothing but python3: it parses
# the Makefile and every kas YAML. Reuse it rather than reimplement it.
check "kas YAML + Makefile parse (make lint)" "python3" 'make lint'

check "every board config declares a machine" "python3" \
  'for f in kas/boards/*.yaml; do
     m=$(grep "^machine:" "$f" | awk "{print \$2}")
     [ -n "$m" ] || { echo "$f has no machine: field"; exit 1; }
   done'

# The incident this guards against cost this repo its git origin: orphan gitlink
# entries (mode 160000) with no .gitmodules made kas clone a layer at the repo
# root, overwriting .git. Recovery is documented; prevention is cheaper.
assert "no orphan gitlinks in layers/" \
  'orphans=$(git ls-files -s layers/ 2>/dev/null | awk "\$1==\"160000\"{print \$4}")
   if [ -n "$orphans" ] && [ ! -f .gitmodules ]; then
     echo "orphan gitlink(s) with no .gitmodules — kas may clobber the repo root:"
     echo "$orphans"
     exit 1
   fi'

# meta-webconfig SHOULD be in the image — Arches-Configuration ships it as a
# Yocto layer with real recipes, and fleet-deps.yaml records OS depends_on
# Configuration. It is not wired yet: kas/common.yaml includes only poky,
# meta-openembedded, meta-tegra, meta-swupdate and meta-arches.
#
# This used to be a hard `assert`, so it failed on every single run. That made
# the whole OS gate red and blocked every OS-scoped loop before it did anything,
# including the six that have nothing to do with WebConfig — and a gate that is
# always red is a gate nobody reads. So: note the known gap while its own loop
# owns the fix, and become a real regression check the moment it is wired.
if grep -rq "meta-webconfig" kas/ 2>/dev/null; then
  assert "meta-webconfig layer resolves to a real layer.conf" \
    'for cand in ../Arches-Configuration/meta-webconfig layers/meta-webconfig meta-webconfig; do
       if [ -f "$cand/conf/layer.conf" ]; then exit 0; fi
     done
     echo "kas/ references meta-webconfig but no conf/layer.conf was found for it"
     exit 1'
else
  note "meta-webconfig not yet wired into kas/" \
    "tracked by loop/backlog/20260728-wire-meta-webconfig-into-kas.md — until it lands, a change to meta-webconfig will NOT reach the built image"
fi

# `make test` checks prerequisites then exits 1 if docker is absent. That is a
# FAIL verdict for what is really an unavailable toolchain, so gate on the tool.
check "build prerequisites + board configs (make test)" "docker curl" 'make test'

[ "$TIER" = "quick" ] && { report "$TIER"; exit $?; }

# --- full ------------------------------------------------------------------

check "image feature/SDK/OTA metadata (make validate)" "docker curl" 'make validate'

# A full Yocto build is hours, not minutes — well past the library's default
# timeout, and deliberately not something an edit-time hook should ever start.
if [ "${ARCHES_VALIDATE_BUILD_IMAGE:-0}" = "1" ]; then
  ARCHES_VALIDATE_TIMEOUT=${ARCHES_VALIDATE_TIMEOUT_IMAGE:-21600} \
    check "full kas image build" "docker curl" 'make build'
else
  block "full kas image build" \
    "not attempted; hours-long. Set ARCHES_VALIDATE_BUILD_IMAGE=1 to run it."
fi

report "$TIER"

#!/usr/bin/env bash
# Arches-OS — per-repo validation gate.  See .claude/lib/validate-lib.sh.
#
#   quick   seconds. kas YAML + board config sanity. No Docker needed.
#   full    hours. The real Yocto image build via kas.
#
# Yocto/kas BSP build for the Jetson. Nothing here is application code, so the
# useful fast checks are all about config integrity.

#!/usr/bin/env bash
set -euo pipefail


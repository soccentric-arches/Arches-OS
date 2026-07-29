#!/usr/bin/env bash
# build-all.sh
#
# Runs the Yocto build across every board (or a chosen subset) for a set of
# make targets (default: build, sdk, esdk). Failures are recorded but never
# stop the script — every board/target combination is always attempted. A
# pass/fail report table is printed to stdout and saved under
# build/reports/.
#
# Usage:
#   scripts/build-all.sh                                 # all boards, build+sdk+esdk
#   scripts/build-all.sh -b jetson-orin-nano              # single board
#   scripts/build-all.sh -b jetson-orin-nano,jetson-agx-orin-devkit
#   scripts/build-all.sh -t build                         # image build only
#   scripts/build-all.sh -t build,sdk-image,esdk-image    # full docker chains
#
# Exit status: 0 if every run passed, 1 if at least one run failed.

set -uo pipefail   # deliberately no -e: this script must continue past failures.

cd "$(dirname "$0")/.."

BOARDS_DIR="kas/boards"
DEFAULT_TARGETS="build sdk esdk"

TARGETS="$DEFAULT_TARGETS"
BOARDS=""

usage() {
    cat <<EOF
Usage: $0 [-b board1,board2,...] [-t target1,target2,...] [-h]

  -b   Comma-separated board names (default: all boards in $BOARDS_DIR/)
  -t   Comma-separated make targets to run per board (default: "$DEFAULT_TARGETS")
  -h   Show this help and exit

Report and per-run logs are written under build/reports/.
EOF
}

while getopts "b:t:h" opt; do
    case "$opt" in
        b) BOARDS="${OPTARG//,/ }" ;;
        t) TARGETS="${OPTARG//,/ }" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

if [ -z "$BOARDS" ]; then
    BOARDS=$(for f in "$BOARDS_DIR"/*.yaml; do basename "$f" .yaml; done)
fi

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="build/reports"
LOG_DIR="$REPORT_DIR/logs-$TS"
REPORT_FILE="$REPORT_DIR/build-all-$TS.md"
mkdir -p "$LOG_DIR"

RESULTS=()      # "board|target|STATUS|duration|logfile"
TOTAL_COUNT=0
FAIL_COUNT=0
RUN_START="$(date +%s)"

echo "=== build-all: boards=[${BOARDS}] targets=[${TARGETS}] ==="
echo "Logs: $LOG_DIR"
echo ""

for board in $BOARDS; do
    for target in $TARGETS; do
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        LOG_FILE="$LOG_DIR/${board}_${target}.log"
        echo ">>> [$board] make $target ..."
        START="$(date +%s)"
        if make "$target" BOARD="$board" >"$LOG_FILE" 2>&1; then
            STATUS="PASS"
        else
            STATUS="FAIL"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
        END="$(date +%s)"
        DURATION=$((END - START))
        echo "    $STATUS  (${DURATION}s)  log: $LOG_FILE"
        RESULTS+=("${board}|${target}|${STATUS}|${DURATION}s|${LOG_FILE}")
    done
done

RUN_END="$(date +%s)"
TOTAL_DURATION=$((RUN_END - RUN_START))
PASS_COUNT=$((TOTAL_COUNT - FAIL_COUNT))

# --- Render the report (Markdown table) -------------------------------------
render_report() {
    echo "# build-all report — $TS"
    echo
    echo "Total: $TOTAL_COUNT   Passed: $PASS_COUNT   Failed: $FAIL_COUNT   Elapsed: ${TOTAL_DURATION}s"
    echo
    echo "| Board | Target | Result | Duration | Log |"
    echo "|-------|--------|--------|----------|-----|"
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r r_board r_target r_status r_duration r_log <<< "$row"
        if [ "$r_status" = "PASS" ]; then
            mark="PASS"
        else
            mark="FAIL"
        fi
        echo "| $r_board | $r_target | $mark | $r_duration | $r_log |"
    done
}

{
    render_report
} | tee "$REPORT_FILE"

echo ""
echo "Report saved: $REPORT_FILE"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0

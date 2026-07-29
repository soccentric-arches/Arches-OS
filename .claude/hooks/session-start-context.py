#!/usr/bin/env python3
"""SessionStart hook — inject repo state the model would otherwise spend
several tool calls discovering: current branch/origin, whether a build has
run before, and whether a bitbake-server is already running (avoid starting
a second concurrent build)."""
import json
import os
import subprocess
import sys


def git(*args):
    try:
        result = subprocess.run(
            ["git", *args], capture_output=True, text=True, timeout=10
        )
        return result.stdout.strip()
    except Exception:
        return ""


root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
if os.path.isdir(root):
    os.chdir(root)

branch = git("rev-parse", "--abbrev-ref", "HEAD") or "unknown"
origin = git("remote", "get-url", "origin") or "unknown"

build_state = "no build/tmp/ yet (no build has run here)"
if os.path.isdir(os.path.join(root, "build", "tmp")):
    build_state = "build/tmp/ present (a build has run here before)"

running_note = ""
try:
    check = subprocess.run(["pgrep", "-f", "bitbake-server"], capture_output=True)
    if check.returncode == 0:
        running_note = " A bitbake-server process is already running — avoid starting a second concurrent build."
except Exception:
    pass

context = (
    f"Arches-OS: branch={branch}, origin={origin}. {build_state}.{running_note} "
    "Customize meta/meta-arches only — layers/ is kas-managed and must never be "
    "hand-edited (see the meta-arches-rules skill)."
)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}))

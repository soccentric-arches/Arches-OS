#!/usr/bin/env python3
"""PostToolUse hook — fast feedback after editing kas/Makefile config.

`make lint` parses every kas YAML plus the Makefile in seconds. Running it
right after an edit to kas/**/*.yaml or the Makefile catches a syntax error
immediately, instead of waiting for the Stop-hook `validate.sh quick` gate at
the end of the whole turn.

This hook never blocks the tool call (the edit already happened); it only
surfaces the lint result as additional context for the model.
"""
import json
import os
import re
import subprocess
import sys

PATH_KEYS = {"filePath", "file_path", "path"}


def emit(context=None):
    out = {"continue": True}
    if context:
        out["hookSpecificOutput"] = {
            "hookEventName": "PostToolUse",
            "additionalContext": context,
        }
    print(json.dumps(out))
    sys.exit(0)


def find_paths(obj):
    found = []
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in PATH_KEYS and isinstance(value, str):
                found.append(value)
            elif key == "files" and isinstance(value, list):
                found.extend(v for v in value if isinstance(v, str))
            else:
                found.extend(find_paths(value))
    elif isinstance(obj, list):
        for item in obj:
            found.extend(find_paths(item))
    return found


try:
    payload = json.load(sys.stdin)
except Exception:
    emit()

tool_name = str(payload.get("tool_name", ""))
tool_input = payload.get("tool_input", {}) or {}

if not re.search(r"create|write|edit|replace|delete|rename|apply_patch", tool_name, re.I):
    emit()

paths = [p.replace("\\", "/") for p in find_paths(tool_input)]


def touches_kas_config(path):
    return path.endswith("Makefile") or re.search(r"(^|/)kas/.*\.ya?ml$", path)


if not any(touches_kas_config(p) for p in paths):
    emit()

root = os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or "."

try:
    result = subprocess.run(
        ["make", "-C", root, "lint"],
        capture_output=True,
        text=True,
        timeout=60,
    )
except Exception as exc:
    emit(f"Could not run `make lint` after this edit: {exc}")

if result.returncode != 0:
    tail = (result.stdout + result.stderr).strip()[-1500:]
    emit(f"`make lint` failed after this kas/Makefile edit:\n{tail}\nFix before continuing.")

emit()

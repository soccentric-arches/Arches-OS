#!/usr/bin/env python3
import os
import sys


def find_controller() -> str | None:
    candidates = []

    env_path = os.environ.get("ARCHES_SERVER_CTRL")
    if env_path:
        candidates.append(env_path)

    repo_root = os.path.dirname(os.path.abspath(__file__))
    candidates.extend(
        [
            os.path.normpath(
                os.path.join(repo_root, "..", "Arches-Server", "src", "rest_api", "controllers", "HealthController.cc")
            ),
            os.path.normpath(
                os.path.join(repo_root, "Arches-Server", "src", "rest_api", "controllers", "HealthController.cc")
            ),
        ]
    )

    for candidate in candidates:
        if os.path.isfile(candidate):
            return candidate

    return None


controller = find_controller()
if not controller:
    print("INFO: HealthController.cc not found; skipping patch.", file=sys.stderr)
    sys.exit(0)

with open(controller, "r", encoding="utf-8") as handle:
    text = handle.read()

text = text.replace('"version": "{{\\}}",', '"version": "{}",', 1)
text = text.replace('#include <fmt/format.h>\n#include <fmt/format.h>\n', '#include <fmt/format.h>\n')

with open(controller, "w", encoding="utf-8") as handle:
    handle.write(text)

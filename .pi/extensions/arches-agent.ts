import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

/**
 * Arches Agent — pi extension for the SiliconCentric Arches project.
 *
 * Provides custom tools and event handlers derived from the project's
 * .claude/ agent procedures, skills, commands, and validation contract.
 *
 * Sources:
 *   - .claude/agents/        (orchestrator, executor, QA, auditor, approval)
 *   - .claude/skills/        (yocto, meta-arches, cmake, kernel, etc.)
 *   - .claude/commands/      (build, validate, lint, test, etc.)
 *   - .claude/loop_engine.md (loop workflow)
 *   - .claude/project_specs.md (fleet map, validation contract)
 */
export default function (pi: ExtensionAPI) {
  const PROJECT_ROOT = process.cwd();
  const ARCHES_ROOT = join(PROJECT_ROOT, "..", ".."); // Arches/ project root
  const FLEET_ROOT = join(ARCHES_ROOT, "..");          // project-managers/ root

  // ──────────────────────────────────────────────
  // Session Start: report project context
  // ──────────────────────────────────────────────
  pi.on("session_start", async (_event, ctx) => {
    const isArchesOS = existsSync(join(PROJECT_ROOT, ".claude", "CLAUDE.md"));
    if (isArchesOS) {
      ctx.ui.notify("Arches-OS agent active — Yocto/kas build for Jetson", "info");
    }
  });

  // ──────────────────────────────────────────────
  // Tool: arches_validate — run the validation gate
  // ──────────────────────────────────────────────
  pi.registerTool({
    name: "arches_validate",
    label: "Arches Validate",
    description:
      "Run the Arches-OS validation gate (quick or full). " +
      "Exit codes: 0=pass, 1-76=fail, 77=blocked (not a pass). " +
      "Use this before claiming any Arches-OS change is complete.",
    parameters: Type.Object({
      tier: Type.Optional(
        Type.Enum(
          { quick: "quick", full: "full" },
          { description: "Validation tier: quick (seconds) or full (hours, needs Docker)" },
        ),
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const tier = params.tier ?? "quick";
      const validateScript = join(PROJECT_ROOT, ".claude", "validate.sh");

      if (!existsSync(validateScript)) {
        return {
          content: [
            {
              type: "text",
              text: `Validation script not found at ${validateScript}. Are you in the Arches-OS repo root?`,
            },
          ],
          details: { exitCode: -1 },
        };
      }

      try {
        const output = execSync(`bash "${validateScript}" ${tier} 2>&1`, {
          cwd: PROJECT_ROOT,
          timeout: tier === "quick" ? 120_000 : 3_600_000,
        }).toString();

        const exitCode = 0;
        return {
          content: [
            {
              type: "text",
              text: `## Validation (${tier}) — PASS (exit 0)\n\n\`\`\`\n${output}\n\`\`\``,
            },
          ],
          details: { exitCode, tier, output },
        };
      } catch (err: unknown) {
        const error = err as { status?: number; stdout?: string; stderr?: string; message?: string };
        const exitCode = error.status ?? 1;
        const stdout = error.stdout?.toString() ?? "";
        const stderr = error.stderr?.toString() ?? "";
        const output = stdout || stderr || error.message || "Unknown error";

        const status =
          exitCode === 77
            ? "BLOCKED (77) — a check never ran (missing toolchain/hardware)"
            : `FAIL (${exitCode})`;

        return {
          content: [
            {
              type: "text",
              text: `## Validation (${tier}) — ${status}\n\n\`\`\`\n${output}\n\`\`\``,
            },
          ],
          details: { exitCode, tier, output },
          isError: exitCode !== 0,
        };
      }
    },
  });

  // ──────────────────────────────────────────────
  // Tool: arches_build — kick off a Yocto image build
  // ──────────────────────────────────────────────
  pi.registerTool({
    name: "arches_build",
    label: "Arches Build",
    description:
      "Kick off a Yocto image build for a given board. " +
      "Default board: jetson-agx-orin-devkit. " +
      "The build takes hours (8000+ bitbake tasks) and is resumable. " +
      "This tool launches it in the background and reports initial progress.",
    parameters: Type.Object({
      board: Type.Optional(
        Type.String({
          description: "Board name (e.g. jetson-agx-orin-devkit, jetson-orin-nano)",
        }),
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const board = params.board ?? "jetson-agx-orin-devkit";
      const makefile = join(PROJECT_ROOT, "Makefile");

      if (!existsSync(makefile)) {
        return {
          content: [{ type: "text", text: "Makefile not found. Are you in the Arches-OS repo root?" }],
          details: {},
          isError: true,
        };
      }

      try {
        // Quick syntax check first
        execSync("make -p -q 2>/dev/null", { cwd: PROJECT_ROOT, timeout: 30_000 });

        // Launch build in background, capture initial output
        const result = execSync(`make build ${board} 2>&1`, {
          cwd: PROJECT_ROOT,
          timeout: 60_000, // 1 min to see initial task queue
        }).toString();

        const hasTaskCount = /Running task \d+ of \d+/.test(result);

        return {
          content: [
            {
              type: "text",
              text: [
                `## Build launched for \`${board}\``,
                "",
                hasTaskCount
                  ? "✅ Build reached the task queue — it is under way."
                  : "⚠️ Build started but task queue not yet visible. Check the log.",
                "",
                "**Important:** This build takes hours. It is resumable — safe to kill and rerun.",
                "",
                "```",
                result.slice(0, 2000),
                result.length > 2000 ? "\n... (truncated)" : "",
                "```",
              ].join("\n"),
            },
          ],
          details: { board, launched: true, taskQueueReached: hasTaskCount },
        };
      } catch (err: unknown) {
        const error = err as { status?: number; stdout?: string; stderr?: string; message?: string };
        return {
          content: [
            {
              type: "text",
              text: [
                `## Build failed to launch for \`${board}\``,
                "",
                "```",
                error.stdout?.toString()?.slice(0, 2000) ?? "",
                error.stderr?.toString()?.slice(0, 2000) ?? "",
                error.message ?? "",
                "```",
              ].join("\n"),
            },
          ],
          details: { board, launched: false },
          isError: true,
        };
      }
    },
  });

  // ──────────────────────────────────────────────
  // Tool: arches_lint — run make lint
  // ──────────────────────────────────────────────
  pi.registerTool({
    name: "arches_lint",
    label: "Arches Lint",
    description:
      "Run make lint in the Arches-OS repo. Checks Makefile syntax and kas YAML configs. " +
      "Fast — completes in seconds.",
    parameters: Type.Object({}),
    async execute() {
      try {
        const output = execSync("make lint 2>&1", {
          cwd: PROJECT_ROOT,
          timeout: 30_000,
        }).toString();
        return {
          content: [
            {
              type: "text",
              text: `## Lint — PASS\n\n\`\`\`\n${output}\n\`\`\``,
            },
          ],
          details: { passed: true, output },
        };
      } catch (err: unknown) {
        const error = err as { status?: number; stdout?: string; stderr?: string; message?: string };
        return {
          content: [
            {
              type: "text",
              text: [
                "## Lint — FAIL",
                "",
                "```",
                error.stdout?.toString() ?? "",
                error.stderr?.toString() ?? "",
                "```",
              ].join("\n"),
            },
          ],
          details: { passed: false, output: error.stdout?.toString() ?? error.stderr?.toString() ?? "" },
          isError: true,
        };
      }
    },
  });

  // ──────────────────────────────────────────────
  // Tool: arches_kas_checkout — verify kas repo composition
  // ──────────────────────────────────────────────
  pi.registerTool({
    name: "arches_kas_checkout",
    label: "Arches Kas Checkout",
    description:
      "Run kas-container checkout for a given board to verify repository composition " +
      "without running BitBake. Default board: jetson-agx-orin-devkit. Needs Docker.",
    parameters: Type.Object({
      board: Type.Optional(
        Type.String({
          description: "Board name (e.g. jetson-agx-orin-devkit, jetson-orin-nano)",
        }),
      ),
    }),
    async execute(_toolCallId, params) {
      const board = params.board ?? "jetson-agx-orin-devkit";
      const kasContainer = join(PROJECT_ROOT, "scripts", "kas-container");

      if (!existsSync(kasContainer)) {
        return {
          content: [{ type: "text", text: "kas-container script not found at scripts/kas-container" }],
          details: {},
          isError: true,
        };
      }

      try {
        const output = execSync(
          `KAS_CONTAINER_IMAGE=arches-kas:latest KAS_BUILD_DIR="${PROJECT_ROOT}/build" ` +
            `./scripts/kas-container checkout kas/boards/${board}.yaml 2>&1`,
          { cwd: PROJECT_ROOT, timeout: 120_000 },
        ).toString();

        return {
          content: [
            {
              type: "text",
              text: `## Kas Checkout (\`${board}\`) — PASS\n\n\`\`\`\n${output}\n\`\`\``,
            },
          ],
          details: { board, passed: true, output },
        };
      } catch (err: unknown) {
        const error = err as { status?: number; stdout?: string; stderr?: string; message?: string };
        return {
          content: [
            {
              type: "text",
              text: [
                `## Kas Checkout (\`${board}\`) — FAIL`,
                "",
                "```",
                error.stdout?.toString() ?? "",
                error.stderr?.toString() ?? "",
                "```",
              ].join("\n"),
            },
          ],
          details: { board, passed: false },
          isError: true,
        };
      }
    },
  });

  // ──────────────────────────────────────────────
  // Tool: arches_boards — list available boards
  // ──────────────────────────────────────────────
  pi.registerTool({
    name: "arches_boards",
    label: "Arches Boards",
    description:
      "List all available board configurations in the Arches-OS repo. " +
      "Reads from kas/boards/*.yaml.",
    parameters: Type.Object({}),
    async execute() {
      const boardsDir = join(PROJECT_ROOT, "kas", "boards");
      if (!existsSync(boardsDir)) {
        return {
          content: [{ type: "text", text: "No kas/boards/ directory found." }],
          details: {},
        };
      }

      try {
        const output = execSync("ls kas/boards/*.yaml 2>&1", {
          cwd: PROJECT_ROOT,
        })
          .toString()
          .trim();

        const boards = output
          .split("\n")
          .filter(Boolean)
          .map((f) => f.replace("kas/boards/", "").replace(".yaml", ""));

        return {
          content: [
            {
              type: "text",
              text: [
                "## Available Boards",
                "",
                ...boards.map((b) => `- \`${b}\``),
                "",
                `**Total: ${boards.length} boards**`,
              ].join("\n"),
            },
          ],
          details: { boards },
        };
      } catch {
        return {
          content: [{ type: "text", text: "Failed to list board configurations." }],
          details: {},
          isError: true,
        };
      }
    },
  });

  // ──────────────────────────────────────────────
  // Tool: arches_status — git status across the fleet
  // ──────────────────────────────────────────────
  pi.registerTool({
    name: "arches_status",
    label: "Arches Status",
    description:
      "Show git status for the Arches-OS repo and optionally the full Arches fleet. " +
      "Reports current branch, dirty state, and recent commits.",
    parameters: Type.Object({
      scope: Type.Optional(
        Type.Enum(
          { local: "local", fleet: "fleet" },
          { description: "Scope: local (Arches-OS only) or fleet (all 9 Arches repos)" },
        ),
      ),
    }),
    async execute(_toolCallId, params) {
      const scope = params.scope ?? "local";

      try {
        const branch = execSync("git branch --show-current", { cwd: PROJECT_ROOT })
          .toString()
          .trim();
        const status = execSync("git status --short", { cwd: PROJECT_ROOT }).toString().trim();
        const log = execSync("git log --oneline -5", { cwd: PROJECT_ROOT }).toString().trim();

        let fleetStatus = "";
        if (scope === "fleet" && existsSync(join(ARCHES_ROOT, "Makefile"))) {
          try {
            fleetStatus = execSync("make status 2>&1 | head -60", {
              cwd: ARCHES_ROOT,
              timeout: 30_000,
            })
              .toString()
              .trim();
          } catch {
            fleetStatus = "(fleet status unavailable)";
          }
        }

        const lines: string[] = [
          `## Arches-OS Status`,
          ``,
          `**Branch:** \`${branch}\``,
          ``,
          `**Status:**`,
          status ? `\`\`\`\n${status}\n\`\`\`` : "_(clean)_",
          ``,
          `**Recent commits:**`,
          `\`\`\`\n${log}\n\`\`\``,
        ];

        if (fleetStatus) {
          lines.push(``, `**Fleet status:**`, `\`\`\`\n${fleetStatus}\n\`\`\``);
        }

        return {
          content: [{ type: "text", text: lines.join("\n") }],
          details: { branch, dirty: status.length > 0 },
        };
      } catch (err: unknown) {
        const error = err as { message?: string };
        return {
          content: [{ type: "text", text: `Failed to get status: ${error.message ?? "unknown error"}` }],
          details: {},
          isError: true,
        };
      }
    },
  });

  // ──────────────────────────────────────────────
  // Tool: arches_swu — package SWUpdate artifact
  // ──────────────────────────────────────────────
  pi.registerTool({
    name: "arches_swu",
    label: "Arches SWU",
    description:
      "Run make swu to package the SWUpdate update artifact. " +
      "Takes minutes (gzip of rootfs.ext4). " +
      "An unsigned .swu is expected when meta/meta-arches/swupdate/keys/ is absent.",
    parameters: Type.Object({}),
    async execute() {
      try {
        const output = execSync("make swu 2>&1", {
          cwd: PROJECT_ROOT,
          timeout: 600_000, // 10 min
        }).toString();

        return {
          content: [
            {
              type: "text",
              text: `## SWUpdate Package — PASS\n\n\`\`\`\n${output}\n\`\`\``,
            },
          ],
          details: { passed: true, output },
        };
      } catch (err: unknown) {
        const error = err as { status?: number; stdout?: string; stderr?: string; message?: string };
        return {
          content: [
            {
              type: "text",
              text: [
                "## SWUpdate Package — FAIL",
                "",
                "```",
                error.stdout?.toString() ?? "",
                error.stderr?.toString() ?? "",
                "```",
              ].join("\n"),
            },
          ],
          details: { passed: false },
          isError: true,
        };
      }
    },
  });

  // ──────────────────────────────────────────────
  // Tool: arches_help — show available commands
  // ──────────────────────────────────────────────
  pi.registerTool({
    name: "arches_help",
    label: "Arches Help",
    description:
      "Show available Arches agent tools and their descriptions. " +
      "Use this to discover what the Arches agent can do.",
    parameters: Type.Object({}),
    async execute() {
      return {
        content: [
          {
            type: "text",
            text: [
              "# Arches Agent — Available Tools",
              "",
              "| Tool | Description |",
              "|------|-------------|",
              "| `arches_validate` | Run validation gate (quick/full) |",
              "| `arches_build` | Kick off Yocto image build for a board |",
              "| `arches_lint` | Run make lint (Makefile + kas YAML) |",
              "| `arches_kas_checkout` | Verify kas repo composition for a board |",
              "| `arches_boards` | List available board configurations |",
              "| `arches_status` | Show git status (local or fleet) |",
              "| `arches_swu` | Package SWUpdate artifact |",
              "| `arches_help` | Show this help |",
              "",
              "---",
              "",
              "**Key project facts:**",
              "- Target: NVIDIA Jetson (Tegra, L4T/JetPack) + STM32 co-processor",
              "- Stack: Yocto + kas, built inside Docker",
              "- All customization goes in `meta/meta-arches/`",
              "- Upstream layers in `layers/` are never patched or tracked",
              "- 11 board configs in `kas/boards/`",
              "- Build is 8000+ bitbake tasks (hours) — resumable",
              "",
              "**Validation exit codes:**",
              "- `0` = PASS",
              "- `1-76` = FAIL",
              "- `77` = BLOCKED (not a pass — missing toolchain/hardware)",
            ].join("\n"),
          },
        ],
        details: {},
      };
    },
  });

  // ──────────────────────────────────────────────
  // PreToolUse guard: protect .claude/ gate files
  // ──────────────────────────────────────────────
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName === "edit" || event.toolName === "write") {
      const input = event.input as { path?: string };
      if (!input.path) return;

      const protectedPaths = [
        ".claude/validate.sh",
        ".claude/lib/",
        ".claude/hooks/",
        ".claude/commands/",
        ".claude/settings.json",
      ];

      for (const protectedPath of protectedPaths) {
        if (input.path.includes(protectedPath)) {
          const ok = await ctx.ui.confirm(
            "Protected File",
            `${input.path} is human-owned. Edit anyway?`,
          );
          if (!ok) {
            return { block: true, reason: "Protected gate file — human-owned, run it don't edit it" };
          }
        }
      }

      // Guard against editing layers/ contents
      if (input.path.includes("/layers/") && !input.path.includes(".gitignore")) {
        const ok = await ctx.ui.confirm(
          "Layers Directory",
          `${input.path} is under layers/ — kas manages this. Edit anyway?`,
        );
        if (!ok) {
          return {
            block: true,
            reason: "layers/ is managed by kas — never hand-edit its contents",
          };
        }
      }
    }
  });

  // ──────────────────────────────────────────────
  // Register a custom command: /arches
  // ──────────────────────────────────────────────
  pi.registerCommand("arches", {
    description: "Arches agent commands: validate, build, lint, status, boards, help",
    handler: async (args, ctx) => {
      const parts = (args ?? "").trim().split(/\s+/);
      const subcommand = parts[0]?.toLowerCase() ?? "help";

      switch (subcommand) {
        case "validate": {
          const tier = parts[1] === "full" ? "full" : "quick";
          ctx.ui.notify(`Running ${tier} validation...`, "info");
          try {
            const output = execSync(`bash .claude/validate.sh ${tier} 2>&1`, {
              cwd: PROJECT_ROOT,
              timeout: tier === "quick" ? 120_000 : 3_600_000,
            }).toString();
            ctx.ui.notify(`Validation (${tier}): PASS`, "info");
            ctx.ui.setWidget("arches", [
              `Validation (${tier}): PASS`,
              ...output.split("\n").slice(0, 10),
            ]);
          } catch (err: unknown) {
            const error = err as { status?: number; stdout?: string; stderr?: string };
            const exitCode = (error as { status?: number }).status ?? 1;
            const label = exitCode === 77 ? "BLOCKED" : "FAIL";
            ctx.ui.notify(`Validation (${tier}): ${label} (exit ${exitCode})`, "error");
          }
          break;
        }

        case "build": {
          const board = parts[1] ?? "jetson-agx-orin-devkit";
          ctx.ui.notify(`Launching build for ${board}...`, "info");
          try {
            const result = execSync(`make build ${board} 2>&1`, {
              cwd: PROJECT_ROOT,
              timeout: 60_000,
            }).toString();
            const hasTasks = /Running task \d+ of \d+/.test(result);
            ctx.ui.notify(
              hasTasks ? `Build for ${board}: task queue reached` : `Build for ${board}: started`,
              hasTasks ? "info" : "warn",
            );
          } catch (err: unknown) {
            const error = err as { stdout?: string; stderr?: string };
            ctx.ui.notify(`Build launch failed: ${(error.stderr ?? error.stdout ?? "").slice(0, 200)}`, "error");
          }
          break;
        }

        case "lint": {
          ctx.ui.notify("Running lint...", "info");
          try {
            execSync("make lint 2>&1", { cwd: PROJECT_ROOT, timeout: 30_000 });
            ctx.ui.notify("Lint: PASS", "info");
          } catch {
            ctx.ui.notify("Lint: FAIL", "error");
          }
          break;
        }

        case "status": {
          try {
            const branch = execSync("git branch --show-current", { cwd: PROJECT_ROOT })
              .toString()
              .trim();
            const dirty = execSync("git status --porcelain", { cwd: PROJECT_ROOT })
              .toString()
              .trim();
            ctx.ui.setWidget("arches", [
              `Branch: ${branch}`,
              dirty ? `Dirty: ${dirty.split("\n").length} files` : "Clean",
            ]);
            ctx.ui.notify(`Branch: ${branch}${dirty ? " (dirty)" : " (clean)"}`, "info");
          } catch {
            ctx.ui.notify("Failed to get status", "error");
          }
          break;
        }

        case "boards": {
          try {
            const output = execSync("ls kas/boards/*.yaml", { cwd: PROJECT_ROOT })
              .toString()
              .trim();
            const boards = output
              .split("\n")
              .filter(Boolean)
              .map((f) => f.replace("kas/boards/", "").replace(".yaml", ""));
            ctx.ui.setWidget("arches", [
              `Boards (${boards.length}):`,
              ...boards.map((b) => `  ${b}`),
            ]);
            ctx.ui.notify(`${boards.length} boards available`, "info");
          } catch {
            ctx.ui.notify("Failed to list boards", "error");
          }
          break;
        }

        default: {
          ctx.ui.setWidget("arches", [
            "Arches Agent Commands:",
            "  /arches validate [quick|full]  — Run validation gate",
            "  /arches build [board]          — Launch Yocto build",
            "  /arches lint                   — Run make lint",
            "  /arches status                 — Show git status",
            "  /arches boards                 — List available boards",
            "  /arches help                   — Show this help",
          ]);
          break;
        }
      }
    },
  });
}

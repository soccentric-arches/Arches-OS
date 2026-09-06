# Planning documents

Point-in-time reviews and specifications, kept for their reasoning rather than
as live instructions. They were in the repository root, where they read as
current documentation next to `README.md` and `REPO_MAP.md`; they are not.
See Task.md G-09.

Nothing here is authoritative about the tree as it stands. Check the code.

| File | What it is | Status as of 2026-09-06 |
|---|---|---|
| [`task.md`](task.md) | Jetson hardware-enablement review (AGX Orin / Orin Nano) | Substantively still accurate. Its MACHINE list matches `kas/boards/*.yaml` today. Explicitly "a planning document only". Renamed in place rather than deleted because nothing has superseded it. |
| [`BRANCH_SPLIT_FINDINGS.md`](BRANCH_SPLIT_FINDINGS.md) | Step 0 deliverable for the orchestration spec, dated 2026-09-02 | The branch split it plans has since happened, so it is a record rather than a plan. Its structural description of `kas/` remains a fair summary. |
| [`Arches-Loop-Orchestration-Spec.md`](Arches-Loop-Orchestration-Spec.md) | Loop orchestration specification | **Do not delete.** Several CHANGELOGs across the fleet cite `Arches-Loop-Orchestration-Spec-v2.md`, and no file of that name exists anywhere in the workspace — this appears to be the only orchestration spec present. Whether it is the v2 those references mean is unresolved. |

One live gap worth naming: the dangling `-v2` reference above. Either the v2
spec was never committed, or it lives outside this workspace, or the citations
are wrong. Anyone who knows should fix the citations or add the file.

---
name: meta-arches-rules
description: 'Use when working in the Arches-OS repository or the SiliconCentric meta-arches layer: kas board/repo configuration, the Makefile build workflow, SWUpdate packaging, or the layers/ tree. Covers repository boundary rules, the meta-arches do and do not list, kas/build commands, and the validation gate. For general Yocto/BitBake recipe practices independent of this repository, use the yocto-best-practices skill instead.'
argument-hint: 'Describe the Arches-OS, kas, meta-arches, or SWUpdate task to review or implement.'
---

# Meta-Arches Rules (Arches-OS)

Use this skill for any change inside the Arches-OS repository: kas configuration, the Makefile/container build workflow, meta/meta-arches, or layers/. Load the yocto-best-practices skill alongside this one for general recipe/layer hygiene.

## Repository Boundary

Arches-OS is a kas-managed Yocto build for NVIDIA Jetson boards. Keep project customization in meta/meta-arches, the checked-out SiliconCentric meta-arches layer. Treat upstream layers (poky, meta-openembedded, meta-tegra, meta-swupdate) as immutable dependencies. For the full directory layout and the (implicit, non-code) coupling to Client/Configuration/HAL, see `.claude/project_specs.md`.

### Do

- Put Arches-specific recipes, .bbappend files, classes, image changes, machine configuration, and distro policy in meta/meta-arches.
- Pin repositories and revisions in kas/repos/*.yaml; use the board configurations in kas/boards/ as the composition entry points.
- Keep layers/ untracked and let kas manage its contents. Review the tree for accidental gitlinks before committing.
- Prefer the existing Makefile targets and containerized scripts/kas-container workflow so host tools and kas version remain consistent.
- Validate metadata with the repository checks before starting a long image build, then run the narrowest useful build or test target.

### Do Not

- Do not patch poky, meta-openembedded, meta-tegra, meta-swupdate, or other upstream layer checkouts in layers/.
- Do not add layers/ repositories as submodules or tracked gitlinks. This can make kas check out a repository at the wrong location and damage the main repository's Git metadata (it has happened before in this repo — see CLAUDE.md history).
- Do not manually edit generated build/ output, tmp/, sstate, downloads, deploy artifacts, or kas checkout contents as source changes.
- Do not run make build to completion inside an interactive session unless there is time to spare; it is 8000+ bitbake tasks and can take hours. Kick it off, confirm it reaches the task queue (e.g. "Running task N of 8148"), then let it run separately.
- Do not use a recursive ?= $(shell date) (or similar) for a version that must stay constant across a multi-minute recipe and a recursive sub-make. SWU_VERSION must be frozen with := and passed explicitly to any recursive sub-make (mirroring DEPLOY_TS), or the sw-description version, .swu filename, and deploy-swu lookup will drift and deploy will fail.
- Do not treat expected build messages as bugs: an unsigned .swu is expected when meta/meta-arches/swupdate/keys/ is absent, and a missing .dtb is expected for UEFI-boot boards (e.g. Orin Nano).

## KAS and Build Workflow

1. Inspect the relevant board YAML, kas include, recipe, or image in meta/meta-arches before editing.
2. Run ./.claude/validate.sh quick for fast YAML, Makefile, board, prerequisite, and orphan-gitlink checks.
3. Use ./kas-container checkout kas/boards/<board>.yaml to verify repository checkout and revision composition without running BitBake.
4. For focused metadata changes, use the existing container and Makefile workflow. Keep the board as a positional argument, for example make build jetson-orin-nano.
5. Run make lint and make test after the focused check. Use ./.claude/validate.sh full when the change affects shared build configuration.
6. Only then run a full image build when its coverage is needed. make build is resumable — killing it mid-build is safe; rerun make build.

Useful commands:

```sh
./.claude/validate.sh quick
./kas-container checkout kas/boards/<board>.yaml
make lint
make test
make build jetson-orin-nano
make shell jetson-orin-nano   # shell in the build container
make swu                      # package SWUpdate artifact
make clean                    # removes build/
make clean-all                # also removes caches + deploy/
```

## Adding a New Recipe from a Git URL (often private, SSH/git://)

When asked to add a recipe for source hosted at a GitHub URL — especially a
private repo reachable only over SSH or the git:// protocol — follow this
sequence rather than guessing at fetcher syntax:

1. Place it under meta/meta-arches, in the matching category directory
   (recipes-bsp, recipes-connectivity, recipes-core, recipes-kernel,
   recipes-support, recipes-swupdate, or a new recipes-<category>/ if
   none fits), as recipes-<category>/<pn>/<pn>_<version>.bb. Never place it
   in layers/ or an upstream checkout.
2. Convert the URL to BitBake fetcher syntax. A private repo URL is
   usually given in one of these forms — convert it, don't use it verbatim:
   - scp-like SSH (git@github.com:ORG/REPO.git) →
     SRC_URI = "git://git@github.com/ORG/REPO.git;protocol=ssh;branch=<default-branch>"
   - explicit git:// over SSH → same ;protocol=ssh form above.
   - Public HTTPS repo → ;protocol=https instead; do not put tokens/credentials
     in SRC_URI — if HTTPS auth is required, that's a sign the fetch should
     use SSH instead.
   - Always add ;name=<pn> when the recipe fetches more than one URI, and
     set S = "${WORKDIR}/git" (or ${S}/<subdir> if the recipe lives in a
     subdirectory of the repo).
3. Pin SRCREV to a specific commit hash, not a floating branch head —
   branch= is still required by the fetcher for metadata, but the checkout
   itself must be reproducible. Do not use SRCREV = "${AUTOREV}" outside of
   throwaway/dev testing.
4. SSH access inside the build container: the kas-container workflow
   already mounts KAS_SSH_DIR=$(HOME)/.ssh into the container (see the
   Makefile's KAS_ENV), so do_fetch for a private SSH SRC_URI uses the
   same keys/agent as the kas repo checkouts. Before adding the recipe,
   confirm host SSH access works (ssh -T git@github.com) — if that fails,
   fetching inside the container will fail identically; it is not a recipe
   bug.
5. Fill in LICENSE, LIC_FILES_CHKSUM, DEPENDS/RDEPENDS, and
   do_install/FILES:${PN} as usual per the yocto-best-practices skill.
   Do not add the package's own repo credentials or private keys into the
   recipe or meta/meta-arches — only reference the existing mounted SSH dir.

### Testing and Validating a Newly Added Recipe

make lint/make test only check the Makefile and kas YAML — they do not
parse individual recipes. Validate a new recipe with BitBake itself, from
narrowest to widest, before trusting it in a full image build:

```sh
./.claude/validate.sh quick                 # fast sanity gate first
make shell jetson-orin-nano                 # open a shell in the build container
#   inside the container shell:
bitbake-layers show-recipes <pn>            # confirms the recipe parses and is visible
bitbake -c fetch <pn>                       # verifies the SSH/git fetch itself succeeds
bitbake -c unpack <pn>                      # verifies SRC_URI/S layout is correct
bitbake <pn>                                # builds the recipe standalone
```

Only after the standalone recipe build succeeds, add it to the image (e.g.
IMAGE_INSTALL:append in the relevant image recipe/.bbappend) and validate
at the image level:

```sh
make build jetson-orin-nano                 # or: make rebuild-image to force a clean rebuild
make lint
make test
./.claude/validate.sh full
```

If -c fetch fails with an auth/permission error, treat it as an SSH access
problem (see step 4 above), not a SRC_URI syntax problem — re-check host SSH
access before changing the recipe.

## Arches-Specific Checks

- Confirm board YAML files have the expected machine: field and compose the intended layers.
- Confirm the five kas-managed repositories (poky, meta-openembedded, meta-tegra, meta-swupdate, meta-arches) remain in their configured locations and revisions, as defined in kas/repos/*.yaml.
- Check git ls-files --stage layers/ for mode 160000 entries; there must be no orphan layer gitlinks (there is no .gitmodules in this repo, and submodules are forbidden).
- For SWUpdate changes, keep the version stable across description generation, artifact naming, and deploy lookup.
- Keep generated deployment artifacts out of source changes and use the repository's deploy targets for packaging.

## Recovery: make build Clobbers the Repo Root

If kas checks a repository out at the repo root instead of layers/<repo>, the Arches-OS .git objects/refs survive (kas augments the existing .git, it does not destroy it). Recover with:

```sh
git checkout develop
git remote set-url origin git@github.com:SiliconCentric/Arches-OS.git
git fetch origin --prune
git branch -D scarthgap
```

Verify git rev-parse develop matches the expected commit and origin points to SiliconCentric/Arches-OS.

## Validation Gate — .claude/validate.sh

```sh
./.claude/validate.sh quick   # seconds: kas YAML + Makefile parse, board machine: fields, orphan-gitlink guard, prerequisite check
./.claude/validate.sh full    # + make validate; the hours-long image build only with ARCHES_VALIDATE_BUILD_IMAGE=1
```

Exit codes follow the fleet contract: 0 pass, 1-76 fail, 77 means a check never ran (missing toolchain) — which is not a pass. This script is human-owned by the Loop Engine; do not edit it — fix the underlying issue instead, or raise it in the loop's Lessons Learned.

## Enforcement Hooks

The rules above are guidance; .claude/settings.json also wires up hooks in .claude/hooks/ that enforce the highest-risk ones deterministically, independent of whether the model has loaded this skill:

- pre-tool-use-guard.py (PreToolUse) — denies edits under layers/, denies git submodule add, and asks for confirmation before force-push, git reset --hard, bitbake -c cleanall, make clean-all, and other rm -rf usage.
- post-tool-use-lint.py (PostToolUse) — runs make lint automatically after any edit under kas/ or to the Makefile and surfaces failures immediately, ahead of the Stop gate.
- session-start-context.py (SessionStart) — reports branch, origin, build state, and whether a bitbake-server is already running, at the start of every session.
- The existing Stop hook still runs ./.claude/validate.sh quick at the end of every turn.

## Review Checklist

Before declaring a meta-arches or Arches-OS change complete, verify:

- Ownership is correct: project code is in meta/meta-arches, not an upstream checkout or generated directory.
- No generated files, caches, downloads, credentials, private keys, or layer gitlinks were added.
- ./.claude/validate.sh quick passes, followed by make lint and make test when applicable.
- Any SWUpdate version handling uses a frozen (:=) value shared consistently across description, artifact name, and deploy lookup.
- The final diff is limited to the requested behavior.

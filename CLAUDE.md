# CLAUDE.md — Arches-OS
Master SoCcentric CLAUDE.md applies. This file adds local knowledge only.

Arches-OS is the Yocto + kas build for the **NVIDIA Jetson** platform (Arches
project). All customization lives in `meta/meta-arches` (kas-managed clone of
`SiliconCentric/meta-arches`). Upstream layers are **never** patched.

- Build: `make build`  (or `make build jetson-orin-nano` — board is a positional arg)
- Test:  `make test`
- Lint:  `make lint`
- Help:  `make help`
- Shell in build container: `make shell jetson-orin-nano`
- Clean: `make clean` (removes `build/`); `make clean-all` also removes caches + `deploy/`

KAS image: `arches-kas:latest` (built from `docker/yocto/`). kas release pinned
to 4.5 via `kas-container`. Build runs inside Docker; `build/`, `downloads/`,
`sstate-cache/` are bind-mounted host dirs (gitignored).

## Do
- **kas manages `layers/` — never track its contents.** `layers/` is in
  `.gitignore`. The 5 kas repos (poky, meta-openembedded, meta-tegra,
  meta-swupdate, meta-arches) are checked out by kas into `layers/` (and
  `meta/meta-arches`), defined in `kas/repos/*.yaml`.
- **Quick repo-setup check without a full build:** `./kas-container checkout
  kas/boards/<board>.yaml` runs only the kas checkout phase (clone/fetch/checkout
  repos) — fast, no bitbake. Use it to verify layer setup.
- **Recovery if `make build` clobbers the repo root** (kas checks a repo out at
  root instead of `layers/<repo>`): the Arches-OS `.git` objects/refs survive
  (kas *augments* the existing `.git`, it does not destroy it). Recover with:
  `git checkout develop` → `git remote set-url origin
  git@github.com:SiliconCentric/Arches-OS.git` → `git fetch origin --prune` →
  `git branch -D scarthgap`. Verify `git rev-parse develop` == `297f259` and
  `origin` == SiliconCentric/Arches-OS.
- **Verify the build progresses before walking away:** `make build` is 8000+
  bitbake tasks (hours). Confirm it reaches "Running task N of 8148" in the log,
  then let it run separately.
- `make build` is resumable — killing it mid-build is safe; rerun `make build`.

## Don't
- **NEVER leave orphan gitlink (submodule) entries in the tree for `layers/`
  paths.** This repo previously tracked `layers/meta-swupdate` and
  `layers/meta-raspberrypi` as gitlinks (mode 160000) with NO `.gitmodules`.
  Running `make build` with those present caused kas to clone `meta-swupdate`
  AT THE REPO ROOT, overwriting the Arches-OS `.git` origin (→ sbabic/meta-
  swupdate), HEAD (→ scarthgap), and tracked files. Fix applied: `git rm --cached
  layers/meta-swupdate layers/meta-raspberrypi` (staged, 2026-07-10). Submodules
  are forbidden by the master CLAUDE.md anyway.
- **`layers/meta-raspberrypi` was spurious** — Arches is Jetson, not RPi. It was
  a leftover from Acadia (the RPi reference project) and not in any kas config.
- Don't run `make build` to completion inside an interactive session unless you
  have hours to spare — kick it off in the background and monitor the log.
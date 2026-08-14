# Arches-OS

Yocto + kas image build for the Jetson. Produces the OS that Client, Configuration and the
HAL/gRPC middleware all run inside.

## How you work here

* Commands: `.claude/commands/` — build, test, lint, boards, check-board, clean-build, kas-checkout, status, swu, help, validate.
* Write: all customization goes in `meta/meta-arches`. Upstream layers are never patched. Every script goes in the `script` folder.
* Test: `make test` and `make lint` are fast. The image build is 8000+ bitbake tasks and takes hours.
* Quick repo-setup check without a full build: `./kas-container checkout kas/boards/<board>.yaml` runs the checkout phase only.

## How you validate

* Gate: `./.claude/validate.sh quick` (seconds) or `full` (adds build + tests). Run it before you claim done.
* Exit codes: `0` pass, `1`-`76` fail, `77` a check never ran. **77 is not a pass.**
* The gate and everything under `.claude/lib`, `hooks`, `commands`, `settings.json` is human-owned. Run it, never edit it.

## Do

* Confirm `make build` reaches "Running task N of 8148" in the log before walking away, then let it run separately.
* Kick long builds off in the background. `make build` is resumable — killing it mid-build is safe, just rerun.
* Expect `make swu` to take minutes: it gzips the full `rootfs.ext4` (28 GB logical, ~1.1 GB real, sparse). An unsigned ~364 MB `.swu` is correct when `meta/meta-arches/swupdate/keys/` is absent, and a missing `.dtb` is expected for UEFI-boot boards like Orin Nano.
* Recover a clobbered repo root (kas checking a repo out at root instead of `layers/<repo>`) with: `git checkout develop` -> `git remote set-url origin git@github.com:soccentric-arches/Arches-OS.git` -> `git fetch origin --prune` -> `git branch -D scarthgap`. The `.git` objects and refs survive; kas augments `.git`, it does not destroy it.

## Don't

* **Never use a recursive `?= $(shell date)`** for a version that must hold constant across a multi-minute recipe and a recursive sub-make. `SWU_VERSION ?= $(shell date +%Y%m%d%H%M)` re-ran on every expansion, so the sw-description version, the `.swu` filename and the deploy lookup drifted to different minutes and deploy failed. Freeze with `:=` and pass it to the sub-make.
* **Never leave orphan gitlink entries** for `layers/` paths. This repo once tracked `layers/meta-swupdate` and `layers/meta-raspberrypi` as mode-160000 gitlinks with no `.gitmodules`; `make build` then made kas clone meta-swupdate at the repo root, overwriting origin, HEAD and tracked files.
* **Don't track anything under `layers/`.** kas manages it and it is gitignored.
* **Don't add `meta-raspberrypi`.** Arches is Jetson. It was a leftover from an earlier reference template and in no kas config.
* **Don't run `make build` to completion inside an interactive session** unless you have hours.

<!-- BEGIN loop-engine -->
## Do's and Don'ts (maintained by the Loop Engine)

Appended by the Loop Engine on loop close; curated by a human when approving a loop out of in-review/. Nothing outside this fence is engine-writable.

<!-- END loop-engine -->

# Four-Generation Branch Split Findings

Status: repository review completed on 2026-09-02.

This report is the required Step 0 deliverable for
[Arches-Loop-Orchestration-Spec.md](Arches-Loop-Orchestration-Spec.md). It records
what is verifiable in the current checkout and separates facts from work that
requires upstream or hardware verification.

## Current Structure

- `kas/` contains the shared kas composition, repository pin files, and eleven
  Orin board entry points.
- `Makefile`, `scripts/`, and `kas-container` provide the build, shell, test,
  lint, validation, and deployment entry points.
- `docker/` contains shared Yocto, SDK, and eSDK Dockerfiles; there are no
  generation-specific container definitions or entry scripts.
- `meta/meta-arches/` is a separate nested Git checkout. The root repository
  does not track that layer as ordinary files.
- `layers/`, `build/`, `cache/`, and `deploy/` are kas-managed or generated
  content and must remain outside source changes.

The current root checkout is `develop`. The available root branches are
`develop` and `main`; `tx`, `xavier`, `orin`, and `thor` do not exist locally or
on the configured origin. The nested `meta-arches` checkout has `develop`,
`master`, and `temp`; it has no matching generation branches.

## Layer Inventory And Pinning

The active kas composition consumes these repositories:

| Layer | Source | Branch | Revision | Checkout |
| --- | --- | --- | --- | --- |
| poky | `git.yoctoproject.org/poky` | `scarthgap` | `d4576e3c08...` | `layers/poky` |
| meta-openembedded | `github.com/openembedded/meta-openembedded` | `scarthgap` | `ae7dfb1224...` | `layers/meta-openembedded` |
| meta-tegra | `github.com/OE4T/meta-tegra` | `scarthgap` | `d2613418be...` | `layers/meta-tegra` |
| meta-swupdate | `github.com/sbabic/meta-swupdate` | `scarthgap` | `a329ea9f9e...` | `layers/meta-swupdate` |
| meta-rust-bin | `github.com/rust-embedded/meta-rust-bin` | `master` | `54721fa1c7...` | `layers/meta-rust-bin` |
| meta-virtualization | `git.yoctoproject.org/meta-virtualization` | `scarthgap` | `422dcd4975...` | `layers/meta-virtualization` |
| meta-arches | `git@github.com:soccentric-arches/meta-arches.git` | `develop` | **not pinned** | `meta/meta-arches` |

The first six repositories are pinned by kas files. `meta-arches` floats at the
`develop` branch because `kas/repos/meta-arches.yaml` has no `commit:` field.
There is no `.gitmodules` file and `git ls-files --stage layers/` reports no
layer gitlinks. All six checked-out upstream layers are clean at their kas
revisions.

## Current Generation And Coverage

The checked-out configuration is Orin-oriented: Yocto/OE-Core `scarthgap`,
`meta-tegra` `scarthgap`, and the L4T R36.x / JetPack 6.x line. The exact
release point must be recorded from the selected upstream revision when each
generation branch is cut; this report does not infer a more precise release
from a branch name.

The current board files cover these Orin configurations:

- `jetson-agx-orin-devkit`
- `jetson-agx-orin-devkit-industrial`
- `jetson-orin-nano`
- `jetson-orin-nano-devkit-nvme`
- `p3509-a02-p3767-0000`
- `p3737-0000-p3701-0004`
- `p3737-0000-p3701-0005`
- `p3768-0000-p3767-0000`
- `p3768-0000-p3767-0001`
- `p3768-0000-p3767-0003`
- `p3768-0000-p3767-0004`

TX, Xavier, Xavier NX, and Thor coverage is absent from the current checkout.
The current Orin set also does not, by itself, prove every requested SoM and
carrier row in the specification.

The required upstream refs were fetched read-only for machine-name
verification. Their immutable `meta-tegra` commits and observed machine files
are:

| Candidate ref | Commit | Relevant observed configs |
| --- | --- | --- |
| `kirkstone-l4t-r32.7.x` | `94e3db3146dc273ec1df463426c0fcaeacc51b5f` | TX1, TX2, TX2 4GB, TX2i, Nano, Nano 2GB, Xavier NX, Xavier NX eMMC, TX2 NX, plus `clara-agx-xavier-devkit` and `jetson-agx-xavier-devkit` |
| `kirkstone` | `47519b99e34475ee9e3e8840da5f1111ab7dee0f` | Xavier and Xavier NX plus Orin configs |
| `scarthgap-l4t-r35.x` | `0c507bfe8d64a0e113beeff8f45e7fe0dfb5bc80` | Xavier, Xavier NX, and Orin configs |
| `master-l4t-r38.2.x` | `7c110ad25129faeff3b26766e82a7525aa20b1c1` | `jetson-agx-thor-devkit` plus Orin configs |

This confirms the specification's generation boundaries cannot be implemented
by blindly selecting the suggested refs: the candidate TX ref includes Xavier
machines, and the candidate Thor ref includes Orin machines. A branch split
must select and retain only verified in-scope machines, and must document the
selected upstream release and layer compatibility. The requested AGX Xavier
Industrial and several production module names are not present in the R32.7.x
machine directory observed above; their supported release and carrier mapping
remain to be verified before adding branch content.

## `meta-arches` Inventory

The layer contains `arches.inc`, `conf/layer.conf`, eighteen image recipes,
four packagegroups, connectivity and initialization recipes, SWUpdate support,
UEFI bbappends, one Linux kernel config fragment and bbappend, and three Orin
WIC layouts. It has no project machine configuration, distro configuration,
build templates, generation-specific Docker assets, pinned manifest,
`VERIFY.md`, `MIGRATION.md`, or per-machine flash documentation.

The project layer is therefore not currently a complete generation branch. Its
Orin-specific image, WIC, UEFI, and SWUpdate assumptions cannot be copied into
TX, Xavier, or Thor without validating the corresponding upstream BSP.

## Build And Flash Entry Points

The supported build interface is the existing Makefile and kas container
workflow. `./.claude/validate.sh quick`, `make lint`, and `make test` are the
fast checks. A full image build is intentionally not claimed here: it is a
large BitBake workload and no generation split exists to validate yet.

Existing documentation describes the current shared Orin workflow. It does
not provide generation-specific Docker invocation, templates, or verified
flash procedures for every requested machine.

## Existing Upstream Customizations

No local modifications were found in the checked-out upstream layers. The
project's upstream changes are represented by files under `meta/meta-arches`,
including UEFI bbappends, the kernel bbappend and fragment, image policy,
SWUpdate support, and WIC layouts. No relocation from `layers/` is required.

## Ambiguities And Required Verification

1. The exact machine names and carrier mappings for TX, Xavier, Xavier NX, and
   Thor must be read from the selected `meta-tegra` revisions. They must not be
   invented from the requested table.
2. The Thor choice is unresolved: the specification permits R38.2.x or a later
   R39.x line. The chosen revision must be compatible with the selected
   Yocto/OE-Core release and must be checked for Thor-only machine coverage.
3. The specification names a non-buildable `master`, while this checkout uses
   `main` as an existing branch. The branch-cut operation needs an explicit
   decision about preserving, renaming, or replacing that branch.
4. `meta-rust-bin` and `meta-virtualization` are active dependencies even though
   the repository-specific checklist calls out five core repositories. Each
   generation must either carry them with immutable pins or remove them with a
   dependency review.
5. Image buildability, Docker buildability, reproducibility, flashing, and
   hardware behavior are unverified in this checkout.

## Findings Summary

The requested four-way split is not implemented. The safe next operation is to
resolve the Thor and documentation-branch decisions, fetch and verify the
generation-specific upstream revisions, then cut the four root and four
matching `meta-arches` branches. Until that evidence exists, creating machine
names, revisions, Docker base images, or flash commands would violate the
specification's no-invention rule.
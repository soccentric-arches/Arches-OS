---
name: yocto-best-practices
description: 'Use when working on any Yocto or BitBake project: writing or reviewing recipes, layers, classes, images, machine configuration, patches, or dependency declarations. Covers general reproducible-build practices, recipe hygiene, and layer conventions independent of any specific repository. For Arches-OS or SiliconCentric meta-arches repository-specific rules, use the meta-arches-rules skill instead.'
argument-hint: 'Describe the Yocto or BitBake recipe, layer, or build task to review or implement.'
---

# Yocto Best Practices

Use this skill when writing or reviewing BitBake recipes, classes, layers, images, or machine/distro configuration in any Yocto project. If the work is specifically in the Arches-OS repository or the SiliconCentric meta-arches layer, also load the meta-arches-rules skill for repository-specific boundaries and commands.

### Do

- Keep recipes declarative and narrow. Use existing Yocto variables, overrides, task flags, package splitting, and dependency declarations instead of shell-side discovery.
- Use FILESEXTRAPATHS, SRC_URI, PACKAGECONFIG, RDEPENDS, DEPENDS, and task dependencies explicitly so BitBake can model the build correctly.
- Prefer .bbappend files for extending an existing recipe; create a new recipe only when the project is genuinely a separate package.
- Use MACHINEOVERRIDES and distro or image policy deliberately. Do not hide board-specific behavior in generic recipes.
- Make changes reproducible: pin source revisions where policy requires it, use checksums for fetched archives, and avoid timestamps or host-environment values in build output.
- Preserve licensing metadata and source integrity. Check LIC_FILES_CHKSUM, source checksums, patch status, and the expected package contents.
- Keep patches small, explainable, and applied in recipe order. Prefer upstream fixes and submitable patches over permanent local forks.
- Validate metadata (parse, lint) before starting a long image build, then run the narrowest useful BitBake or package test.

### Do Not

- Do not patch upstream/vendor layer checkouts directly; extend them with .bbappend files or local layers instead.
- Do not manually edit generated build output (tmp/, sstate, downloads, deploy artifacts) as source changes.
- Do not use absolute host paths, undeclared host tools, network access during tasks, or shell commands that depend on the caller's current directory.
- Do not use bitbake -c cleanall casually; it removes downloaded source and can make diagnosis and rebuilds unnecessarily expensive. Prefer targeted -c cleansstate only when justified.
- Do not use BBMASK, broad COMPATIBLE_MACHINE, or global DISTRO_FEATURES changes to conceal a broken dependency or recipe.
- Do not add runtime dependencies merely because a build-time tool is needed; keep DEPENDS and RDEPENDS semantically correct.
- Do not silently override a variable globally when a machine, distro, image, package, or task-specific override is available.
- Do not introduce unreviewed binary blobs or private signing keys into a layer. Keep signing material out of source control and document expected key locations.
- Do not start a full image build as the first diagnostic step. Run a quick parse/lint or a targeted build task first.
- Do not use a recursive make/shell variable (e.g. $(shell date) with ?=) for a value that must remain constant across a multi-minute recipe and any recursive sub-invocation.

## Review Checklist

Before declaring a Yocto recipe or layer change complete, verify:

- The change is reproducible and does not depend on wall-clock time, host paths, undeclared tools, or network availability.
- Dependencies, package contents, licenses, overrides, and machine scope are explicit.
- The smallest relevant validation (parse/lint) passes before a full build is attempted.
- No generated files, caches, downloads, credentials, or private keys were added to source control.
- The final diff is limited to the requested behavior.

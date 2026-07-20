# =============================================================================
# Arches OS — NVIDIA Jetson Yocto Build System
# =============================================================================

# --- Image names -------------------------------------------------------------
KAS_IMAGE        ?= arches-kas:latest
SDK_IMAGE        ?= arches-sdk:latest
ESDK_IMAGE       ?= arches-esdk:latest

# Pin to a specific kas release — https://github.com/siemens/kas/releases
KAS_VERSION      ?= 4.5

# Yocto image recipe built by build / sdk / esdk / rebuild-image targets
IMAGE_TARGET     ?= arches-image

# OTA package version (overridable: make swu SWU_VERSION=1.2.3)
# Frozen with ':=' so the value is computed once per invocation. A recursive
# '?=' would re-run `date` on every expansion and drift across the multi-minute
# gzip — mismatching the sw-description version, the .swu filename, and the
# recursive deploy-swu lookup (which runs in its own make process).
SWU_VERSION      ?= $(shell date +%Y%m%d%H%M)
SWU_VERSION      := $(SWU_VERSION)

# RSA private key for signing .swu packages (optional — absent = unsigned)
SWU_PRIV_KEY     ?= meta/meta-arches/swupdate/keys/swupdate-private.pem

# Set to 1 for production OTA artifacts. Secure mode refuses to create an
# unsigned bundle; image builds also require ARCHES_SWUPDATE_PUBLIC_KEY.
ARCHES_SECURE_BOOT ?= 0

# --- Positional board argument -----------------------------------------------
# The board name is typed directly after the target — no BOARD= needed:
#   make image jetson-orin-nano
#   make sdk   jetson-orin-nano
#   make esdk  jetson-orin-nano
#   make shell jetson-orin-nano
# This block MUST appear before the BOARD default and KAS_CONFIG / MACHINE
# definitions so those variables are derived from the correct board name.
_BOARD_TARGETS := image build rebuild-image sdk esdk sdk-image esdk-image shell swu flash

ifneq ($(filter $(_BOARD_TARGETS),$(firstword $(MAKECMDGOALS))),)
  _BOARD_ARG := $(word 2,$(MAKECMDGOALS))
  ifneq ($(_BOARD_ARG),)
    # Only apply when BOARD was not explicitly set on the command line
    ifeq ($(origin BOARD),undefined)
      BOARD := $(_BOARD_ARG)
    endif
    # Prevent make from treating the board name as a missing target
    $(eval $(_BOARD_ARG):;@true)
  endif
endif

# --- Board -------------------------------------------------------------------
# Select target board — must match a file in kas/boards/<BOARD>.yaml
# SD card boards:
#   jetson-orin-nano             Jetson Orin Nano devkit (SD card, default)
# eMMC boards (AGX Orin family):
#   jetson-agx-orin-devkit       Jetson AGX Orin devkit (P3701-0000)
#   jetson-agx-orin-devkit-industrial  Jetson AGX Orin Industrial 64GB (P3701-0008)
#   p3737-0000-p3701-0004        Jetson AGX Orin 32GB (P3701-0004 in P3737)
#   p3737-0000-p3701-0005        Jetson AGX Orin 64GB (P3701-0005 in P3737)
# NVMe boards:
#   jetson-orin-nano-devkit-nvme Jetson Orin Nano devkit (NVMe)
#   p3509-a02-p3767-0000         Jetson Orin NX 16GB in P3509 carrier
#   p3768-0000-p3767-0000        Jetson Orin NX 16GB (P3767-0000 in P3768)
#   p3768-0000-p3767-0001        Jetson Orin NX 8GB  (P3767-0001 in P3768)
#   p3768-0000-p3767-0003        Jetson Orin Nano 8GB (P3767-0003 in P3768)
#   p3768-0000-p3767-0004        Jetson Orin Nano 4GB (P3767-0004 in P3768)
BOARD            ?= jetson-orin-nano
KAS_CONFIG       := kas/boards/$(BOARD).yaml

# Derive MACHINE automatically from the kas yaml
MACHINE          := $(shell grep '^machine:' $(KAS_CONFIG) 2>/dev/null | awk '{print $$2}')

# --- Directories -------------------------------------------------------------
BUILD_DIR        ?= $(CURDIR)/build
CACHE_DIR        ?= $(CURDIR)/cache
DL_DIR           ?= $(CACHE_DIR)/downloads
SSTATE_DIR       ?= $(CACHE_DIR)/sstate-cache
DEPLOY_DIR       ?= $(CURDIR)/deploy

# Single timestamp for the entire invocation — keeps all artifacts in the same
# snapshot directory and is passed explicitly to recursive make calls.
DEPLOY_TS        := $(shell date +%Y%m%d_%H%M%S)

# SDK / eSDK install paths inside the Docker containers
SDK_INSTALL_DIR  ?= /opt/poky/sdk
ESDK_INSTALL_DIR ?= /opt/poky/esdk

# --- kas-container -----------------------------------------------------------
KAS_CONTAINER     := $(CURDIR)/scripts/kas-container
KAS_CONTAINER_URL  = https://raw.githubusercontent.com/siemens/kas/refs/tags/$(KAS_VERSION)/kas-container

# All KAS operations go through kas-container which handles Docker volume
# mounts, UID/GID remapping, and build-dir env vars automatically.
KAS_ENV = \
	KAS_CONTAINER_IMAGE=$(KAS_IMAGE) \
	KAS_BUILD_DIR=$(BUILD_DIR) \
	DL_DIR=$(DL_DIR) \
	SSTATE_DIR=$(SSTATE_DIR) \
	KAS_SSH_DIR=$(HOME)/.ssh

KAS_RUN = $(KAS_ENV) $(KAS_CONTAINER)

# --- Internal helpers --------------------------------------------------------
# Split IMAGE_NAME:TAG once so every sub-make call is consistent.
_KAS_IMAGE_NAME  := $(firstword $(subst :, ,$(KAS_IMAGE)))
_KAS_IMAGE_TAG   := $(lastword  $(subst :, ,$(KAS_IMAGE)))
_SDK_IMAGE_NAME  := $(firstword $(subst :, ,$(SDK_IMAGE)))
_SDK_IMAGE_TAG   := $(lastword  $(subst :, ,$(SDK_IMAGE)))
_ESDK_IMAGE_NAME := $(firstword $(subst :, ,$(ESDK_IMAGE)))
_ESDK_IMAGE_TAG  := $(lastword  $(subst :, ,$(ESDK_IMAGE)))

# =============================================================================
# Targets
# =============================================================================
.PHONY: all build rebuild-image \
        kas-image image ensure-image \
        sdk-image ensure-sdk-image \
        esdk-image ensure-esdk-image \
        kas-container-script shell flash sdk esdk swu \
        deploy-images deploy-sdk deploy-esdk deploy-swu \
        clean clean-build clean-docker clean-all \
		check-board completion help lint test validate

all: build

# -----------------------------------------------------------------------------
# kas-container helper script
# -----------------------------------------------------------------------------

## Download the kas-container script into scripts/ when it is absent
kas-container-script:
	@if [ ! -f $(KAS_CONTAINER) ]; then \
	    echo "Downloading kas-container $(KAS_VERSION) ..."; \
	    curl -fsSL $(KAS_CONTAINER_URL) -o $(KAS_CONTAINER); \
	    chmod +x $(KAS_CONTAINER); \
	    echo "  Saved: $(KAS_CONTAINER)"; \
	fi

# -----------------------------------------------------------------------------
# Docker image targets
# -----------------------------------------------------------------------------

## Build (or rebuild) the KAS Yocto build container (docker/yocto/)
kas-image:
	$(MAKE) -C docker/yocto \
	    IMAGE_NAME=$(_KAS_IMAGE_NAME) \
	    IMAGE_TAG=$(_KAS_IMAGE_TAG) \
	    KAS_VERSION=$(KAS_VERSION)

## Build the KAS image only when it is absent (used internally by build/shell/sdk/esdk)
ensure-image:
	@docker image inspect $(KAS_IMAGE) >/dev/null 2>&1 \
	    || { echo "KAS image $(KAS_IMAGE) not found — building ..."; \
	         $(MAKE) kas-image; }

## Build the Yocto SD card image for BOARD — alias for build
## Usage: make image jetson-orin-nano
image: build

## Full chain: Yocto SDK build → stage installer → docker build → deploy
##   Step 1  ensure the KAS build container is present
##   Step 2  run bitbake populate_sdk inside the container
##   Step 3  locate and stage the SDK installer into docker/sdk/sdk.sh
##   Step 4  build the SDK Docker image
##   Step 5  deploy SDK artifacts to deploy/sdk/BOARD_TS/
sdk-image: ensure-image kas-container-script check-board
	@echo ""
	@echo "======================================================================"
	@echo " sdk-image: building Yocto SDK + Docker image for $(SDK_IMAGE)"
	@echo "======================================================================"
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	@echo ""
	@echo "[1/4] Building Yocto SDK (bitbake populate_sdk) ..."
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk $(IMAGE_TARGET)"
	@echo ""
	@echo "[2/4] Staging SDK installer into docker/sdk/ ..."
	$(eval _SDK_SH := $(shell find $(BUILD_DIR)/tmp/deploy/sdk -maxdepth 1 \
	    -name '*.sh' ! -name '*-ext-*' 2>/dev/null | sort -V | tail -1))
	@test -n "$(_SDK_SH)" || \
	    { echo "ERROR: SDK installer (.sh) not found in $(BUILD_DIR)/tmp/deploy/sdk"; exit 1; }
	@echo "  Source : $(_SDK_SH)"
	@echo "  Dest   : docker/sdk/sdk.sh"
	@cp "$(_SDK_SH)" docker/sdk/sdk.sh && chmod +x docker/sdk/sdk.sh
	@echo ""
	@echo "[3/4] Building SDK Docker image $(SDK_IMAGE) ..."
	$(MAKE) -C docker/sdk \
	    IMAGE_NAME=$(_SDK_IMAGE_NAME) \
	    IMAGE_TAG=$(_SDK_IMAGE_TAG) \
	    SDK_INSTALL_DIR=$(SDK_INSTALL_DIR)
	@echo ""
	@echo "[4/4] Deploying SDK artifacts to deploy/sdk/ ..."
	@$(MAKE) --no-print-directory deploy-sdk DEPLOY_TS=$(DEPLOY_TS)
	@echo ""
	@echo "======================================================================"
	@echo " sdk-image: complete → $(SDK_IMAGE)"
	@echo "======================================================================"
	@echo ""

## Full chain: Yocto eSDK build → stage installer → docker build → deploy
##   Step 1  ensure the KAS build container is present
##   Step 2  run bitbake populate_sdk_ext inside the container
##   Step 3  locate and stage the eSDK installer into docker/esdk/esdk.sh
##   Step 4  build the eSDK Docker image
##   Step 5  deploy eSDK artifacts to deploy/esdk/BOARD_TS/
esdk-image: ensure-image kas-container-script check-board
	@echo ""
	@echo "======================================================================"
	@echo " esdk-image: building Yocto eSDK + Docker image for $(ESDK_IMAGE)"
	@echo "======================================================================"
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	@echo ""
	@echo "[1/4] Building Yocto eSDK (bitbake populate_sdk_ext) ..."
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk_ext $(IMAGE_TARGET)"
	@echo ""
	@echo "[2/4] Staging eSDK installer into docker/esdk/ ..."
	$(eval _ESDK_SH := $(shell find $(BUILD_DIR)/tmp/deploy/sdk -maxdepth 1 \
	    -name '*-ext-*.sh' 2>/dev/null | sort -V | tail -1))
	@test -n "$(_ESDK_SH)" || \
	    { echo "ERROR: eSDK installer (*-ext-*.sh) not found in $(BUILD_DIR)/tmp/deploy/sdk"; exit 1; }
	@echo "  Source : $(_ESDK_SH)"
	@echo "  Dest   : docker/esdk/esdk.sh"
	@cp "$(_ESDK_SH)" docker/esdk/esdk.sh && chmod +x docker/esdk/esdk.sh
	@echo ""
	@echo "[3/4] Building eSDK Docker image $(ESDK_IMAGE) ..."
	$(MAKE) -C docker/esdk \
	    IMAGE_NAME=$(_ESDK_IMAGE_NAME) \
	    IMAGE_TAG=$(_ESDK_IMAGE_TAG) \
	    ESDK_INSTALL_DIR=$(ESDK_INSTALL_DIR)
	@echo ""
	@echo "[4/4] Deploying eSDK artifacts to deploy/esdk/ ..."
	@$(MAKE) --no-print-directory deploy-esdk DEPLOY_TS=$(DEPLOY_TS)
	@echo ""
	@echo "======================================================================"
	@echo " esdk-image: complete → $(ESDK_IMAGE)"
	@echo "======================================================================"
	@echo ""

## Build the SDK Docker image only when it is absent
ensure-sdk-image:
	@docker image inspect $(SDK_IMAGE) >/dev/null 2>&1 \
	    || { echo "SDK image $(SDK_IMAGE) not found — running full sdk-image chain ..."; \
	         $(MAKE) sdk-image; }

## Build the eSDK Docker image only when it is absent
ensure-esdk-image:
	@docker image inspect $(ESDK_IMAGE) >/dev/null 2>&1 \
	    || { echo "eSDK image $(ESDK_IMAGE) not found — running full esdk-image chain ..."; \
	         $(MAKE) esdk-image; }

# -----------------------------------------------------------------------------
# Yocto build targets
# -----------------------------------------------------------------------------

## Validate that BOARD has a kas config and MACHINE is derivable
check-board:
	@test -f "$(KAS_CONFIG)" \
	    || { echo "ERROR: No board config at $(KAS_CONFIG)"; \
	         echo "       Available boards:"; \
	         ls kas/boards/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/\.yaml//' | sed 's/^/         /'; \
	         exit 1; }
	@test -n "$(MACHINE)" \
	    || { echo "ERROR: Could not derive MACHINE from $(KAS_CONFIG)"; exit 1; }
	@echo "Board: $(BOARD)  Machine: $(MACHINE)"

## Build the Yocto image for the selected BOARD (default target)
build: ensure-image kas-container-script check-board
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) build $(KAS_CONFIG)
	@$(MAKE) --no-print-directory deploy-images DEPLOY_TS=$(DEPLOY_TS)

## Clean sstate for the image recipe then rebuild (use after adding packages)
rebuild-image: ensure-image kas-container-script check-board
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c cleansstate $(IMAGE_TARGET)"
	$(KAS_RUN) build $(KAS_CONFIG)
	@$(MAKE) --no-print-directory deploy-images DEPLOY_TS=$(DEPLOY_TS)

## Interactive shell inside the KAS build container
shell: ensure-image kas-container-script check-board
	$(KAS_RUN) shell $(KAS_CONFIG)

## Build the cross-toolchain SDK installer and deploy it (no Docker image)
## Use 'make sdk-image' to also build the SDK Docker image.
sdk: ensure-image kas-container-script check-board
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk $(IMAGE_TARGET)"
	@$(MAKE) --no-print-directory deploy-sdk DEPLOY_TS=$(DEPLOY_TS)

## Build the extensible SDK installer and deploy it (no Docker image)
## Use 'make esdk-image' to also build the eSDK Docker image.
esdk: ensure-image kas-container-script check-board
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk_ext $(IMAGE_TARGET)"
	@$(MAKE) --no-print-directory deploy-esdk DEPLOY_TS=$(DEPLOY_TS)

## Build a .swu OTA update package from the latest rootfs.ext4 image
## Usage: make swu   or   make swu SWU_VERSION=1.2.3
swu: check-board
	@if [ "$(ARCHES_SECURE_BOOT)" = "1" ] && [ ! -f "$(SWU_PRIV_KEY)" ]; then \
	    echo "ERROR: ARCHES_SECURE_BOOT=1 requires SWU_PRIV_KEY=$(SWU_PRIV_KEY)"; \
	    exit 1; \
	fi
	$(eval ROOTFS := $(shell find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) \
	    -name "arches-image-$(MACHINE)*.rootfs.ext4" \
	    -o -name "core-image-base-$(MACHINE)*.rootfs.ext4" 2>/dev/null \
	    | sort -V | tail -1))
	@test -n "$(ROOTFS)" || \
	    { echo "ERROR: No .rootfs.ext4 found. Ensure 'ext4' is in IMAGE_FSTYPES."; exit 1; }
	@echo "Packaging OTA update from: $(ROOTFS)"
	@mkdir -p $(BUILD_DIR)/swu

	# --- rootfs ---
	@gzip -kfc "$(ROOTFS)" > "$(BUILD_DIR)/swu/rootfs.ext4.gz"

	# --- kernel + DTB (required for I3: kernel/DTB included in OTA) ---
	$(eval KERNEL := $(shell find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) \
	    -maxdepth 1 \
	    -name "Image" -o -name "Image-$(MACHINE).bin" 2>/dev/null | sort -V | tail -1))
	$(eval DTB := $(shell find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) \
	    -maxdepth 1 \
	    -name "*.dtb" 2>/dev/null | sort -V | tail -1))
	@test -n "$(KERNEL)" \
	    && { echo "  Found kernel: $(KERNEL)"; cp "$(KERNEL)" "$(BUILD_DIR)/swu/Image"; } \
	    || echo "WARNING: kernel Image not found — kernel will not be updated in this .swu"
	@test -n "$(DTB)" \
	    && { echo "  Found DTB: $(DTB)"; cp "$(DTB)" "$(BUILD_DIR)/swu/$(notdir $(DTB))"; } \
	    || echo "WARNING: DTB not found — DTB will not be updated in this .swu"

	# --- sw-description ---
	@sed "s|@@VERSION@@|$(SWU_VERSION)|" \
	    meta/meta-arches/swupdate/sw-description \
	    > "$(BUILD_DIR)/swu/sw-description"
	@cp meta/meta-arches/swupdate/pre-install.sh  "$(BUILD_DIR)/swu/"
	@cp meta/meta-arches/swupdate/post-install.sh "$(BUILD_DIR)/swu/"

	# --- optional RSA signing (C2) ---
	@if [ -f "$(SWU_PRIV_KEY)" ]; then \
	    echo "Signing sw-description with RSA-4096 ..."; \
	    openssl dgst -sha256 \
	        -sign "$(SWU_PRIV_KEY)" \
	        -out  "$(BUILD_DIR)/swu/sw-description.sig" \
	        "$(BUILD_DIR)/swu/sw-description"; \
	    echo "Packing SIGNED .swu ..."; \
	    cd "$(BUILD_DIR)/swu" && \
	    { printf 'sw-description\nsw-description.sig\npre-install.sh\npost-install.sh\nrootfs.ext4.gz\n'; \
	      [ -f Image ] && printf 'Image\n'; \
	      ls *.dtb 2>/dev/null | while read f; do printf '%s\n' "$$f"; done; } \
	      | cpio -ov -H newc > "$(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"; \
	else \
	    echo "WARNING: No private key found — packing UNSIGNED .swu (run scripts/generate-swu-keys.sh to enable signing)"; \
	    cd "$(BUILD_DIR)/swu" && \
	    { printf 'sw-description\npre-install.sh\npost-install.sh\nrootfs.ext4.gz\n'; \
	      [ -f Image ] && printf 'Image\n'; \
	      ls *.dtb 2>/dev/null | while read f; do printf '%s\n' "$$f"; done; } \
	      | cpio -ov -H newc > "$(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"; \
	fi
	@echo "OTA package: $(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"
	@$(MAKE) --no-print-directory deploy-swu DEPLOY_TS=$(DEPLOY_TS) SWU_VERSION=$(SWU_VERSION)


## Flash to SD card.  Usage: make flash jetson-orin-nano DEVICE=/dev/sdX
flash: check-board
ifndef DEVICE
	$(error DEVICE is not set — example: make flash DEVICE=/dev/sdb)
endif
	@test -b "$(DEVICE)" || \
	    { echo "ERROR: '$(DEVICE)' is not a block device."; exit 1; }
	$(eval WIC := $(shell find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) \
	    -maxdepth 1 -name "*.wic.bz2" 2>/dev/null | sort -V | tail -1))
	@test -n "$(WIC)" || \
	    { echo "ERROR: no .wic.bz2 found in $(BUILD_DIR)/tmp/deploy/images/$(MACHINE)"; exit 1; }
	$(eval WIC_BMAP := $(WIC:.bz2=.bmap))
	@test -f "$(WIC_BMAP)" || \
	    { echo "ERROR: no .bmap file found at $(WIC_BMAP)"; exit 1; }
	@echo "Flashing $(WIC) → $(DEVICE)"
	bmaptool copy --bmap "$(WIC_BMAP)" "$(WIC)" "$(DEVICE)"

# -----------------------------------------------------------------------------
# Artifact deployment (called automatically; can also be invoked manually)
# -----------------------------------------------------------------------------

## Copy .wic SD card images → deploy/images/BOARD_TS/
deploy-images:
	@src="$(BUILD_DIR)/tmp/deploy/images/$(MACHINE)"; \
	 out="$(DEPLOY_DIR)/images/$(BOARD)_$(DEPLOY_TS)"; \
	 test -d "$$src" || { echo "ERROR: No image artifacts at $$src"; exit 1; }; \
	 echo "Deploying SD card images → $$out ..."; \
	 mkdir -p "$$out"; \
	 find "$$src" -maxdepth 1 \( -type f -o -type l \) \
	     \( -name "*.wic.bz2" -o -name "*.wic.bmap" \) \
	     -exec cp -L {} "$$out/" \;; \
	 echo "  Done: $$out"

## Copy cross-toolchain SDK installer → deploy/sdk/BOARD_TS/
deploy-sdk:
	@src="$(BUILD_DIR)/tmp/deploy/sdk"; \
	 out="$(DEPLOY_DIR)/sdk/$(BOARD)_$(DEPLOY_TS)"; \
	 test -d "$$src" || { echo "ERROR: No SDK artifacts at $$src"; exit 1; }; \
	 echo "Deploying SDK → $$out ..."; \
	 mkdir -p "$$out"; \
	 find "$$src" -maxdepth 1 \( -type f -o -type l \) \
	     -name '*.sh' ! -name '*-ext-*' \
	     -exec cp -L {} "$$out/" \;; \
	 echo "  Done: $$out"

## Copy extensible SDK installer → deploy/esdk/BOARD_TS/
deploy-esdk:
	@src="$(BUILD_DIR)/tmp/deploy/sdk"; \
	 out="$(DEPLOY_DIR)/esdk/$(BOARD)_$(DEPLOY_TS)"; \
	 test -d "$$src" || { echo "ERROR: No eSDK artifacts at $$src"; exit 1; }; \
	 echo "Deploying eSDK → $$out ..."; \
	 mkdir -p "$$out"; \
	 find "$$src" -maxdepth 1 \( -type f -o -type l \) \
	     -name '*-ext-*.sh' \
	     -exec cp -L {} "$$out/" \;; \
	 echo "  Done: $$out"

## Copy .swu OTA package → deploy/swu/BOARD_TS/
deploy-swu:
	@out="$(DEPLOY_DIR)/swu/$(BOARD)_$(DEPLOY_TS)"; \
	 swu="$(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"; \
	 test -f "$$swu" || { echo "ERROR: $$swu not found"; exit 1; }; \
	 echo "Deploying SWU → $$out ..."; \
	 mkdir -p "$$out"; \
	 cp -L "$$swu" "$$out/"; \
	 echo "  Done: $$out"

# -----------------------------------------------------------------------------
# Clean targets
# -----------------------------------------------------------------------------

## Remove build/  (alias for clean-build)
clean: clean-build

## Remove the build output directory
clean-build:
	rm -rf $(BUILD_DIR)

## Remove all three Docker images (kas, sdk, esdk)
clean-docker:
	docker rmi -f $(KAS_IMAGE) $(SDK_IMAGE) $(ESDK_IMAGE) 2>/dev/null || true

## Remove build/, cache/, and deploy/
clean-all: clean-build
	rm -rf $(CACHE_DIR) $(DEPLOY_DIR)

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

## Install bash tab-completion (appends a source line to ~/.bashrc)
completion:
	@RCFILE="$$HOME/.bashrc"; \
	 LINE="source \"$(CURDIR)/scripts/arches-make-completion.bash\""; \
	 if grep -qF "$$LINE" "$$RCFILE" 2>/dev/null; then \
	     echo "Completion already enabled in $$RCFILE"; \
	 else \
	     printf '\n# Arches Makefile tab-completion\n%s\n' "$$LINE" >> "$$RCFILE"; \
	     echo "Added to $$RCFILE — run: source $$RCFILE"; \
	 fi

## Lint: validate Makefile syntax and kas YAML configs
lint:
	@echo "Checking Makefile syntax ..."
	@$(MAKE) -p -q 2>/dev/null | grep -q '^\.PHONY' || { echo 'ERROR: Makefile parse failed'; exit 1; }
	@echo "Checking kas YAML configs ..."
	@for f in kas/common.yaml kas/boards/*.yaml kas/repos/*.yaml; do \
	     python3 -c "import yaml,sys; yaml.safe_load(open('$$f'))" 2>/dev/null \
	         || { echo "ERROR: $$f is not valid YAML"; exit 1; }; \
	 done
	@echo "Lint: OK"

## Test: verify build prerequisites and board configs
test:
	@echo "Checking build prerequisites ..."
	@command -v docker >/dev/null 2>&1 || { echo 'ERROR: docker not found'; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo 'ERROR: curl not found'; exit 1; }
	@echo "Checking board configs ..."
	@for f in kas/boards/*.yaml; do \
	     b=$$(basename "$$f" .yaml); \
	     m=$$(grep '^machine:' "$$f" | awk '{print $$2}'); \
	     [ -n "$$m" ] || { echo "ERROR: $$f has no machine: field"; exit 1; }; \
	     echo "  $$b → $$m"; \
	 done
	@echo "Test: OK"

## Validate image feature, SDK, and OTA metadata through BitBake
validate: ensure-image kas-container-script check-board
	@$(KAS_RUN) shell $(KAS_CONFIG) -c "set -eu; \
	    bitbake -e $(IMAGE_TARGET) | grep -q '^ARCHES_MIDDLEWARE=\"1\"'; \
	    bitbake -e $(IMAGE_TARGET) | grep -q '^ARCHES_CLOUD=\"1\"'; \
	    bitbake -e $(IMAGE_TARGET) | grep -q '^ARCHES_DEBUG=\"1\"'; \
	    bitbake -e $(IMAGE_TARGET) | grep -q '^ARCHES_SDK_SUPPORT=\"1\"'; \
	    bitbake -e $(IMAGE_TARGET) | grep -q 'packagegroup-arches-middleware'; \
	    bitbake -e $(IMAGE_TARGET) | grep -q 'packagegroup-arches-cloud'; \
	    bitbake -e $(IMAGE_TARGET) | grep -q 'packagegroup-arches-sdk'; \
	    bitbake -e $(IMAGE_TARGET) | grep -q 'dev-pkgs'; \
	    bitbake -e $(IMAGE_TARGET) | grep -q 'ptest-pkgs'; \
	    echo 'Arches feature validation: OK'"

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help:
	@printf "\nUsage: make <target> <board>\n"
	@printf "\n  Examples:\n"
	@printf "    make image  jetson-orin-nano\n"
	@printf "    make sdk    jetson-orin-nano\n"
	@printf "    make esdk   jetson-orin-nano\n"
	@printf "    make flash  jetson-orin-nano DEVICE=/dev/sdX\n"
	@printf "\nYocto build:\n"
	@printf "  %-24s %s\n" "image"              "Build Yocto SD card image for BOARD  (alias for build)"
	@printf "  %-24s %s\n" "build"              "Build Yocto SD card image for BOARD"
	@printf "  %-24s %s\n" "rebuild-image"      "cleansstate image recipe, then rebuild"
	@printf "  %-24s %s\n" "sdk"                "Build cross-toolchain SDK → deploy/sdk/"
	@printf "  %-24s %s\n" "esdk"               "Build extensible SDK     → deploy/esdk/"
	@printf "  %-24s %s\n" "shell"              "Interactive kas shell in the build container"
	@printf "  %-24s %s\n" "swu"                "Build .swu OTA package  [SWU_VERSION=YYYYMMDDHHMM]"
	@printf "  %-24s %s\n" "flash"              "Flash SD card  (requires DEVICE=/dev/sdX)"
	@printf "\nDocker images:\n"
	@printf "  %-24s %s\n" "kas-image"          "Build/rebuild KAS build container  (docker/yocto/)"
	@printf "  %-24s %s\n" "ensure-image"       "Build KAS image only when absent"
	@printf "  %-24s %s\n" "sdk-image"          "Full chain: SDK build → stage → docker build → deploy"
	@printf "  %-24s %s\n" "ensure-sdk-image"   "Run sdk-image chain only when image is absent"
	@printf "  %-24s %s\n" "esdk-image"         "Full chain: eSDK build → stage → docker build → deploy"
	@printf "  %-24s %s\n" "ensure-esdk-image"  "Run esdk-image chain only when image is absent"
	@printf "\nDeployment (called automatically; can also be run manually):\n"
	@printf "  %-24s %s\n" "deploy-images"      "Copy .wic artifacts → deploy/images/BOARD_TS/"
	@printf "  %-24s %s\n" "deploy-sdk"         "Copy SDK installer   → deploy/sdk/BOARD_TS/"
	@printf "  %-24s %s\n" "deploy-esdk"        "Copy eSDK installer  → deploy/esdk/BOARD_TS/"
	@printf "  %-24s %s\n" "deploy-swu"         "Copy .swu package    → deploy/swu/BOARD_TS/"
	@printf "\nClean:\n"
	@printf "  %-24s %s\n" "clean"              "Remove build/"
	@printf "  %-24s %s\n" "clean-docker"       "Remove kas/sdk/esdk Docker images"
	@printf "  %-24s %s\n" "clean-all"          "Remove build/, cache/, deploy/"
	@printf "\nUtilities:\n"
	@printf "  %-24s %s\n" "completion"         "Install bash tab-completion into ~/.bashrc"
	@printf "  %-24s %s\n" "lint"               "Validate Makefile syntax and kas YAML configs"
	@printf "  %-24s %s\n" "test"               "Verify build prerequisites and board configs"
	@printf "  %-24s %s\n" "validate"           "Validate image, SDK, middleware, cloud, debug, and OTA metadata"
	@printf "\nBoards (kas/boards/*.yaml):\n"
	@for f in kas/boards/*.yaml; do \
	     b=$$(basename "$$f" .yaml); \
	     if [ "$$b" = "$(BOARD)" ]; then \
	         printf "  %-28s (default)\n" "$$b"; \
	     else \
	         printf "  %-28s\n" "$$b"; \
	     fi; \
	 done
	@printf "\n"

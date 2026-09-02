# =============================================================================
# Arches OS — NVIDIA Jetson Yocto Build System
# =============================================================================

# --- Image names -------------------------------------------------------------
.DEFAULT_GOAL := help

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
#   make image jetson-agx-thor-devkit
#   make sdk   jetson-agx-thor-devkit
#   make esdk  jetson-agx-thor-devkit
#   make shell jetson-agx-thor-devkit
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
#   jetson-agx-thor-devkit       AGX Thor dev kit (T5000 P3834-0008, NVMe)
#   jetson-agx-thor-t4000        AGX Thor T4000 (P3834-0000, NVMe)
BOARD            ?= jetson-agx-thor-devkit
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
.PHONY: all build rebuild-image build-all \
        kas-image image ensure-image \
        sdk-image ensure-sdk-image \
        esdk-image ensure-esdk-image \
        kas-container-script shell flash sdk esdk swu \
        deploy-images deploy-sdk deploy-esdk deploy-swu \
        clean clean-build clean-docker clean-all \
		check-board completion help lint test validate

all: help

# -----------------------------------------------------------------------------
# kas-container helper script
# -----------------------------------------------------------------------------

## Download the kas-container script into scripts/ when it is absent
kas-container-script: ## Download the pinned kas-container helper when absent
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
kas-image: ## Build/rebuild KAS build container  (docker/yocto/)
	$(MAKE) -C docker/yocto \
	    IMAGE_NAME=$(_KAS_IMAGE_NAME) \
	    IMAGE_TAG=$(_KAS_IMAGE_TAG) \
	    KAS_DIGEST=sha256:1bf421652ed769134ec401add491ae6bc6f7b7c6f26c8b1fe12d15e318355563

## Build the KAS image only when it is absent (used internally by build/shell/sdk/esdk)
ensure-image: ## Build the KAS image only when absent
	@docker image inspect $(KAS_IMAGE) >/dev/null 2>&1 \
	    || { echo "KAS image $(KAS_IMAGE) not found — building ..."; \
	         $(MAKE) kas-image; }

## Build the Yocto SD card image for BOARD — alias for build
## Usage: make image jetson-agx-thor-devkit
image: build ## Build the selected image (alias for build)

## Full chain: Yocto SDK build → stage installer → docker build → deploy
##   Step 1  ensure the KAS build container is present
##   Step 2  run bitbake populate_sdk inside the container
##   Step 3  locate and stage the SDK installer into docker/sdk/sdk.sh
##   Step 4  build the SDK Docker image
##   Step 5  deploy SDK artifacts to deploy/sdk/BOARD_TS/
sdk-image: ensure-image kas-container-script check-board ## Full chain: SDK build → stage → docker build → deploy
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
	@_SDK_SH="$$(find $(BUILD_DIR)/tmp/deploy/sdk -maxdepth 1 \
	    -name '*.sh' ! -name '*-ext-*' 2>/dev/null | sort -V | tail -1)"; \
	 test -n "$$_SDK_SH" || { echo "ERROR: SDK installer (.sh) not found in $(BUILD_DIR)/tmp/deploy/sdk"; exit 1; }; \
	 echo "  Source : $$_SDK_SH"; \
	 echo "  Dest   : docker/sdk/sdk.sh"; \
	 cp "$$_SDK_SH" docker/sdk/sdk.sh && chmod +x docker/sdk/sdk.sh
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
esdk-image: ensure-image kas-container-script check-board ## Full chain: eSDK build → stage → docker build → deploy
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
	@_ESDK_SH="$$(find $(BUILD_DIR)/tmp/deploy/sdk -maxdepth 1 \
	    -name '*-ext-*.sh' 2>/dev/null | sort -V | tail -1)"; \
	 test -n "$$_ESDK_SH" || { echo "ERROR: eSDK installer (*-ext-*.sh) not found in $(BUILD_DIR)/tmp/deploy/sdk"; exit 1; }; \
	 echo "  Source : $$_ESDK_SH"; \
	 echo "  Dest   : docker/esdk/esdk.sh"; \
	 cp "$$_ESDK_SH" docker/esdk/esdk.sh && chmod +x docker/esdk/esdk.sh
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
ensure-sdk-image: ## Run sdk-image chain only when image is absent
	@docker image inspect $(SDK_IMAGE) >/dev/null 2>&1 \
	    || { echo "SDK image $(SDK_IMAGE) not found — running full sdk-image chain ..."; \
	         $(MAKE) sdk-image; }

## Build the eSDK Docker image only when it is absent
ensure-esdk-image: ## Run esdk-image chain only when image is absent
	@docker image inspect $(ESDK_IMAGE) >/dev/null 2>&1 \
	    || { echo "eSDK image $(ESDK_IMAGE) not found — running full esdk-image chain ..."; \
	         $(MAKE) esdk-image; }

# -----------------------------------------------------------------------------
# Yocto build targets
# -----------------------------------------------------------------------------

## Validate that BOARD has a kas config and MACHINE is derivable
check-board: ## Validate BOARD and derive its MACHINE
	@test -f "$(KAS_CONFIG)" \
	    || { echo "ERROR: No board config at $(KAS_CONFIG)"; \
	         echo "       Available boards:"; \
	         ls kas/boards/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/\.yaml//' | sed 's/^/         /'; \
	         exit 1; }
	@test -n "$(MACHINE)" \
	    || { echo "ERROR: Could not derive MACHINE from $(KAS_CONFIG)"; exit 1; }
	@echo "Board: $(BOARD)  Machine: $(MACHINE)"

## Build the Yocto image for the selected BOARD (default target)
build: ensure-image kas-container-script check-board ## Build and deploy the selected image
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) build $(KAS_CONFIG)
	@$(MAKE) --no-print-directory deploy-images DEPLOY_TS=$(DEPLOY_TS)

## Clean sstate for the image recipe then rebuild (use after adding packages)
rebuild-image: ensure-image kas-container-script check-board ## Clear image sstate, rebuild, and deploy
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c cleansstate $(IMAGE_TARGET)"
	$(KAS_RUN) build $(KAS_CONFIG)
	@$(MAKE) --no-print-directory deploy-images DEPLOY_TS=$(DEPLOY_TS)

## Build image+sdk+esdk for every board, continuing past failures, and emit
## a pass/fail report table under build/reports/.
## Usage: make build-all   or   make build-all BUILD_ALL_ARGS="-b jetson-agx-thor-devkit -t build"
build-all: ensure-image kas-container-script ## Build image+sdk+esdk for every board; pass/fail report
	./scripts/build-all.sh $(BUILD_ALL_ARGS)

## Interactive shell inside the KAS build container
shell: ensure-image kas-container-script check-board ## Open an interactive kas build shell
	$(KAS_RUN) shell $(KAS_CONFIG)

## Build the cross-toolchain SDK installer and deploy it (no Docker image)
## Use 'make sdk-image' to also build the SDK Docker image.
sdk: ensure-image kas-container-script check-board ## Build and deploy the standard SDK
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk $(IMAGE_TARGET)"
	@$(MAKE) --no-print-directory deploy-sdk DEPLOY_TS=$(DEPLOY_TS)

## Build the extensible SDK installer and deploy it (no Docker image)
## Use 'make esdk-image' to also build the eSDK Docker image.
esdk: ensure-image kas-container-script check-board ## Build and deploy the extensible SDK
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk_ext $(IMAGE_TARGET)"
	@$(MAKE) --no-print-directory deploy-esdk DEPLOY_TS=$(DEPLOY_TS)

## Build a .swu OTA update package from the latest rootfs.ext4 image
## Usage: make swu   or   make swu SWU_VERSION=1.2.3
swu: check-board ## Build and deploy an OTA package
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
	      :; } \
	      | cpio -ov -H newc > "$(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"; \
	else \
	    echo "WARNING: No private key found — packing UNSIGNED .swu (run scripts/generate-swu-keys.sh to enable signing)"; \
	    cd "$(BUILD_DIR)/swu" && \
	    { printf 'sw-description\npre-install.sh\npost-install.sh\nrootfs.ext4.gz\n'; \
	      :; } \
	      | cpio -ov -H newc > "$(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"; \
	fi
	@echo "OTA package: $(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"
	@$(MAKE) --no-print-directory deploy-swu DEPLOY_TS=$(DEPLOY_TS) SWU_VERSION=$(SWU_VERSION)


## Flash — Thor uses the unified initrd-flash flow (NVMe rootfs).
## See FLASH.md for the per-machine procedure.
flash: check-board ## Print the Thor flash procedure (see FLASH.md)
	@echo "Thor boards flash via initrd-flash from the flash package."
	@echo "Build the board image, then follow FLASH.md:"
	@echo "  make build $(BOARD)"
	@echo "  cd build/tmp/deploy/images/$(MACHINE) && sudo ./initrd-flash"

# -----------------------------------------------------------------------------
# Artifact deployment (called automatically; can also be invoked manually)
# -----------------------------------------------------------------------------

## Copy flash packages and rootfs images → deploy/images/BOARD_TS/
deploy-images: ## Copy .tegraflash-tar + rootfs → deploy/images/BOARD_TS/
	@src="$(BUILD_DIR)/tmp/deploy/images/$(MACHINE)"; \
	 out="$(DEPLOY_DIR)/images/$(BOARD)_$(DEPLOY_TS)"; \
	 test -d "$$src" || { echo "ERROR: No image artifacts at $$src"; exit 1; }; \
	 echo "Deploying image artifacts → $$out ..."; \
	 mkdir -p "$$out"; \
	 find "$$src" -maxdepth 1 \( -type f -o -type l \) \
	     \( -name "*.tegraflash-tar" -o -name "*.rootfs.ext4" -o -name "*.ext4.simg" \) \
	     -exec cp -L {} "$$out/" \;; \
	 echo "  Done: $$out"

## Copy cross-toolchain SDK installer → deploy/sdk/BOARD_TS/
deploy-sdk: ## Copy SDK installer   → deploy/sdk/BOARD_TS/
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
deploy-esdk: ## Copy eSDK installer  → deploy/esdk/BOARD_TS/
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
deploy-swu: ## Copy .swu package    → deploy/swu/BOARD_TS/
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
clean: clean-build ## Remove build/

## Remove the build output directory
clean-build: ## Remove the Yocto build directory
	rm -rf $(BUILD_DIR)

## Remove all three Docker images (kas, sdk, esdk)
clean-docker: ## Remove kas/sdk/esdk Docker images
	docker rmi -f $(KAS_IMAGE) $(SDK_IMAGE) $(ESDK_IMAGE) 2>/dev/null || true

## Remove build/, cache/, and deploy/
clean-all: clean-build ## Remove build/, cache/, deploy/
	rm -rf $(CACHE_DIR) $(DEPLOY_DIR)

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

## Install bash tab-completion (appends a source line to ~/.bashrc)
completion: ## Install bash tab-completion into ~/.bashrc
	@RCFILE="$$HOME/.bashrc"; \
	 LINE="source \"$(CURDIR)/scripts/arches-make-completion.bash\""; \
	 if grep -qF "$$LINE" "$$RCFILE" 2>/dev/null; then \
	     echo "Completion already enabled in $$RCFILE"; \
	 else \
	     printf '\n# Arches Makefile tab-completion\n%s\n' "$$LINE" >> "$$RCFILE"; \
	     echo "Added to $$RCFILE — run: source $$RCFILE"; \
	 fi

## Lint: validate Makefile syntax and kas YAML configs
lint: ## Validate Makefile syntax and kas YAML configs
	@echo "Checking Makefile syntax ..."
	@$(MAKE) -p -q 2>/dev/null | grep -q '^\.PHONY' || { echo 'ERROR: Makefile parse failed'; exit 1; }
	@echo "Checking kas YAML configs ..."
	@for f in kas/common.yaml kas/boards/*.yaml kas/repos/*.yaml; do \
	     python3 -c "import yaml,sys; yaml.safe_load(open('$$f'))" 2>/dev/null \
	         || { echo "ERROR: $$f is not valid YAML"; exit 1; }; \
	 done
	@echo "Lint: OK"

## Test: verify build prerequisites and board configs
test: ## Verify build prerequisites and board configs
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
validate: ## Validate image, SDK, middleware, cloud, debug, and OTA metadata
	@echo "Running validation gate (quick)..."
	@.claude/validate.sh quick

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

# ── Help ──────────────────────────────────────────────────────────────────────
# Targets are self-documenting: text after `## ` on a target line is picked up
# by `make help` automatically, so the listing can never drift from the rules.
.PHONY: help
help: ## Show this help
	@printf '\n  \033[1m%s\033[0m\n' 'Arches-OS'
	@printf '  Usage: make <target> [VAR=value ...]\n'
	@printf '\n'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_.\/-]+:.*?## / { printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf '\n'

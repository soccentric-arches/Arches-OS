IMAGE_NAME  ?= arches-kas
IMAGE_TAG   ?= latest
# Digest pin — keep in sync with the FROM line in the Dockerfile.
# kas 4.5 multi-arch index digest, resolved from the 4.5 tag.
KAS_DIGEST  ?= sha256:1bf421652ed769134ec401add491ae6bc6f7b7c6f26c8b1fe12d15e318355563

.PHONY: all build clean

all: build

## Build the KAS Yocto build container
build:
	docker build \
		--build-arg KAS_DIGEST=$(KAS_DIGEST) \
		--label "org.yocto.kas.version=4.5" \
		--label "org.opencontainers.image.base.digest=$(KAS_DIGEST)" \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		.

clean:
	docker rmi -f $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
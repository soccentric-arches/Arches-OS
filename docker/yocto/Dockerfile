# kas 4.5, pinned by digest (resolved from the 4.5 tag; multi-arch index).
# The Arches distro content is branch-local; the toolchain base image is shared
# across branches only because the digest — not a tag — is the pin.
ARG KAS_DIGEST=sha256:1bf421652ed769134ec401add491ae6bc6f7b7c6f26c8b1fe12d15e318355563
FROM ghcr.io/siemens/kas/kas@${KAS_DIGEST}

# Install bmap-tools (efficient SD card flashing) and a few extras
# that may be handy inside the build container.
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bmap-tools \
        fdisk \
        parted \
        file \
    && rm -rf /var/lib/apt/lists/*

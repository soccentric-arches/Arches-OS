FROM ghcr.io/siemens/kas/kas@sha256:1bf421652ed769134ec401add491ae6bc6f7b7c6f26c8b1fe12d15e318355563

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    bmap-tools fdisk file parted \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/arches-tx-entrypoint
RUN chmod 0755 /usr/local/bin/arches-tx-entrypoint

ENTRYPOINT ["/usr/local/bin/arches-tx-entrypoint"]
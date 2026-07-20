#!/bin/sh
set -eu

OUTPUT_DIR=${1:-meta/meta-arches/swupdate/keys}
PRIVATE_KEY="${OUTPUT_DIR}/swupdate-private.pem"
PUBLIC_KEY="${OUTPUT_DIR}/swupdate-public.pem"

if [ -e "${PRIVATE_KEY}" ] || [ -e "${PUBLIC_KEY}" ]; then
    echo "ERROR: refusing to overwrite existing SWUpdate keys in ${OUTPUT_DIR}" >&2
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
umask 077
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "${PRIVATE_KEY}"
openssl rsa -in "${PRIVATE_KEY}" -pubout -out "${PUBLIC_KEY}"
chmod 600 "${PRIVATE_KEY}"
chmod 644 "${PUBLIC_KEY}"
printf 'Generated SWUpdate key pair:\n  private: %s\n  public:  %s\n' "${PRIVATE_KEY}" "${PUBLIC_KEY}"
printf 'Keep the private key outside source control.\n'

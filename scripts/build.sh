#!/bin/bash

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Inputs and build configurations
INSTALLBUILDER="${INSTALLBUILDER:?missing value for INSTALLBUILDER}"
UPLOAD_API_KEY="${UPLOAD_API_KEY:?missing value for UPLOAD_API_KEY}"
HEALTHCHECKTOOLS_VERSION="$(cat HEALTHCHECKTOOLS_VERSION)"
VERSION="$(cat VERSION)"

# Calculate VERSION_ID
VERSION_REGEXP="^([0-9]+)\.([0-9]+)\.([0-9]+)$"
MAJOR_VERSION="$(sed -E "s/${VERSION_REGEXP}/\1/" <<< "$VERSION")"
MINOR_VERSION="$(sed -E "s/${VERSION_REGEXP}/\2/" <<< "$VERSION")"
PATCH_VERSION="$(sed -E "s/${VERSION_REGEXP}/\3/" <<< "$VERSION")"
VERSION_ID="$(printf '%d%02d%02d' "$MAJOR_VERSION" "$MINOR_VERSION" "$PATCH_VERSION")"

for arch in amd64 arm64; do
    INSTALLBUILDER_TARGET="linux-$([[ "$arch" = "amd64" ]] && echo "x64" || echo "$arch")"

    # Re-create the output directory
    rm -rf "output-${arch}"
    mkdir -p "output-${arch}"
    cp -rp project/. "output-${arch}"
    # Download healthcheck-tools
    for tool in smtp-checker ssl-checker; do
        curl -L "https://github.com/bitnami-labs/healthcheck-tools/releases/download/${HEALTHCHECKTOOLS_VERSION}/${tool}-linux-${arch}" -o "output-${arch}/health-check-tools/${tool}"
    done
    # Prepare project files
    sed -i \
        -e "s/@@VERSION@@/${VERSION}/g" \
        -e "s/@@VERSION_ID@@/${VERSION_ID}/g" \
        "output-${arch}"/{*,*/*}.*
    # Build auto-updater tool with VMware InstallBuilder
    "${INSTALLBUILDER}/autoupdate/bin/customize.run" build "output-${arch}/bndiagnostic-auto-updater.xml" "$INSTALLBUILDER_TARGET"
    cp "${INSTALLBUILDER}/autoupdate/output/autoupdate-${INSTALLBUILDER_TARGET}.run" "output-${arch}/autoupdater/autoupdate-${INSTALLBUILDER_TARGET}.run"

    # Build tool with VMware InstallBuilder
    "${INSTALLBUILDER}/bin/builder" build "output-${arch}/bndiagnostic.xml" "$INSTALLBUILDER_TARGET" --setvars \
        project.version="$VERSION" \
        project.versionId="$VERSION_ID" \
        upload_api_key="$UPLOAD_API_KEY"
    cp "${INSTALLBUILDER}/output/bndiagnostic.run" "output-${arch}/bndiagnostic-${VERSION}-${INSTALLBUILDER_TARGET}.run"
done

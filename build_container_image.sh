#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2019 ANSSI. All rights reserved.

set -o errexit -o nounset -o xtrace -o pipefail

# Use VFS as storage driver and create Docker compatible images
export STORAGE_DRIVER=vfs
export BUILDAH_FORMAT=docker

# Disable options that do not work inside a container (overlayfs, etc.)
sed -i -e 's|^mount_program|#mount_program|g' /etc/containers/storage.conf
sed -i -e 's|^mountopt|#mountopt|g' /etc/containers/storage.conf
sed -i -e '/\/var\/lib\/shared/d' /etc/containers/storage.conf

# Generate a date based version number for the container image
TIMESTAMP="$(date '+%Y%m%d%H%M%S')"
LOCAL_NAME="base:${TIMESTAMP}"

# Install minimal Git
dnf install -y git-core

# Do we need to rebuild the base image?
if [[ $(git diff --name-only HEAD~ HEAD | grep -Ec "Dockerfile|build_container_image.sh") -eq 0 ]]; then
    echo "No change in Dockerfile or build_container_image.sh."
    if [[ -z "${CLIPOS_REBUILD_BASE+x}" ]]; then
        echo "CLIPOS_REBUILD_BASE variable not set. Skipping base container image build."
        exit 0
    fi
    echo "CLIPOS_REBUILD_BASE variable set. Forcing base container image rebuild."
fi

# Build base container image
buildah build-using-dockerfile --isolation=chroot --file Dockerfile --tag ${LOCAL_NAME} .

# Login and push container image
buildah login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}

buildah push ${LOCAL_NAME} ${CI_REGISTRY_IMAGE}:${TIMESTAMP}
buildah push ${LOCAL_NAME} ${CI_REGISTRY_IMAGE}:latest

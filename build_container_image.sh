#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2019 ANSSI. All rights reserved.

set -o errexit -o nounset -o xtrace -o pipefail

# Create Docker compatible images
export BUILDAH_FORMAT=docker

# Generate a date based version number for the container image
TIMESTAMP="$(date '+%Y%m%d%H%M%S')"
LOCAL_NAME="base:${TIMESTAMP}"

# Build base container image
podman build --file Dockerfile --no-cache --pull --squash-all --tag ${LOCAL_NAME} .

# Login and push container image
podman login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}

podman push ${LOCAL_NAME} ${CI_REGISTRY_IMAGE}:${TIMESTAMP}
podman push ${LOCAL_NAME} ${CI_REGISTRY_IMAGE}:latest

# Remove local image
podman rmi ${LOCAL_NAME}

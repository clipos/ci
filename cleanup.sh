#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2019 ANSSI. All rights reserved.

set -o errexit -o nounset -o pipefail
# Debug
# set -o xtrace

main() {
    if [[ -d 'clipos' ]]; then
        echo "[*] Removing 'cache' & 'out' directories"
        # We do this from inside a podman container to make sure that have access
        # to all UIDs & GIDs mapped to the current user with user namespaces.
        podman run --rm --tty --interactive \
            --volume "${PWD}/clipos":/mnt:rw \
            debian:10 \
            rm -rf /mnt/cache /mnt/out
    fi
    echo "[*] Cleanup successful"
}

main ${@}

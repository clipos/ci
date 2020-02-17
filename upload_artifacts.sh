#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2019 ANSSI. All rights reserved.

# Do not set '-o errexit' to keep uploading artifacts if one transfer fails or
# if we retried a build.
set -o nounset -o pipefail
# Debug
# set -o xtrace

main() {
    # Are we using FTP to upload build artifacts or built-in GitLab CI logic?
    if [[ -z "${ARTIFACTS_FTP_URL:+x}" ]]; then
        echo "ARTIFACTS_FTP_URL is not set or empty. GitLab CI will upload artifacts."
        return 0
    fi

    if [[ ! -f 'artifacts/SHA256SUMS' ]]; then
        echo "No 'SHA256SUMS' found. Skipping artifacts upload."
        return 0
    fi

    cd 'artifacts'

    # Create remote artifact directory for current job
    lftp -c "connect ${ARTIFACTS_FTP_URL}; mkdir -p ${CI_PIPELINE_ID}"

    for f in *; do
        lftp -c "connect ${ARTIFACTS_FTP_URL}; cd ${CI_PIPELINE_ID}; mput ${f}"
    done

    echo "[*] Removing 'artifacts' directory"
    rm -rfv 'artifacts'
}

main ${@}

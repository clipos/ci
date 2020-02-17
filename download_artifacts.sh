#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2019 ANSSI. All rights reserved.

set -o errexit -o nounset -o pipefail
# Debug
# set -o xtrace

main() {
    echo "[*] Removing 'artifacts' directory"
    rm -rfv 'artifacts'

    mkdir -p 'artifacts'
    cd 'artifacts'

    # TODO: Download artifacts from GitLab CI.
    if [[ -z "${ARTIFACTS_DOWNLOAD_URL:+x}" ]]; then
        echo "ARTIFACTS_DOWNLOAD_URL is not set or empty. Skipping artifacts download."
        return 0
    fi

    echo "Will download artifacts from: ${ARTIFACTS_DOWNLOAD_URL}"

    # GitLab.com project ID for this repository (CLIPOS/ci)
    local -r project_id="${CI_PROJECT_ID}"

    # GitLab.com API URL to get the latest successful build
    local -r url="https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/api/v4/projects/${project_id}/pipelines?scope=finished&status=success"

    # Pick the latest successful build
    build="$(curl --proto '=https' --tlsv1.2 -sSf "${url}" | jq '.[0].id')"

    local -r url="${ARTIFACTS_DOWNLOAD_URL}/${build}"
    echo "[*] Retrieving artifacts from: ${url}"

    # List of artifacts to retrieve (Core & EFIboot packages)
    artifacts=(
        'core_pkgs.tar.zst'
        'efiboot_pkgs.tar.zst'
    )

    # Retrieve artifacts
    for a in "${artifacts[@]}"; do
        echo "[*] Downloading ${a}..."
        curl --proto '=https' --tlsv1.2 -sSf -o "${a}" "${url}/${a}"
    done

    # Retrieve the SHA256SUMS file and check artifacts integrity
    curl --proto '=https' --tlsv1.2 -sSf -o 'SHA256SUMS.full' "${url}/SHA256SUMS"

    # Only keep relevant checksums to avoid issues
    > 'SHA256SUMS'
    for a in "${artifacts[@]}"; do
        grep "${a}" 'SHA256SUMS.full' >> 'SHA256SUMS'
    done
    rm 'SHA256SUMS.full'

    echo "[*] Verifying artifacts integrity..."
    sha256sum -c 'SHA256SUMS'

    echo "[*] Artifacts successfully downloaded"
}

main ${@}

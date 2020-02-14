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

    if [[ -z "${ARTIFACTS_DOWNLOAD_URL:+x}" ]]; then
        echo "ARTIFACTS_DOWNLOAD_URL is not set or empty. Skipping artifacts download."
        return 0
    fi

    echo "Will download artifacts from: ${ARTIFACTS_DOWNLOAD_URL}"

    # GitLab access URL and API URL for the current project repository
    local -r base_url="https://${CI_SERVER_HOST}"
    local -r api_url="https://${CI_SERVER_HOST}/api/v4/projects/${CI_PROJECT_ID}"

    # URL to get the latest successful GitLab CI pipeline
    local -r pipeline_url="${api_url}/pipelines?scope=finished&status=success"

    # Pick the latest successful build
    pipeline="$(curl --proto '=https' --tlsv1.2 -sSf "${pipeline_url}" | jq '.[0].id')"

    # Use a "magic" value to specify that we should use artifacts stored by
    # GitLab
    local url=""
    if [[ ${ARTIFACTS_DOWNLOAD_URL} == "gitlab"  ]]; then
        # URL to get jobs in the pipeline
        local -r jobs_url="${api_url}/pipelines/${pipeline}/jobs"
        # GitLab API header with access token. This is required even on public
        # projects but only for this specific query
        local -r token="Private-Token: ${CI_ACCESS_TOKEN}"
        # Find the "build" job id for the latest successful pipeline
        job_id="$(curl --proto '=https' --tlsv1.2 -sSf -H "${token}" "${jobs_url}" | jq '.[] | select((.stage == "build") and (.status == "success")) | .id')"

        url="${base_url}/${CI_PROJECT_NAMESPACE}/${CI_PROJECT_NAME}/-/jobs/${job_id}/artifacts/raw/artifacts/"
    else
        url="${ARTIFACTS_DOWNLOAD_URL}/${pipeline}"
    fi
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

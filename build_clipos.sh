#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2019 ANSSI. All rights reserved.

set -o errexit -o nounset -o pipefail
# Debug
# set -o xtrace

# Help for the bash logic frequently used in this script:
# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash

main() {
    # Directory used to retrieve and store artifacts
    ARTIFACTS="$(realpath ${CI_PROJECT_DIR})/artifacts"

    # Use manifest project from current GitLab instance if no specific manifest
    # project was set.
    if [[ -z ${MANIFEST_URL:+x} ]]; then
        MANIFEST_URL="https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_NAMESPACE}/manifest"
    fi
    echo "Using manifest from: ${MANIFEST_URL}"

    # Install Git LFS support
    git lfs install --skip-repo

    # Fetch source
    mkdir clipos
    cd clipos
    umask 0022
    repo init -u "${MANIFEST_URL}"
    repo sync -j8 --no-clone-bundle

    # Make sure LFS objects are fetched
    repo forall -g lfs -c 'git lfs pull && git checkout .'

    extract_artifacts

    # Setup config.toml
    cp '../config.toml' 'config.toml'
    save_artifact 'config.toml'

    # Setup toolkit
    toolkit/setup.sh
    set +o nounset
    source toolkit/activate
    set -o nounset
    save_artifact 'run/bin/cosmk'

    # Get and save the current version
    local -r product="$(cosmk product-name)"
    local -r version="$(cosmk product-version)"
    echo "${version}" > version
    save_artifact 'version'

    # Build and push SDK if needed
    cosmk bootstrap 'sdk'
    if [[ -f "cache/${product}/${version}/sdk/binpkgs/Packages" ]]; then
        save_artifact_tar_zstd "cache/${product}/${version}/sdk/binpkgs"   'sdk_pkgs'
        save_artifact_tar_zstd "cache/${product}/${version}/sdk/bootstrap" 'sdk_build_logs'
    fi
    push_container_image $(cosmk container 'sdk')

    # Build Core
    cosmk build 'core'
    save_artifact_tar_zstd "cache/${product}/${version}/core/binpkgs" 'core_pkgs'
    save_artifact_tar_zstd "cache/${product}/${version}/core/build"   'core_build_logs'
    cosmk image 'core'
    save_artifact_tar_zstd "cache/${product}/${version}/core/image"   'core_image_logs'
    cosmk configure 'core'
    cosmk bundle 'core'
    save_artifact_tar_zstd "out/${product}/${version}/core/bundle"    'core_bundle'

    # Build EFI boot
    cosmk build 'efiboot'
    save_artifact_tar_zstd "cache/${product}/${version}/efiboot/binpkgs" 'efiboot_pkgs'
    save_artifact_tar_zstd "cache/${product}/${version}/efiboot/build"   'efiboot_build_logs'
    cosmk image 'efiboot'
    save_artifact_tar_zstd "cache/${product}/${version}/efiboot/image"   'efiboot_image_logs'
    cosmk configure 'efiboot'
    cosmk bundle 'efiboot'
    save_artifact_tar_zstd  "out/${product}/${version}/efiboot/bundle"   'efiboot_bundle'

    # Build Core state and firmwares for QEMU
    cosmk bundle 'qemu'

    # Build QEMU image
    ./testbed/create_qemu_image.sh

    # Prepare standalone QEMU image bundle
    mkdir -p "${product}_${version}_qemu"

    mv  "run/virtual_machines/main.qcow2" \
        "run/virtual_machines/core_state.keyfile" \
        "out/${product}/${version}/qemu/bundle/qemu-core-state.tar" \
        "cache/${product}/${version}/qemu/bundle/"* \
        "${product}_${version}_qemu"

    tar --extract \
        --file "out/${product}/${version}/efiboot/bundle/qemu-firmware.tar" \
        --directory "${product}_${version}_qemu"

    cp  "../README_qemu.md" "${product}_${version}_qemu/README.md"
    cp  "../qemu.sh" "../qemu-nokvm.sh" "${product}_${version}_qemu"

    save_artifact_tar_zstd  "${product}_${version}_qemu"  'qemu'

    cat "${ARTIFACTS}/SHA256SUMS"
}

extract_artifacts() {
    if [[ ! -f "${ARTIFACTS}/SHA256SUMS" ]]; then
        echo "No artifacts available. Skipping."
        return 0
    fi

    rm "${ARTIFACTS}/SHA256SUMS"

    # Extract artifacts
    for a in "${ARTIFACTS}/"*; do
        echo "[*] Extracting ${a}..."
        tar --extract --file "${a}" --warning=no-unknown-keyword
    done

    # Cleanup
    rm -rfv "${ARTIFACTS}"
    mkdir -p "${ARTIFACTS}"
}

# Login and push container image
push_container_image() {
    if [[ "${#}" -ne 1 ]]; then
        >&2 echo "[!] Argument missing: container image name and tag"
        exit 1
    fi
    local -r image="${1}"

    podman login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}

    echo "Pushing 'localhost/${image}' to registry '${CI_REGISTRY_IMAGE}'"
    podman push "localhost/${image}" "${CI_REGISTRY_IMAGE}/${image}"
}

save_artifact() {
    local -r src="${1}"

    # Workaround to strip file path when computing SHA256 sums
    # The double space is intentionnal (SHA256SUMS file format)
    echo "$(sha256sum "${src}" | cut -f1 -d\ )  $(basename "${src}")" >> "${ARTIFACTS}/SHA256SUMS"

    # Small artifacts are copied to the artifacts folder to keep them available
    # in the main project directory.
    cp -a "${src}" "${ARTIFACTS}"
}

save_artifact_tar_zstd() {
    local -r src="${1}"
    local -r dst="${2}.tar.zst"

    bsdtar --verbose --zstd --create --file "${dst}" "${src}"

    sha256sum "${dst}" >> "${ARTIFACTS}/SHA256SUMS"

    # Potentially large artifacts are moved to the artifacts folder as they are
    # no longer needed in the main project directory.
    mv "${dst}" "${ARTIFACTS}"
}

main ${@}

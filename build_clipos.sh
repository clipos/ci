#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2019 ANSSI. All rights reserved.

set -o errexit -o nounset -o xtrace -o pipefail

save_artifact() {
    local src="${1}"
    upload_artifact "${src}"
}

save_artifact_tar() {
    local src="${1}"
    local dst=".artifacts/${2}.tar"

    mkdir -p .artifacts
    bsdtar --verbose --create --file "${dst}" "${src}"

    upload_artifact "${dst}"
}

save_artifact_zstd() {
    local src="${1}"
    local dst=".artifacts/${2}.zst"

    mkdir -p .artifacts
    zstd --compress "${src}" -o "${dst}"

    upload_artifact "${dst}"
}

save_artifact_tar_zstd() {
    local src="${1}"
    local dst=".artifacts/${2}.tar.zst"

    mkdir -p .artifacts
    bsdtar --verbose --zstd --create --file "${dst}" "${src}"

    upload_artifact "${dst}"
}

upload_artifact() {
    local src="${1}"
    local dest="gitlab/${CI_PIPELINE_ID}"

    if [[ -z "${ARTIFACTS_FTP_URL:+x}" ]]; then
        >&2 echo "ARTIFACTS_FTP_URL is not set or empty. Skipping artifacts upload."
        return 0
    fi

    cat <<END_OF_LFTP_SCRIPT | lftp
connect ${ARTIFACTS_FTP_URL}
mkdir -p ${dest}
cd ${dest}
mput ${src}
END_OF_LFTP_SCRIPT
}

main() {
    # https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
    if [[ -z "${ARTIFACTS_FTP_URL:+x}" ]]; then
        >&2 echo "ARTIFACTS_FTP_URL is not set or empty. Skipping artifacts upload."
    fi

    # Install Git LFS support
    git lfs install --skip-repo

    # Fetch source
    mkdir clipos
    cd clipos
    umask 0022

    repo init -u https://review.clip-os.org/clipos/manifest
    repo sync -j8 --no-clone-bundle

    # Make sure LFS objects are fetched
    repo forall -g lfs -c 'git lfs pull && git checkout .'

    # Setup toolkit
    toolkit/setup.sh
    set +o nounset
    source toolkit/activate
    set -o nounset

    # Get and save the current version
    local version="$(cosmk product-version clipos)"
    echo "${version}" > version
    save_artifact 'version'

    # Setup debug instrumentation level
    cp '../instrumentation.toml' 'instrumentation.toml'
    save_artifact 'instrumentation.toml'

    # Build SDK
    cosmk bootstrap 'clipos/sdk'
    save_artifact_tar "cache/clipos/${version}/sdk/rootfs.squashfs" 'sdk'

    # Build Core
    cosmk build 'clipos/core'
    save_artifact_tar      "cache/clipos/${version}/core/binpkgs" 'core_pkgs'
    save_artifact_tar_zstd "cache/clipos/${version}/core/build"   'core_build_logs'

    cosmk image 'clipos/core'
    save_artifact_tar_zstd "cache/clipos/${version}/core/image"   'core_image_logs'

    cosmk configure 'clipos/core'

    cosmk bundle 'clipos/core'
    save_artifact_tar      "out/clipos/${version}/core/bundle"    'core_bundle'

    # Build EFI boot
    cosmk build 'clipos/efiboot'
    save_artifact_tar      "cache/clipos/${version}/efiboot/binpkgs" 'efiboot_pkgs'
    save_artifact_tar_zstd "cache/clipos/${version}/efiboot/build"   'efiboot_build_logs'

    cosmk image 'clipos/efiboot'
    save_artifact_tar_zstd "cache/clipos/${version}/efiboot/image"   'efiboot_image_logs'

    cosmk configure 'clipos/efiboot'
    save_artifact_tar      "out/clipos/${version}/efiboot/configure/OVMF_CODE_sb-tpm.fd" 'efiboot_ovmf'

    cosmk bundle 'clipos/efiboot'
    save_artifact_tar      "out/clipos/${version}/efiboot/bundle"    'efiboot_bundle'

    # Build Debian SDK
    cosmk bootstrap 'clipos/sdk_debian'
    save_artifact_tar      "cache/clipos/${version}/sdk_debian/rootfs.squashfs" 'sdk_debian'

    # Build QEMU image
    cosmk bundle 'clipos/qemu'
    save_artifact_tar_zstd "out/clipos/${version}/qemu/bundle/main.qcow2" 'qemu'
    rm "cache/clipos/${version}/qemu/bundle/empty.qcow2"
    mv "out/clipos/${version}/qemu/bundle/qemu-core-state.tar" \
        "cache/clipos/${version}/qemu/bundle/"
    save_artifact_tar_zstd "cache/clipos/${version}/qemu/bundle/" "qemu_misc"
}

main ${@}

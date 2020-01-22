# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2019 ANSSI. All rights reserved.

FROM debian:10

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Enable contrib to get 'repo' from Debian APT repositories
RUN grep -E '^deb .* buster main$' /etc/apt/sources.list &&\
    sed -i -e 's/^deb .* buster main$/\0 contrib/' /etc/apt/sources.list

# Gets rid of "(Reading database ... 5%" output.
RUN echo 'Dpkg::Use-Pty "0";' > /etc/apt/apt.conf.d/00usepty

# Update both packages index and installed packages
RUN apt-get -y -q update && apt-get -y -q --no-install-recommends upgrade

# Install all the required packages for this environment. See the section
# related to the development environment setup in the CLIP OS project
# documentation for the rationale behind every package:
RUN apt-get -y -q --no-install-recommends install \
        git git-lfs python2.7 gnupg2 repo \
        python3 python3-venv python3-dev build-essential pkg-config \
        bash sudo util-linux squashfs-tools coreutils diffutils locales \
        cargo \
        runc qemu libvirt-dev libvirt-daemon libguestfs-tools \
        linux-image-amd64 \
        libarchive-tools \
        lftp lz4 zstd curl jq

# Create an unprivileged user:
RUN useradd -m -d /home/clipos -U -G users clipos

# This unprivileged user is not so unprivileged because it can still use sudo
# to get root privileges within the container.
# This strangeness is explained by the fact that cosmk automatically recalls
# itself through sudo to get root privileges but still lower its running
# privileges for sections of code that do not require root permissions (see the
# ElevatedPrivileges class and its usage in the cosmk Python project for
# further details).
RUN echo "clipos ALL=(ALL:ALL) NOPASSWD: ALL" \
        > /etc/sudoers.d/user-without-passwd \
        && chmod 0440 /etc/sudoers.d/user-without-passwd

# Drop to non-root user and change working directory to its homedir:
USER clipos
WORKDIR /home/clipos

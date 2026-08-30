# SPDX-FileCopyrightText: 2022-2026 David Bensoussan
# SPDX-License-Identifier: Apache-2.0

# Builds this package as a standalone ROS 2 workspace — the same `colcon build` a
# downstream project's own CI/dev environment runs after `vcs import`-ing this repo.
# Verifies this repo builds clean on its own; ros2_data_collection's own CI builds it
# again as a fetched dependency (its network-isolation check there is what actually
# proves the live-fetch-needs-network design this repo's README documents — nothing
# to duplicate here).
#
# Podman, not Docker (see ros2_data_collection's CLAUDE.md "Containers: Podman, not
# Docker"): fully-qualified base image, `Containerfile` not `Dockerfile`.

ARG ROS_DISTRO=jazzy
FROM docker.io/library/ros:${ROS_DISTRO}-ros-base

ARG APT_CACHEBUST=unknown
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /root/ws
COPY . src/aws_sdk_vendor

# `vcs` (python3-vcstool) is what ament_vendor()'s VCS_TYPE git path shells out to;
# rosdep resolves it via ament_cmake_vendor_package's own rosdep key instead of
# installing it directly here. `AWS_SDK_BUILD_ONLY` build-arg lets CI (or a local
# `podman build --build-arg AWS_SDK_BUILD_ONLY=...`) exercise a non-default service
# without editing CMakeLists.txt.
ARG AWS_SDK_BUILD_ONLY=s3
RUN echo "apt cache bust: ${APT_CACHEBUST}" && \
    apt-get -q update && \
    DEBIAN_FRONTEND=noninteractive \
    rosdep update --include-eol-distros && \
    rosdep install -y --from-paths src --ignore-src --rosdistro "${ROS_DISTRO}" --as-root=apt:false && \
    # shellcheck disable=SC1091
    . "/opt/ros/${ROS_DISTRO}/setup.sh" && \
    colcon build --packages-select aws_sdk_vendor \
      --cmake-args "-DAWS_SDK_BUILD_ONLY=${AWS_SDK_BUILD_ONLY}" \
      --event-handlers desktop_notification- status- && \
    rm -rf /var/lib/apt/lists/*

# SPDX-FileCopyrightText: 2022-2026 David Bensoussan
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.16)
project(aws_sdk_vendor)

find_package(ament_cmake REQUIRED)
find_package(ament_cmake_vendor_package REQUIRED)

# Pinned to the tag verified working against RustFS (PutObject + multipart) before
# adoption — see ros2_data_collection's ADR-0007 / Phase 2 verification. Bump this
# (and <version> in package.xml) to move versions; see README.md.
set(AWS_SDK_VERSION 1.11.600)

# Which AWS SDK for C++ service clients to build, forwarded verbatim to aws-sdk-cpp's
# own -DBUILD_ONLY. Defaults to just `s3` — all ros2_data_collection's Bridge Uploader
# needs (ADR-0007) — but this package has no consumer-specific content otherwise, so a
# downstream project needing other services shouldn't have to fork it just to change
# one CMake option. Override with a normal CMake list, e.g.
# `--cmake-args -DAWS_SDK_BUILD_ONLY="s3;dynamodb"` — see README.md.
set(AWS_SDK_BUILD_ONLY "s3" CACHE STRING
  "AWS SDK for C++ service client(s) to build (aws-sdk-cpp's own -DBUILD_ONLY values, \
semicolon-separated for more than one).")

# CMAKE_ARGS is itself a CMake list (ament_vendor()'s own multi-value keyword), so a
# semicolon inside one of its entries — from a multi-service AWS_SDK_BUILD_ONLY value —
# would otherwise be indistinguishable from an entry separator by the time it reaches
# ExternalProject_Add's own CMAKE_ARGS list; verified concretely (a plain quoted
# "-DBUILD_ONLY=${AWS_SDK_BUILD_ONLY}" still silently splits "s3;dynamodb" into two
# unrelated arguments). $<SEMICOLON> is CMake's documented escape for exactly this:
# it survives every intermediate list operation as four literal characters and is
# resolved back to a real ';' only when ExternalProject_Add evaluates the generator
# expression for the actual configure-step command line.
string(REPLACE ";" "$<SEMICOLON>" _aws_sdk_build_only_escaped "${AWS_SDK_BUILD_ONLY}")

# Live git fetch at colcon-build time via ament_cmake_vendor_package's ament_vendor()
# macro — the same idiom zmqpp_vendor/tinyxml_vendor/yaml_cpp_vendor already use
# successfully on the real ROS buildfarm (see ros2_data_collection's
# docs/adr/0012-aws-sdk-vendor-flattened-source.md). Its VCS_TYPE git path resolves
# through `vcs import --recursive`, which recurses aws-sdk-cpp's one top-level
# submodule (crt/aws-crt-cpp) and that submodule's own chain in full — including
# crt/s2n's unrelated CBMC formal-verification model, harmless to fetch with real
# network available and not worth excluding via a hand-rolled patch step.
#
# BUILD_DEPS=ON (the default) vendors the aws-c-* / aws-crt-cpp dependency chain from
# the recursed submodules, so the only external system libraries needed are
# curl/openssl/zlib (the package.xml build_depends) regardless of AWS_SDK_BUILD_ONLY.
# Unlike AWS_SDK_BUILD_ONLY above, the remaining CMAKE_ARGS below aren't exposed as
# their own cache variables — zlib request compression, testing, and PIC are fixed
# choices this package makes for its own default services (just `s3`), not settings a
# downstream project overriding AWS_SDK_BUILD_ONLY can currently reach from outside;
# widen this file's own CMAKE_ARGS list if a service that needs one of them shows up.
#
# GLOBAL_HOOK + an explicit CMAKE_BUILD_TYPE: dc_bridge (the real downstream
# consumer, in ros2_data_collection) never calls find_package(aws_sdk_vendor) itself
# — it only find_package(AWSSDK)s, expecting colcon to have already put this
# package's install prefix on CMAKE_PREFIX_PATH. GLOBAL_HOOK is what installs that as
# an environment hook (applied to every downstream package's build unconditionally)
# rather than a CMake config-extra a consumer would only pick up by
# find_package()-ing this vendor package first. Pinning CMAKE_BUILD_TYPE here (rather
# than relying on whatever the outer colcon invocation passes down) keeps the
# vendored SDK's own build deterministic regardless of how aws_sdk_vendor itself is
# invoked (e.g. a package-only `colcon build --packages-select aws_sdk_vendor` step,
# which passes no --cmake-args of its own).
ament_vendor(aws_sdk_cpp_vendor
  GLOBAL_HOOK
  VCS_TYPE git
  VCS_URL https://github.com/aws/aws-sdk-cpp.git
  VCS_VERSION ${AWS_SDK_VERSION}
  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=Release
    "-DBUILD_ONLY=${_aws_sdk_build_only_escaped}"
    -DENABLE_TESTING=OFF
    -DAUTORUN_UNIT_TESTS=OFF
    -DENABLE_ZLIB_REQUEST_COMPRESSION=OFF
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
)

ament_package()

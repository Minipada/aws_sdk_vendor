# aws_sdk_vendor

A ROS 2 `ament_cmake` package that builds the [AWS SDK for C++](https://github.com/aws/aws-sdk-cpp)
from a pinned upstream git tag, fetched live at `colcon build` time via
`ament_cmake_vendor_package`'s `ament_vendor()` macro (`VCS_TYPE git`) — the same idiom
`zmqpp_vendor`/`tinyxml_vendor`/`yaml_cpp_vendor` already use successfully on the real
ROS buildfarm. No AWS SDK source is vendored or committed anywhere in this repo. Builds
just the `s3` service client by default — override `AWS_SDK_BUILD_ONLY` for others; see
"Building other AWS services" below.

It exists to provide the AWS SDK for the [DC (`ros2_data_collection`)](https://github.com/Minipada/ros2_data_collection)
pipeline, where it's the object-storage client the Bridge's Uploader (`dc_bridge`) uses.
See that repo's [ADR-0007](https://github.com/Minipada/ros2_data_collection/blob/jazzy/docs/adr/0007-bridge-returns-to-cpp.md)
and [ADR-0012](https://github.com/Minipada/ros2_data_collection/blob/jazzy/docs/adr/0012-aws-sdk-vendor-flattened-source.md)
for why the AWS SDK was chosen and why this package fetches it live rather than
vendoring flattened source (a design this repo briefly held and reverted — see git
history).

## Why a separate repo

This package's own content is small — a `CMakeLists.txt` and a `package.xml`, nothing
vendored — so, unlike `vector_vendor` (whose split was about isolating ~106MB/bump of
binary growth from `ros2_data_collection`'s git history), there's no bloat this split
avoids. It lives here anyway, alongside `vector_vendor`, so every vendor package DC
pulls in via `.repos` follows the same layout and the same bump/release workflow,
rather than special-casing the one that happens to be small.

## Usage

Pull this repo into a ROS 2 workspace alongside `ros2_data_collection` (e.g. via a
`.repos` file and `vcs import`), then `colcon build` as usual — network access is
required at build time (this package fetches aws-sdk-cpp live; see the ADRs above for
why that's fine on the real ROS buildfarm).

```sh
colcon build --packages-select aws_sdk_vendor
```

### Building other AWS services

`ros2_data_collection` only needs `s3`, but this package builds whatever
`AWS_SDK_BUILD_ONLY` (a normal, semicolon-separated CMake list — the same syntax
aws-sdk-cpp's own `BUILD_ONLY` option takes) names:

```sh
colcon build --packages-select aws_sdk_vendor --cmake-args -DAWS_SDK_BUILD_ONLY="s3;dynamodb"
```

Everything else this package fixes (zlib request compression off, testing off,
position-independent code on) is this package's own default, not something
`AWS_SDK_BUILD_ONLY` alone changes — widen `CMakeLists.txt`'s own `CMAKE_ARGS` list
(a PR welcome) if a service you need depends on one of them.

### Bumping the vendored AWS SDK version

1. Update `AWS_SDK_VERSION` in `CMakeLists.txt` and `<version>` in `package.xml` to the
   new upstream tag.
2. `colcon build --packages-select aws_sdk_vendor` from a clean workspace to confirm the
   new tag still builds `-DBUILD_ONLY=s3` cleanly (aws-sdk-cpp's CMake options and
   `crt/aws-crt-cpp`'s submodule chain occasionally change between releases).
3. Run `reuse lint` and fix anything it flags, then tag the commit `v<version>`.
4. In `ros2_data_collection`, bump the pinned `version:` in `ros2_data_collection.repos`
   to match.

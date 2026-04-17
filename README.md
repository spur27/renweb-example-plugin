# My RenWeb Plugin

A RenWeb plugin.

## Source layout

```
my_renweb_plugin/
├── build/
│   ├── renweb-<version>-<os>-<arch>  # downloaded engine executable
│   ├── info.json                     # minimal launch config
│   ├── config.json
│   ├── content/test/index.html       # plugin test harness page
│   └── plugins/                      # compiled plugin output (per arch)
├── release/                          # output from build_for_release.sh
├── external/
│   └── boost-json/                   # pinned Boost.JSON submodule (boost-1.90.0)
├── include/
│   ├── plugin.hpp          # RenWeb Plugin base class (fetched from engine)
│   └── my_renweb_plugin.hpp   # Plugin class declaration
├── src/
│   └── my_renweb_plugin.cpp   # Plugin implementation (defines name + version)
├── build_all_archs.sh      # Build for all OS/arch targets
├── build_for_release.sh    # Build all arches, collect binaries into release/
└── makefile
```

## Dependencies

Requires a C++20-capable compiler and the **Boost** development headers  
(Boost.JSON is compiled into the plugin via `BOOST_JSON_SOURCE`, so no
prebuilt Boost libraries are required for plugin builds).

This template pins the expected Boost ABI to **Boost 1.90.0**
(`BOOST_VERSION=109000`) to avoid runtime crashes from mismatched C++ ABI.
If you intentionally need another Boost version, override
`REQUIRED_BOOST_VERSION` in the make invocation and ensure the RenWeb engine
was compiled against the same version.

| Platform | Command |
|----------|---------|
| **Ubuntu / Debian** | `sudo apt install libboost-dev` |
| **Fedora / RHEL** | `sudo dnf install boost-devel` |
| **Arch Linux** | `sudo pacman -S boost` |
| **openSUSE** | `sudo zypper install boost-devel` |
| **Alpine Linux** | `apk add boost-dev` |
| **macOS (Homebrew)** | `brew install boost` |
| **Windows (vcpkg)** | `vcpkg install boost-json:x64-windows` then add the vcpkg include path |
| **Windows (manual)** | Download from [boost.org](https://www.boost.org/users/download/) and add the extracted folder to `CPATH` or your IDE include paths |

## Building

```sh
# Linux / macOS — release
make

# Linux / macOS — debug
make TARGET=debug

# Cross-compile for ARM64 on Linux
make TOOLCHAIN=aarch64-linux-gnu

# Windows (MinGW or MSVC Developer Prompt)
make

# Intentional override (only if engine uses the same Boost version)
make REQUIRED_BOOST_VERSION=109000
```

Output: `<internal_name>-<version>-<os>-<arch>.so` (or `.dll` / `.dylib`)

Run `make info` to see the resolved build configuration.

### Multi-architecture builds

```sh
./build_all_archs.sh         # build all supported OS/arch targets
./build_for_release.sh       # build all arches and collect output into ./release/
```

## Installing

Copy the built library into your RenWeb project's `build/plugins/` directory.

## Usage in JavaScript

> Plugin functions are bound as `BIND_plugin_<internal_name>_<function>` in the JS engine.

```js
// Square a number
const sq = await BIND_plugin_my_renweb_plugin_square(7);   // → 49

// Factorial
const fact = await BIND_plugin_my_renweb_plugin_factorial(5);  // → 120

// Reverse a string (strings must be encoded with Utils.encode)
const rev = await BIND_plugin_my_renweb_plugin_reverse_string(Utils.encode("Hello"));  // → "olleH"
```

## API

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `square` | `number` | `number` | Returns the square of the input |
| `factorial` | `number` | `number` | Returns n! via the gamma function |
| `reverse_string` | `Utils.encode(string)` | `string` | Returns the reversed string |

## License

BSL 1.0

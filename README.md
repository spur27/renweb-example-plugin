# RenWeb Example Plugin

An example plugin used for testing purposes.

## Source layout

```
renweb_example_plugin/
├── build/
│   ├── renweb-<version>-<os>-<arch>  # downloaded engine executable
│   ├── info.json                     # minimal launch config
│   ├── config.json
│   ├── content/test/index.html       # plugin test harness page
│   └── plugins/                      # compiled plugin output (per arch)
├── release/                          # output from build_for_release.sh
├── include/
│   ├── plugin.hpp          # RenWeb Plugin base class (fetched from engine)
│   └── renweb_example_plugin.hpp   # Plugin class declaration
├── src/
│   └── renweb_example_plugin.cpp   # Plugin implementation (defines name + version)
├── build_all_archs.sh      # Build for all OS/arch targets
├── build_for_release.sh    # Build all arches, collect binaries into release/
└── makefile
```

## Dependencies

Requires a C++17-capable compiler and the **Boost** development headers  
(Boost.JSON is compiled statically into the plugin via `#include <boost/json/src.hpp>` —
no separate `libboost_json` needed at runtime).

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
const sq = await BIND_plugin_renweb_example_plugin_square(7);   // → 49

// Factorial
const fact = await BIND_plugin_renweb_example_plugin_factorial(5);  // → 120

// Reverse a string (strings must be encoded with Utils.encode)
const rev = await BIND_plugin_renweb_example_plugin_reverse_string(Utils.encode("Hello"));  // → "olleH"
```

## API

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `square` | `number` | `number` | Returns the square of the input |
| `factorial` | `number` | `number` | Returns n! via the gamma function |
| `reverse_string` | `Utils.encode(string)` | `string` | Returns the reversed string |

## License

BSL 1.0

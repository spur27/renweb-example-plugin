#!/usr/bin/env bash
# build_all_archs.sh — build plugin for all supported architectures
#
# Usage:
#   ./build_all_archs.sh [--arch <arch>] ...
#
# On Linux:   builds all 13 toolchain architectures (requires cross-compilers)
# On macOS:   builds arm64 + x86_64, then creates a universal .dylib via lipo
# On Windows: builds x64 + x86 + arm64 via MSVC (requires VS 2022)

set -e

RESET=$(printf '\033[0m')
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
MAGENTA=$(printf '\033[35m')
CYAN=$(printf '\033[36m')
BOLD=$(printf '\033[1m')

LINUX_TOOLCHAINS="x86_64-linux-gnu i686-linux-gnu aarch64-linux-gnu arm-linux-gnueabihf mips-linux-gnu mipsel-linux-gnu mips64-linux-gnuabi64 mips64el-linux-gnuabi64 powerpc-linux-gnu powerpc64-linux-gnu riscv64-linux-gnu s390x-linux-gnu sparc64-linux-gnu"

PLUGIN_NAME_DISPLAY=$(grep -hE -A5 ': (RenWeb::)?Plugin\b' src/*.cpp 2>/dev/null | grep -o '"[^"]*"' | sed -n '2p' | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
if [ -z "$PLUGIN_NAME_DISPLAY" ]; then
    PLUGIN_NAME_DISPLAY=$(basename "$PWD")
fi

print_header()  { echo "${CYAN}${BOLD}========================================${RESET}"; echo "${CYAN}${BOLD}$1${RESET}"; echo "${CYAN}${BOLD}========================================${RESET}"; }
print_info()    { echo "${GREEN}${BOLD}[INFO]${RESET} $1"; }
print_warning() { echo "${YELLOW}${BOLD}[WARN]${RESET} $1"; }
print_error()   { echo "${RED}${BOLD}[ERROR]${RESET} $1"; }
print_success() { echo "${GREEN}${BOLD}[SUCCESS]${RESET} $1"; }
print_building(){ echo "${MAGENTA}${BOLD}[BUILD]${RESET} Building for ${CYAN}$1${RESET} (${YELLOW}$2${RESET})"; }

command_exists()  { command -v "$1" >/dev/null 2>&1; }
toolchain_exists(){ command_exists "$1-gcc" && command_exists "$1-g++"; }

normalize_arch() {
    case "$1" in
        x86_64|x64|amd64)              echo "x86_64"    ;;
        x86_32|x86|i686|i386|ia32)    echo "x86_32"    ;;
        arm64|aarch64)                 echo "arm64"     ;;
        arm32|armhf|armv7|armv7l)     echo "arm32"     ;;
        mips32|mips)                   echo "mips32"    ;;
        mips32el|mipsel)               echo "mips32el"  ;;
        mips64)                        echo "mips64"    ;;
        mips64el)                      echo "mips64el"  ;;
        powerpc32|ppc|ppc32)           echo "powerpc32" ;;
        powerpc64|ppc64)               echo "powerpc64" ;;
        riscv64)                       echo "riscv64"   ;;
        s390x)                         echo "s390x"     ;;
        sparc64)                       echo "sparc64"   ;;
        *)                             echo "$1"        ;;
    esac
}
FILTER_ARCHS=""
arch_matches() {
    [ -z "$FILTER_ARCHS" ] && return 0
    for _fa in $FILTER_ARCHS; do [ "$_fa" = "$1" ] && return 0; done
    return 1
}
toolchain_to_arch() {
    case "$1" in
        arm-linux-gnueabihf)         echo "arm32"     ;;
        aarch64-linux-gnu)           echo "arm64"     ;;
        i686-linux-gnu)              echo "x86_32"    ;;
        x86_64-linux-gnu)            echo "x86_64"    ;;
        mips-linux-gnu)              echo "mips32"    ;;
        mipsel-linux-gnu)            echo "mips32el"  ;;
        mips64-linux-gnuabi64)       echo "mips64"    ;;
        mips64el-linux-gnuabi64)     echo "mips64el"  ;;
        powerpc-linux-gnu)           echo "powerpc32" ;;
        powerpc64-linux-gnu)         echo "powerpc64" ;;
        riscv64-linux-gnu)           echo "riscv64"   ;;
        s390x-linux-gnu)             echo "s390x"     ;;
        sparc64-linux-gnu)           echo "sparc64"   ;;
        *)                           echo "$1"        ;;
    esac
}

build_for_toolchain() {
    local toolchain=$1 arch_name=$2
    print_building "$arch_name" "$toolchain"
    if make clear TOOLCHAIN="$toolchain" TARGET=release; then
        if make TOOLCHAIN="$toolchain" TARGET=release -j$(nproc 2>/dev/null || echo 4); then
            print_success "Built $arch_name"; return 0
        else
            print_error "Failed to build $arch_name"; return 1
        fi
    else
        print_error "Failed to clear for $arch_name"; return 1
    fi
}

build_native() {
    local arch_name=$1
    print_building "$arch_name" "native"
    if make clear TARGET=release; then
        if make TARGET=release -j$(nproc 2>/dev/null || echo 4); then
            print_success "Built native $arch_name"; return 0
        else
            print_error "Failed to build native"; return 1
        fi
    else
        print_error "Failed to clear native build"; return 1
    fi
}

detect_os() {
    case "$(uname -s)" in
        Linux*)          OS_NAME="Linux";   HOST_ARCH="$(uname -m)" ;;
        Darwin*)         OS_NAME="macOS";   HOST_ARCH="$(uname -m)" ;;
        CYGWIN*|MINGW*|MSYS*) OS_NAME="Windows" ;;
        *) print_error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
}

build_linux() {
    local success_count=0 fail_count=0 total_count=0
    print_header "Building ${PLUGIN_NAME_DISPLAY} for Linux (13 architectures)"
    print_info "Host: $HOST_ARCH"
    echo ""

    local host_toolchain=""
    case "$HOST_ARCH" in
        x86_64)        host_toolchain="x86_64-linux-gnu" ;;
        i686|i386)     host_toolchain="i686-linux-gnu" ;;
        aarch64|arm64) host_toolchain="aarch64-linux-gnu" ;;
        armv7l|armhf)  host_toolchain="arm-linux-gnueabihf" ;;
        mips)          host_toolchain="mips-linux-gnu" ;;
        mipsel)        host_toolchain="mipsel-linux-gnu" ;;
        mips64)        host_toolchain="mips64-linux-gnuabi64" ;;
        mips64el)      host_toolchain="mips64el-linux-gnuabi64" ;;
        ppc)           host_toolchain="powerpc-linux-gnu" ;;
        ppc64)         host_toolchain="powerpc64-linux-gnu" ;;
        riscv64)       host_toolchain="riscv64-linux-gnu" ;;
        s390x)         host_toolchain="s390x-linux-gnu" ;;
        sparc64)       host_toolchain="sparc64-linux-gnu" ;;
    esac

    local native_arch
    native_arch=$(normalize_arch "$HOST_ARCH")
    if arch_matches "$native_arch"; then
        total_count=$((total_count + 1))
        if build_native "native ($HOST_ARCH)"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        echo ""
    else
        print_info "Skipping native ($HOST_ARCH) — not in arch filter"
        echo ""
    fi

    for toolchain in $LINUX_TOOLCHAINS; do
        if [ "$toolchain" = "$host_toolchain" ]; then
            print_info "Skipping $toolchain (already built natively)"
            continue
        fi
        local tc_arch
        tc_arch=$(toolchain_to_arch "$toolchain")
        if ! arch_matches "$tc_arch"; then
            print_info "Skipping $toolchain ($tc_arch) — not in arch filter"
            echo ""
            continue
        fi
        total_count=$((total_count + 1))
        if toolchain_exists "$toolchain"; then
            if build_for_toolchain "$toolchain" "$toolchain"; then
                success_count=$((success_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
        else
            print_warning "Toolchain $toolchain not found, skipping"
            fail_count=$((fail_count + 1))
        fi
        echo ""
    done

    print_header "Build Summary"
    echo "${GREEN}Successful: ${BOLD}${success_count}${RESET}  ${RED}Failed: ${BOLD}${fail_count}${RESET}  ${CYAN}Total: ${BOLD}${total_count}${RESET}"
    if [ $success_count -gt 0 ]; then
        print_info "Output: ./build/plugins/"
        ls -lh build/plugins/ 2>/dev/null | grep '\.so$' || true
    fi
}

build_macos() {
    local success_count=0 fail_count=0
    print_header "Building ${PLUGIN_NAME_DISPLAY} for macOS (arm64 + x86_64)"
    echo ""

    command_exists clang++ || { print_error "clang++ not found"; return 1; }
    local ncpu=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

    for arch in arm64 x86_64; do
        if ! arch_matches "$arch"; then
            print_info "Skipping $arch — not in arch filter"
            echo ""
            continue
        fi
        print_building "$arch" "clang++ -arch $arch"
        make clear >/dev/null 2>&1 || true
        if ARCH="$arch" ARCH_FLAGS="-arch $arch" make TARGET=release -j$ncpu; then
            print_success "Built $arch"
            success_count=$((success_count + 1))
        else
            print_error "Failed $arch"
            fail_count=$((fail_count + 1))
        fi
        echo ""
    done

    if [ $success_count -eq 2 ]; then
        print_info "Creating universal dylib (arm64 + x86_64)..."
        local arm64_lib=$(ls build/plugins/*-macos-arm64.dylib 2>/dev/null | head -1)
        local x86_lib=$(ls build/plugins/*-macos-x86_64.dylib 2>/dev/null | head -1)
        if [ -n "$arm64_lib" ] && [ -n "$x86_lib" ]; then
            local universal="${arm64_lib/arm64/universal}"
            if lipo -create "$arm64_lib" "$x86_lib" -output "$universal" 2>/dev/null; then
                print_success "Universal dylib: $universal"
                lipo -info "$universal"
            else
                print_warning "lipo failed — universal binary not created"
            fi
        fi
    fi

    print_header "Build Summary"
    echo "${GREEN}Successful: ${BOLD}${success_count}${RESET}  ${RED}Failed: ${BOLD}${fail_count}${RESET}"
    if [ $success_count -gt 0 ]; then
        print_info "Output: ./build/plugins/"
        ls -lh build/plugins/ 2>/dev/null | grep '\.dylib$' || true
    fi
}

build_windows() {
    local success_count=0 fail_count=0
    print_header "Building ${PLUGIN_NAME_DISPLAY} for Windows (x86_64 + x86_32 + arm64)"
    echo ""

    local vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
    [ -f "$vswhere" ] || vswhere="/c/Program Files/Microsoft Visual Studio/Installer/vswhere.exe"

    local vs_path=""
    [ -f "$vswhere" ] && vs_path=$("$vswhere" -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>/dev/null | head -1)
    [ -z "$vs_path" ] && vs_path="/c/Program Files/Microsoft Visual Studio/2022/Community"
    [ -d "$vs_path" ] || { print_error "Visual Studio 2022 not found"; return 1; }

    local vcvars_path="$vs_path/VC/Auxiliary/Build"
    [ -d "$vcvars_path" ] || { print_error "vcvars path not found: $vcvars_path"; return 1; }

    for arch_spec in "x86_64:vcvars64.bat" "x86_32:vcvars32.bat" "arm64:vcvarsamd64_arm64.bat"; do
        IFS=':' read -r make_arch vcvars <<< "$arch_spec"
        if ! arch_matches "$make_arch"; then
            print_info "Skipping $make_arch — not in arch filter"
            echo ""
            continue
        fi
        print_building "$make_arch" "$vcvars"
        local vcvars_win=$(cygpath -w "$vcvars_path/$vcvars" 2>/dev/null || echo "$vcvars_path\\$vcvars")
        rm -rf src/.build
        local temp_bat=$(mktemp --suffix=.bat)
        cat > "$temp_bat" <<BATEOF
@echo off
call "$vcvars_win" >nul 2>&1
if errorlevel 1 exit /b 1
make ARCH=$make_arch TARGET=release -j4
BATEOF
        if cmd //c "$(cygpath -w "$temp_bat" 2>/dev/null || echo "$temp_bat")" 2>&1; then
            print_success "Built $make_arch"
            success_count=$((success_count + 1))
        else
            print_error "Failed $make_arch"
            fail_count=$((fail_count + 1))
        fi
        rm -f "$temp_bat"
        echo ""
    done

    print_header "Build Summary"
    echo "${GREEN}Successful: ${BOLD}${success_count}${RESET}  ${RED}Failed: ${BOLD}${fail_count}${RESET}"
    if [ $success_count -gt 0 ]; then
        print_info "Output: ./build/plugins/"
        ls -lh build/plugins/ 2>/dev/null | grep '\.dll$' || true
    fi
    if [ $fail_count -gt 0 ]; then
        print_warning "ARM64 failures may need: MSVC v143 ARM64 build tools (via VS Installer)"
    fi
}

main() {
    while [ $# -gt 0 ]; do
        case $1 in
            --arch|-a)
                if [ -z "${2:-}" ] || [ "${2#-}" != "$2" ]; then
                    print_error "--arch requires an architecture name"; exit 1
                fi
                _fa=$(normalize_arch "$2")
                FILTER_ARCHS="${FILTER_ARCHS:+$FILTER_ARCHS }$_fa"
                shift 2 ;;
            --help|-h)
                echo "Usage: $0 [--arch <arch>]..."
                echo "Builds the ${PLUGIN_NAME_DISPLAY} plugin for all architectures on the current OS."
                echo "  --arch <arch>  Only build for the specified architecture (repeatable)"
                echo "  Linux:   13 cross-compiled .so files (requires toolchains)"
                echo "  macOS:   arm64 + x86_64 .dylib files + universal binary"
                echo "  Windows: x86_64 + x86_32 + arm64 .dll files (requires VS 2022)"
                exit 0 ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    detect_os
    print_header "${PLUGIN_NAME_DISPLAY} Plugin — Multi-Architecture Build"
    print_info "OS: $OS_NAME"
    echo ""

    command_exists make || { print_error "make not found"; exit 1; }
    make clean

    case "$OS_NAME" in
        Linux)   build_linux ;;
        macOS)   build_macos ;;
        Windows) build_windows ;;
    esac
}

main "$@"

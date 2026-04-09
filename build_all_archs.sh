#!/usr/bin/env bash
# build_all_archs.sh — build renweb_example_plugin plugin for all supported architectures
#
# Usage:
#   ./build_all_archs.sh
#
# On Linux:   builds all 13 toolchain architectures (requires cross-compilers)
# On macOS:   builds arm64 + x86_64, then creates a universal .dylib via lipo
# On Windows: builds x64 + x86 + arm64 via MSVC (requires VS 2022)

set -e

RESET='\033[0m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
CYAN='\033[36m'
BOLD='\033[1m'

LINUX_TOOLCHAINS="x86_64-linux-gnu i686-linux-gnu aarch64-linux-gnu arm-linux-gnueabihf mips-linux-gnu mipsel-linux-gnu mips64-linux-gnuabi64 mips64el-linux-gnuabi64 powerpc-linux-gnu powerpc64-linux-gnu riscv64-linux-gnu s390x-linux-gnu sparc64-linux-gnu"

print_header()  { echo -e "$CYAN$BOLD========================================$RESET"; echo -e "$CYAN$BOLD$1$RESET"; echo -e "$CYAN$BOLD========================================$RESET"; }
print_info()    { echo -e "$GREEN$BOLD[INFO]$RESET $1"; }
print_warning() { echo -e "$YELLOW$BOLD[WARN]$RESET $1"; }
print_error()   { echo -e "$RED$BOLD[ERROR]$RESET $1"; }
print_success() { echo -e "$GREEN$BOLD[SUCCESS]$RESET $1"; }
print_building(){ echo -e "$MAGENTA$BOLD[BUILD]$RESET Building for $CYAN$1$RESET ($YELLOW$2$RESET)"; }

command_exists()  { command -v "$1" >/dev/null 2>&1; }
toolchain_exists(){ command_exists "$1-gcc" && command_exists "$1-g++"; }

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
    print_header "Building renweb_example_plugin for Linux (13 architectures)"
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

    total_count=$((total_count + 1))
    if build_native "native ($HOST_ARCH)"; then
        success_count=$((success_count + 1))
    else
        fail_count=$((fail_count + 1))
    fi
    echo ""

    for toolchain in $LINUX_TOOLCHAINS; do
        if [ "$toolchain" = "$host_toolchain" ]; then
            print_info "Skipping $toolchain (already built natively)"
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
    echo -e "$GREEN Successful: $BOLD$success_count$RESET  $RED Failed: $BOLD$fail_count$RESET  $CYAN Total: $BOLD$total_count$RESET"
    if [ $success_count -gt 0 ]; then
        print_info "Output: ./build/plugins/"
        ls -lh build/plugins/ 2>/dev/null | grep '\.so$' || true
    fi
}

build_macos() {
    local success_count=0 fail_count=0
    print_header "Building renweb_example_plugin for macOS (arm64 + x86_64)"
    echo ""

    command_exists clang++ || { print_error "clang++ not found"; return 1; }
    local ncpu=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

    for arch in arm64 x86_64; do
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
    echo -e "$GREEN Successful: $BOLD$success_count$RESET  $RED Failed: $BOLD$fail_count$RESET"
    if [ $success_count -gt 0 ]; then
        print_info "Output: ./build/plugins/"
        ls -lh build/plugins/ 2>/dev/null | grep '\.dylib$' || true
    fi
}

build_windows() {
    local success_count=0 fail_count=0
    print_header "Building renweb_example_plugin for Windows (x64 + x86 + arm64)"
    echo ""

    local vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
    [ -f "$vswhere" ] || vswhere="/c/Program Files/Microsoft Visual Studio/Installer/vswhere.exe"

    local vs_path=""
    [ -f "$vswhere" ] && vs_path=$("$vswhere" -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>/dev/null | head -1)
    [ -z "$vs_path" ] && vs_path="/c/Program Files/Microsoft Visual Studio/2022/Community"
    [ -d "$vs_path" ] || { print_error "Visual Studio 2022 not found"; return 1; }

    local vcvars_path="$vs_path/VC/Auxiliary/Build"
    [ -d "$vcvars_path" ] || { print_error "vcvars path not found: $vcvars_path"; return 1; }

    for arch_spec in "x64:x86_64:vcvars64.bat" "x86:x86_32:vcvars32.bat" "arm64:arm64:vcvarsamd64_arm64.bat"; do
        IFS=':' read -r win_arch make_arch vcvars <<< "$arch_spec"
        print_building "$win_arch" "$vcvars"
        local vcvars_win=$(cygpath -w "$vcvars_path/$vcvars" 2>/dev/null || echo "$vcvars_path\\$vcvars")
        local temp_bat=$(mktemp --suffix=.bat)
        cat > "$temp_bat" <<BATEOF
@echo off
call "$vcvars_win" >nul 2>&1
if errorlevel 1 exit /b 1
make clear ARCH=$make_arch TARGET=release >nul 2>&1
if errorlevel 1 exit /b 1
make ARCH=$make_arch TARGET=release -j4
BATEOF
        if cmd //c "$(cygpath -w "$temp_bat" 2>/dev/null || echo "$temp_bat")" 2>&1; then
            print_success "Built $win_arch"
            success_count=$((success_count + 1))
        else
            print_error "Failed $win_arch"
            fail_count=$((fail_count + 1))
        fi
        rm -f "$temp_bat"
        echo ""
    done

    print_header "Build Summary"
    echo -e "$GREEN Successful: $BOLD$success_count$RESET  $RED Failed: $BOLD$fail_count$RESET"
    if [ $success_count -gt 0 ]; then
        print_info "Output: ./build/plugins/"
        ls -lh build/plugins/ 2>/dev/null | grep '\.dll$' || true
    fi
    if [ $fail_count -gt 0 ]; then
        print_warning "ARM64 failures may need: MSVC v143 ARM64 build tools (via VS Installer)"
    fi
}

main() {
    case "${1:-}" in
        --help|-h)
            echo "Usage: $0"
            echo "Builds the renweb_example_plugin plugin for all architectures on the current OS."
            echo "  Linux:   13 cross-compiled .so files (requires toolchains)"
            echo "  macOS:   arm64 + x86_64 .dylib files + universal binary"
            echo "  Windows: x64 + x86 + arm64 .dll files (requires VS 2022)"
            exit 0 ;;
        "") ;;
        *) print_error "Unknown option: $1"; exit 1 ;;
    esac

    detect_os
    print_header "renweb_example_plugin Plugin — Multi-Architecture Build"
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

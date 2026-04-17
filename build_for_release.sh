#!/usr/bin/env bash
# build_for_release.sh — collect all plugin binaries into ./release/
#
# Usage: ./build_for_release.sh [--arch <arch>] ...
#
# 1. Removes and recreates ./release/
# 2. Runs ./build_all_archs.sh (builds build/plugins/ for all platforms)
# 3. Moves every file from build/plugins/ into ./release/

set -e

RESET=$(printf '\033[0m')
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
CYAN=$(printf '\033[36m')
BOLD=$(printf '\033[1m')

normalize_arch() {
    case "$1" in
        x86_64|x64|amd64)              echo "x86_64"    ;;
        x86_32|x86|i686|i386|ia32)     echo "x86_32"    ;;
        arm64|aarch64)                  echo "arm64"     ;;
        arm32|armhf|armv7|armv7l)       echo "arm32"     ;;
        mips32|mips)                    echo "mips32"    ;;
        mips32el|mipsel)                echo "mips32el"  ;;
        mips64)                         echo "mips64"    ;;
        mips64el)                       echo "mips64el"  ;;
        powerpc32|ppc|ppc32)            echo "powerpc32" ;;
        powerpc64|ppc64)                echo "powerpc64" ;;
        riscv64)                        echo "riscv64"   ;;
        s390x)                          echo "s390x"     ;;
        sparc64)                        echo "sparc64"   ;;
        *)                              echo "$1"        ;;
    esac
}

RELEASE_DIR="./release"
PLUGINS_DIR="./build/plugins"

print_header()  { echo "${CYAN}${BOLD}========================================${RESET}"; echo "${CYAN}${BOLD}$1${RESET}"; echo "${CYAN}${BOLD}========================================${RESET}"; }
print_info()    { echo "${GREEN}${BOLD}[INFO]${RESET} $1"; }
print_warning() { echo "${YELLOW}${BOLD}[WARN]${RESET} $1"; }
print_error()   { echo "${RED}${BOLD}[ERROR]${RESET} $1" >&2; }
print_success() { echo "${GREEN}${BOLD}[SUCCESS]${RESET} $1"; }

ARCH_FLAGS=""
while [ $# -gt 0 ]; do
    case $1 in
        --arch|-a)
            if [ -z "$2" ] || [ "${2#-}" != "$2" ]; then
                print_error "--arch requires an architecture name"
                exit 1
            fi
            _fa=$(normalize_arch "$2")
            ARCH_FLAGS="${ARCH_FLAGS:+$ARCH_FLAGS }--arch $_fa"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--arch <arch>] ..."
            echo ""
            echo "  --arch <arch>, -a    Build only the specified architecture (repeatable)."
            echo "                       Accepts canonical names or common aliases."
            echo "                       Default: all architectures."
            exit 0 ;;
        *)
            print_error "Unknown option: $1"
            exit 1 ;;
    esac
done

print_header "Cleaning release directory"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
print_info "Ready: $RELEASE_DIR/"

print_header "Building all architectures"
# shellcheck disable=SC2086
bash ./build_all_archs.sh $ARCH_FLAGS

print_header "Collecting plugins"
plugin_count=0
if [ -d "$PLUGINS_DIR" ]; then
    for f in "$PLUGINS_DIR"/*; do
        [ -f "$f" ] || continue
        mv "$f" "$RELEASE_DIR/"
        print_info "$(basename "$f")"
        plugin_count=$((plugin_count + 1))
    done
else
    print_warning "build/plugins/ not found — build_all_archs.sh may have failed"
fi

echo ""
if [ $plugin_count -gt 0 ]; then
    print_success "$plugin_count plugin(s) ready in $RELEASE_DIR/"
    ls -lh "$RELEASE_DIR/"
else
    print_error "No plugins collected — check build_all_archs.sh output above"
    exit 1
fi

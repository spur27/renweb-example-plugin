#!/usr/bin/env bash
# build_for_release.sh — collect all plugin binaries into ./release/
#
# Usage: ./build_for_release.sh
#
# 1. Removes and recreates ./release/
# 2. Runs ./build_all_archs.sh (builds build/plugins/ for all platforms)
# 3. Moves every file from build/plugins/ into ./release/

set -e

RESET='\033[0m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
BOLD='\033[1m'

RELEASE_DIR="./release"
PLUGINS_DIR="./build/plugins"

print_header()  { echo -e "$CYAN$BOLD========================================$RESET"; echo -e "$CYAN$BOLD  $1$RESET"; echo -e "$CYAN$BOLD========================================$RESET"; }
print_info()    { echo -e "$GREEN$BOLD[INFO]$RESET $1"; }
print_warning() { echo -e "$YELLOW$BOLD[WARN]$RESET $1"; }
print_error()   { echo -e "$RED$BOLD[ERROR]$RESET $1" >&2; }
print_success() { echo -e "$GREEN$BOLD[SUCCESS]$RESET $1"; }

print_header "Cleaning release directory"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
print_info "Ready: $RELEASE_DIR/"

print_header "Building all architectures"
bash ./build_all_archs.sh

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

# =============================================================================
# RenWeb Example Plugin — RenWeb Plugin Makefile
# =============================================================================
# Usage:
#   make                          Build for current OS/arch (debug)
#   make TARGET=release           Build in release mode
#   make TOOLCHAIN=<triplet>      Cross-compile (Linux only, same triplets as
#                                 the engine makefile)
#   make ARCH=<arch>              Override the arch label in the output filename
#   make clear                    Remove only object files (between arch passes)
#   make clean                    Remove object files and build/plugins/ output
#   make info                     Print build configuration
#   make help                     Show this help
#
# Plugin name and version are read from the RenWeb::Plugin constructor in
# src/*.cpp — the second string param is the internal_name; third is version.
# Output: <internal_name>-<version>-<os>-<arch>.<ext>
# =============================================================================

# -----------------------------------------------------------------------------
# Cross-compilation toolchain (Linux only)
# Supported triplets (same as engine makefile):
#   arm-linux-gnueabihf   aarch64-linux-gnu   i686-linux-gnu
#   mips-linux-gnu        mipsel-linux-gnu
#   mips64-linux-gnuabi64 mips64el-linux-gnuabi64
#   powerpc-linux-gnu     powerpc64-linux-gnu
#   riscv64-linux-gnu     s390x-linux-gnu     sparc64-linux-gnu
# -----------------------------------------------------------------------------
TOOLCHAIN :=
ifdef TOOLCHAIN
	CROSS_COMPILE := $(TOOLCHAIN)-
	SYSROOT       := --sysroot=/usr/$(TOOLCHAIN)
	ifeq ($(TOOLCHAIN),arm-linux-gnueabihf)
		ARCH := arm32
	else ifeq ($(TOOLCHAIN),aarch64-linux-gnu)
		ARCH := arm64
	else ifeq ($(TOOLCHAIN),i686-linux-gnu)
		ARCH := x86_32
	else ifeq ($(TOOLCHAIN),mips-linux-gnu)
		ARCH := mips32
	else ifeq ($(TOOLCHAIN),mipsel-linux-gnu)
		ARCH := mips32el
	else ifeq ($(TOOLCHAIN),mips64-linux-gnuabi64)
		ARCH := mips64
	else ifeq ($(TOOLCHAIN),mips64el-linux-gnuabi64)
		ARCH := mips64el
	else ifeq ($(TOOLCHAIN),powerpc-linux-gnu)
		ARCH := powerpc32
	else ifeq ($(TOOLCHAIN),powerpc64-linux-gnu)
		ARCH := powerpc64
	else ifeq ($(TOOLCHAIN),riscv64-linux-gnu)
		ARCH := riscv64
	else ifeq ($(TOOLCHAIN),s390x-linux-gnu)
		ARCH := s390x
	else ifeq ($(TOOLCHAIN),sparc64-linux-gnu)
		ARCH := sparc64
	else ifeq ($(TOOLCHAIN),x86_64-linux-gnu)
		ARCH := x86_64
	else
		ARCH := unknown
	endif
else
	CROSS_COMPILE :=
	SYSROOT       :=
endif

# -----------------------------------------------------------------------------
# Build target
# -----------------------------------------------------------------------------
ifndef TARGET
	TARGET := debug
endif

# -----------------------------------------------------------------------------
# OS / compiler / architecture detection
# -----------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	SHELL      := C:\Program Files\Git\usr\bin\sh.exe
	OS_NAME    := windows
	SHARED_EXT := .dll
	OBJ_EXT    := .obj
	OBJ_DIR    := src\\.build
	ifeq ($(RENWEB_VS_BOOTSTRAPPED),)
	CL_IN_PATH := $(shell which cl 2>/dev/null)
	ifeq ($(CL_IN_PATH),)
	NEED_VS_BOOTSTRAP := 1
	endif
	endif
	CXX      := cl
	CXXFLAGS := /std:c++17 /utf-8 /EHsc /W3 /FS /nologo
	ifeq ($(TARGET),debug)
		CXXFLAGS += /Zi /Od /MTd
		LDFLAGS  := /DEBUG
	else
		CXXFLAGS += /O2 /GL /GS- /Gy /MT
		LDFLAGS  := /LTCG /OPT:REF /OPT:ICF
	endif
	ifdef VSCMD_ARG_TGT_ARCH
		ifeq ($(VSCMD_ARG_TGT_ARCH),x64)
			ARCH    := x86_64
			LDFLAGS += /MACHINE:X64
		else ifeq ($(VSCMD_ARG_TGT_ARCH),x86)
			ARCH    := x86_32
			LDFLAGS += /MACHINE:X86
		else ifeq ($(VSCMD_ARG_TGT_ARCH),arm64)
			ARCH    := arm64
			LDFLAGS += /MACHINE:ARM64
		else
			ARCH    := x86_64
			LDFLAGS += /MACHINE:X64
		endif
	else ifndef ARCH
		ARCH    := x86_64
		LDFLAGS += /MACHINE:X64
	endif
else
	SHELL   := /bin/sh
	UNAME_S := $(shell uname -s)
	OBJ_EXT := .o
	OBJ_DIR := src/.build
	ifeq ($(UNAME_S),Darwin)
		OS_NAME      := macos
		SHARED_EXT   := .dylib
		SHARED_FLAGS := -dynamiclib
		CXX          := clang++
		CXXFLAGS     := -std=c++17 -MMD -MP -fPIC -mmacosx-version-min=10.15
		LDFLAGS      := -mmacosx-version-min=10.15
		ifeq ($(TARGET),debug)
			CXXFLAGS += -g -O0 -Wall -Wextra -Wno-missing-braces
		else
			CXXFLAGS += -O3 -flto
		endif
		ifdef ARCH_FLAGS
			CXXFLAGS += $(ARCH_FLAGS)
			LDFLAGS  += $(ARCH_FLAGS)
		endif
		ifndef ARCH
			UNAME_M := $(shell uname -m)
			ifeq ($(UNAME_M),arm64)
				ARCH := arm64
			else
				ARCH := x86_64
			endif
		endif
	else
		OS_NAME      := linux
		SHARED_EXT   := .so
		SHARED_FLAGS := -shared
		CXX          := $(CROSS_COMPILE)g++
		CXXFLAGS     := -std=c++17 -MMD -MP -fPIC -D_GNU_SOURCE
		ifeq ($(TARGET),debug)
			CXXFLAGS += $(SYSROOT) -g -O0 -Wall -Wextra -Wno-missing-braces
		else
			CXXFLAGS += $(SYSROOT) -O3 -flto
		endif
		ifdef TOOLCHAIN
			CXXFLAGS += -isystem /usr/$(TOOLCHAIN)/usr/local/include
			LDFLAGS  := --sysroot=/usr/$(TOOLCHAIN) -L/lib -L/lib64 -L/usr/lib -L/usr/lib64
		else
			LDFLAGS  :=
		endif
		ifndef ARCH
			UNAME_M := $(shell uname -m)
			ifeq ($(UNAME_M),x86_64)
				ARCH := x86_64
			else ifeq ($(UNAME_M),i686)
				ARCH := x86_32
			else ifeq ($(UNAME_M),aarch64)
				ARCH := arm64
			else ifeq ($(UNAME_M),armv7l)
				ARCH := arm32
			else
				ARCH := $(UNAME_M)
			endif
		endif
	endif
endif

# -----------------------------------------------------------------------------
# Utility — colored output (matches engine makefile conventions)
# -----------------------------------------------------------------------------
RESET   := \033[0m
RED     := \033[31m
GREEN   := \033[32m
YELLOW  := \033[33m
MAGENTA := \033[35m
CYAN    := \033[36m
BOLD    := \033[1m
define describe
	@printf "$(GREEN)$(BOLD)%s$(RESET) $(MAGENTA)%s$(RESET) $(GREEN)$(BOLD)%s$(RESET) $(MAGENTA)%s$(RESET)\n" "$(1)" "$(2)" "$(3)" "$(4)"
endef
define warn
	@printf "$(YELLOW)$(BOLD)%s$(RESET) $(MAGENTA)%s$(RESET) $(YELLOW)$(BOLD)%s$(RESET) $(MAGENTA)%s$(RESET)\n" "$(1)" "$(2)" "$(3)" "$(4)"
endef
define step
	@printf "$(CYAN)$(BOLD)%s$(RESET) $(MAGENTA)%s$(RESET) $(CYAN)$(BOLD)%s$(RESET) $(MAGENTA)%s$(RESET)\n" "$(1)" "$(2)" "$(3)" "$(4)"
endef

# -----------------------------------------------------------------------------
# Paths and plugin metadata
# Plugin name and version are read from the RenWeb::Plugin() constructor
# in src/*.cpp: the 2nd string param is internal_name; the 3rd is version.
# -----------------------------------------------------------------------------
BUILD_DIR      := build/plugins
SRC            := src/renweb_example_plugin.cpp
OBJ            := $(OBJ_DIR)/renweb_example_plugin$(OBJ_EXT)
PLUGIN_NAME    := $(shell grep -hE -A5 ': (RenWeb::)?Plugin\b' src/*.cpp 2>/dev/null | grep -o '"[^"]*"' | sed -n '2p' | tr -d '"' | xargs)
PLUGIN_VERSION := $(shell grep -hE -A5 ': (RenWeb::)?Plugin\b' src/*.cpp 2>/dev/null | grep -o '"[^"]*"' | sed -n '3p' | tr -d '"' | xargs)
OUT            := $(BUILD_DIR)/$(PLUGIN_NAME)-$(PLUGIN_VERSION)-$(OS_NAME)-$(ARCH)$(SHARED_EXT)

# =============================================================================
# VS auto-bootstrap (Windows only: runs when cl.exe is absent from PATH)
# Locates vcvarsall via vswhere, re-execs make with the VS environment set up.
# RENWEB_VS_BOOTSTRAPPED=1 prevents re-entry.
# =============================================================================
ifdef NEED_VS_BOOTSTRAP
VCVARS_BAT := vcvars64.bat
ifeq ($(ARCH),x86_32)
VCVARS_BAT := vcvars32.bat
else ifeq ($(ARCH),arm64)
VCVARS_BAT := vcvarsamd64_arm64.bat
endif
_VS_GOALS := $(if $(MAKECMDGOALS),$(MAKECMDGOALS),all)
_VS_VARS  := $(strip $(foreach v,TARGET ARCH,\
               $(if $(filter-out undefined default,$(origin $v)),$v=$($v))))
_vs_bootstrap:
	@VSWHERE="C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"; \
	if [ ! -f "$$VSWHERE" ]; then \
		printf "\033[31;1mError\033[0m cl.exe not in PATH and vswhere.exe not found.\n"; \
		exit 1; \
	fi; \
	TMP_VS="/tmp/_rw_plugin_vs.txt"; \
	printf "\033[36;1mBootstrapping\033[0m Locating Visual Studio toolchain...\n"; \
	"$$VSWHERE" -latest -products '*' \
		-requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
		-find "VC/Auxiliary/Build/$(VCVARS_BAT)" \
		> "$$TMP_VS" 2>/dev/null; \
	if [ ! -s "$$TMP_VS" ]; then \
		printf "\033[31;1mError\033[0m No VS C++ build tools found.\n"; \
		exit 1; \
	fi; \
	VCBAT=$$(tr -d '\r' < "$$TMP_VS" | head -1); \
	rm -f "$$TMP_VS"; \
	printf "\033[36;1mBootstrapping\033[0m Using: %s\n" "$$VCBAT"; \
	_esc=$$(printf '%s' "$$VCBAT" | sed 's/[^0-9A-Za-z]/^&/g'); \
	ENV_OUT=$$(MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
		cmd.exe /s /c " ; $$_esc && set" </dev/null 2>/dev/null | tr -d '\r'); \
	if [ -z "$$ENV_OUT" ]; then \
		printf "\033[31;1mError\033[0m cmd.exe returned empty output.\n"; \
		exit 1; \
	fi; \
	_vs_path=$$(printf '%s\n' "$$ENV_OUT" | grep -i '^Path=' | head -1 | cut -d= -f2-); \
	_vs_lib=$$(printf '%s\n' "$$ENV_OUT" | grep -i '^LIB=' | head -1 | cut -d= -f2-); \
	_vs_include=$$(printf '%s\n' "$$ENV_OUT" | grep -i '^INCLUDE=' | head -1 | cut -d= -f2-); \
	if [ -n "$$_vs_path" ]; then \
		_posix_path=$$(cygpath --path --unix "$$_vs_path" 2>/dev/null); \
		[ -n "$$_posix_path" ] && export PATH="$$_posix_path:$$PATH"; \
	fi; \
	[ -n "$$_vs_include" ] && export INCLUDE="$$_vs_include"; \
	[ -n "$$_vs_lib" ]     && export LIB="$$_vs_lib"; \
	printf "\033[36;1mBootstrapping\033[0m VS environment ready. Re-running make...\n"; \
	export RENWEB_VS_BOOTSTRAPPED=1; \
	$(MAKE) $(_VS_GOALS) $(_VS_VARS)
$(_VS_GOALS): _vs_bootstrap
.PHONY: _vs_bootstrap $(_VS_GOALS)
else
# =============================================================================
# Build targets
# =============================================================================
.PHONY: all clear clean info help

all: $(OUT)

# ── Link ──────────────────────────────────────────────────────────────────────
ifeq ($(OS_NAME),windows)
$(OUT): $(OBJ) | $(BUILD_DIR)
	$(call step,Linking,$(PLUGIN_NAME))
	$(CXX) $(OBJ) /LD /Fe:$(OUT) /link $(LDFLAGS)
else
$(OUT): $(OBJ) | $(BUILD_DIR)
	$(call step,Linking,$(PLUGIN_NAME))
	$(CXX) $(CXXFLAGS) $(SHARED_FLAGS) $(LDFLAGS) -o $@ $^
endif

$(BUILD_DIR):
ifeq ($(OS_NAME),windows)
	mkdir "$(BUILD_DIR)" 2>nul || exit 0
else
	mkdir -p $(BUILD_DIR)
endif

# ── Compile ───────────────────────────────────────────────────────────────────
ifeq ($(OS_NAME),windows)
$(OBJ): $(SRC) include/renweb_example_plugin.hpp include/plugin.hpp | $(OBJ_DIR)
	$(call step,Compiling,$<)
	$(CXX) $(CXXFLAGS) /I include/ /c $(SRC) /Fo$@
else
$(OBJ): $(SRC) include/renweb_example_plugin.hpp include/plugin.hpp | $(OBJ_DIR)
	$(call step,Compiling,$<)
	$(CXX) $(CXXFLAGS) -I include/ -c $< -o $@
endif

$(OBJ_DIR):
ifeq ($(OS_NAME),windows)
	mkdir "$@" 2>nul || exit 0
else
	mkdir -p $@
endif

# ── Utility ───────────────────────────────────────────────────────────────────
clear:
	$(call step,Clearing,object files)
ifeq ($(OS_NAME),windows)
	-rmdir /s /q "$(OBJ_DIR)" 2>nul
else
	rm -rf $(OBJ_DIR)
endif

clean:
	$(call step,Cleaning,all build outputs)
ifeq ($(OS_NAME),windows)
	-rmdir /s /q "$(OBJ_DIR)" 2>nul
	-rmdir /s /q "$(BUILD_DIR)" 2>nul
else
	rm -rf $(OBJ_DIR) $(BUILD_DIR)
endif

info:
	$(call describe,Plugin,$(PLUGIN_NAME),Version,$(PLUGIN_VERSION))
	$(call describe,OS,$(OS_NAME),Arch,$(ARCH))
	$(call describe,Target,$(TARGET),Compiler,$(CXX))
	$(call step,Output,$(OUT))

help:
	@echo ""
	@echo "Usage: make [TARGET=debug|release] [TOOLCHAIN=<triplet>]"
	@echo ""
	@echo "  all     Build the plugin shared library (default)"
	@echo "  clear   Remove object files only (useful between cross-compile passes)"
	@echo "  clean   Remove object files and build/plugins/ output"
	@echo "  info    Print plugin name, version, compiler, and output path"
	@echo "  help    Show this message"
	@echo ""
	@echo "Tip: run ./build_all_archs.sh to build for all supported architectures."
	@echo ""

# ── Dependency tracking (gcc/clang only) ─────────────────────────────────────
ifneq ($(OS_NAME),windows)
-include $(OBJ:.o=.d)
endif
endif


TOOLCHAIN_DIR := toolchain
LIBFXCG_DIR := libfxcg
MKG3A_DIR := mkg3a
BUILD_DIR := .build

TOOLCHAIN_DIR := $(abspath $(TOOLCHAIN_DIR))
BUILD_DIR := $(abspath $(BUILD_DIR))
LIBFXCG_DIR := $(abspath $(LIBFXCG_DIR))
MKG3A_DIR := $(abspath $(MKG3A_DIR))

all: $(TOOLCHAIN_DIR)/bin/sh3eb-elf-gcc $(LIBFXCG_DIR)/lib/libfxcg.a $(LIBFXCG_DIR)/lib/libc.a $(TOOLCHAIN_DIR)/bin/mkg3a

# binutils
BINUTILS_URL := https://ftp.gnu.org/gnu/binutils/binutils-2.43.1.tar.xz
BINUTILS_XZ_NAME := binutils-2.43.1.tar.xz

$(TOOLCHAIN_DIR)/bin/sh3eb-elf-ld: $(BUILD_DIR)/binutils/Makefile
	@mkdir -p $(dir $@)
	$(MAKE) -C $(dir $^)
	$(MAKE) -C $(dir $^) install

$(BUILD_DIR)/binutils/Makefile: $(BUILD_DIR)/binutils-src/configure
	@mkdir -p $(dir $@)
	cd $(dir $@) && $(BUILD_DIR)/binutils-src/configure --target=sh3eb-elf --prefix="$(TOOLCHAIN_DIR)" --disable-nls

$(BUILD_DIR)/binutils-src/configure: $(BUILD_DIR)/$(BINUTILS_XZ_NAME)
	@mkdir -p $(dir $@)
	cd $(dir $@) && tar -mxf $^ --xz
	@# -v | awk '{printf "\r'"Extracted %s files..."'",NR} END {printf "Done.\n"}'
	cd $(dir $@) && ls -1 | xargs -i bash -c 'cd {} && shopt -s dotglob && mv * ..'

$(BUILD_DIR)/$(BINUTILS_XZ_NAME):
	@mkdir -p $(dir $@)
	curl $(BINUTILS_URL) -s -o $@

# gcc
GCC_URL := https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz
GCC_XZ_NAME := gcc-14.2.0.tar.xz

$(TOOLCHAIN_DIR)/bin/sh3eb-elf-gcc: $(BUILD_DIR)/gcc/Makefile $(TOOLCHAIN_DIR)/bin/sh3eb-elf-ld
	@mkdir -p $(dir $@)
	export PATH=$(TOOLCHAIN_DIR)/bin:$$PATH && $(MAKE) -C $(dir $<) all-gcc all-target-libgcc
	export PATH=$(TOOLCHAIN_DIR)/bin:$$PATH && $(MAKE) -C $(dir $<) install-gcc install-target-libgcc

$(BUILD_DIR)/gcc/Makefile: $(BUILD_DIR)/gcc-src/configure $(TOOLCHAIN_DIR)/bin/sh3eb-elf-ld
	@mkdir -p $(dir $@)
	cd $(dir $@) && $(BUILD_DIR)/gcc-src/configure --target=sh3eb-elf --prefix="$(TOOLCHAIN_DIR)" --disable-nls --enable-languages=c,c++ --without-headers

$(BUILD_DIR)/gcc-src/configure: $(BUILD_DIR)/$(GCC_XZ_NAME)
	@mkdir -p $(dir $@)
	cd $(dir $@) && tar -mxf $^ --xz
	@# -v | awk '{printf "\r'"Extracted %s files..."'",NR} END {printf "Done.\n"}'
	cd $(dir $@) && ls -1 | xargs -i bash -c 'cd {} && shopt -s dotglob && mv * ..'

$(BUILD_DIR)/$(GCC_XZ_NAME):
	@mkdir -p $(dir $@)
	curl $(GCC_URL) -s -o $@

# libfxcg
$(LIBFXCG_DIR)/lib/libfxcg.a $(LIBFXCG_DIR)/lib/libc.a &: $(TOOLCHAIN_DIR)/bin/sh3eb-elf-gcc
	@mkdir -p $(dir $@)
	export PATH=$(TOOLCHAIN_DIR)/bin:$$PATH && $(MAKE) -C $(LIBFXCG_DIR)

# mkg3a
$(TOOLCHAIN_DIR)/bin/mkg3a: $(BUILD_DIR)/mkg3a/Makefile
	@mkdir -p $(dir $@)
	$(MAKE) -C $(BUILD_DIR)/mkg3a
	$(MAKE) -C $(BUILD_DIR)/mkg3a install

$(BUILD_DIR)/mkg3a/Makefile: $(MKG3A_DIR)/CMakeLists.txt
	@mkdir -p $(dir $@)
	cd $(dir $@) && cmake -DCMAKE_INSTALL_PREFIX:PATH="$(TOOLCHAIN_DIR)" $(MKG3A_DIR)

# make configuration

.PHONY: all clean distclean fullclean

clean:
	rm -rf $(TOOLCHAIN_DIR)
	-$(MAKE) -C $(BUILD_DIR)/binutils clean
	-$(MAKE) -C $(BUILD_DIR)/gcc clean
	-$(MAKE) -C $(LIBFXCG_DIR) clean
	-$(MAKE) -C $(BUILD_DIR)/mkg3a clean

distclean:
	rm -rf $(TOOLCHAIN_DIR)
	rm -rf $(BUILD_DIR)/binutils $(BUILD_DIR)/gcc $(BUILD_DIR)/mkg3a
	cd $(LIBFXCG_DIR) && git clean -d . -f -x -q && git reset --hard head

fullclean:
	rm -rf $(TOOLCHAIN_DIR) $(BUILD_DIR)
	rm -rf $(LIBFXCG_DIR) && git submodule update --recursive

DELETE_ON_ERROR: 
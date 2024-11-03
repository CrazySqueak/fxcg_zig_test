
.SUFFIXES: 
.SECONDARY: 

AUTOBUILD_PATH := $(abspath ../fxcg_autobuild)
TOOL_BIN_PATH := $(AUTOBUILD_PATH)/cross/bin
LINKER_SCRIPT := $(AUTOBUILD_PATH)/build/src-libfxcg/toolchain/prizm.x  # dirty hack
GCC_PREFIX := $(TOOL_BIN_PATH)/sh3eb-elf
GCC := $(GCC_PREFIX)-gcc
LD := $(GCC_PREFIX)-gcc

LIBS_PATH := $(AUTOBUILD_PATH)/libfxcg/lib
INCLUDES_PATH := $(AUTOBUILD_PATH)/libfxcg/include

TFLAGS := -mb -m4a-nofpu -mhitachi -nostdlib
CFLAGS := -Os -Wall $(TFLAGS) -ffunction-sections -fdata-sections -flto
LDFLAGS := $(TFLAGS) -T$(LINKER_SCRIPT) -flto -Wl,-static -Wl,-gc-sections

ZIGFLAGS := --gc-sections -target powerpc-freestanding $(ZIGFLAGS)
ZIG_LIB_DIR := $(shell zig env | jq -r .lib_dir)

LIBS := -L$(LIBS_PATH) -lc -lfxcg -lgcc
INCLUDES := -I$(INCLUDES_PATH) -I$(ZIG_LIB_DIR) -Icgutil -isystem workaround

BUILD_DIR := build
UTIL_OBJS := $(patsubst cgutil/%.c,util/%.o,$(wildcard cgutil/*.c))  # util/openmainmenu.o
SRC_OBJS := generated/zig.o
OBJECTS := $(SRC_OBJS) $(UTIL_OBJS) # zigbuiltin/compiler_rt.o

TARGET_NAME := target
APP_NAME := fxcg_example

target: $(TARGET_NAME).g3a

# O -> bin -> g3a
# TODO: icon images
$(TARGET_NAME).g3a: $(BUILD_DIR)/out.bin
	@mkdir -p $(dir $@)
	$(TOOL_BIN_PATH)/mkg3a -n basic:$(APP_NAME) $^ $@

$(BUILD_DIR)/out.bin: $(addprefix $(BUILD_DIR)/,$(OBJECTS))
	@mkdir -p $(dir $@)
	$(LD) $^ $(LDFLAGS) $(LIBS) -o $@

# C -> O
$(BUILD_DIR)/generated/%.o: $(BUILD_DIR)/generated/%.c
	@mkdir -p $(dir $@)
	$(GCC) -MMD -MP -MF $(BUILD_DIR)/$*.d -DTARGET_PRIZM=1 $(CFLAGS) -Wno-all $(INCLUDES) -c $^ -o $@

$(BUILD_DIR)/util/%.o: cgutil/%.c
	@mkdir -p $(dir $@)
	$(GCC) -MMD -MP -MF $(BUILD_DIR)/$*.d -DTARGET_PRIZM=1 $(CFLAGS) -Wno-all $(INCLUDES) -c $^ -o $@

# Zig -> C
$(BUILD_DIR)/generated/zig.c: FORCE
	@mkdir -p $(dir $@)
	zig build-obj zigstub.zig -lc -ofmt=c -femit-bin=$@ $(INCLUDES) $(ZIGFLAGS)

# $(BUILD_DIR)/generated/src/%.c: src/%.zig
# 	@mkdir -p $(dir $@)
# 	zig build-obj $^ -ofmt=c -femit-bin=$@ $(INCLUDES) $(ZIGFLAGS)

# Zig builtins
$(BUILD_DIR)/generated/zigbuiltin/%.c: $(ZIG_LIB_DIR)/%.zig
	@mkdir -p $(dir $@)
	zig build-obj $^ -ofmt=c -femit-bin=$@ $(INCLUDES) $(ZIGFLAGS)

clean:
	-rm -rf $(BUILD_DIR)
FORCE: 
.PHONY: clean FORCE target
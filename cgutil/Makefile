
C_SRC_DIR := c
BUILD_DIR := build
OUT_DIR := lib

CC := ../toolchain/bin/sh3eb-elf-gcc
AR := ../toolchain/bin/sh3eb-elf-gcc-ar
INCLUDES := -I../libfxcg/include -Iinclude
CFLAGS := -mb -m4a-nofpu -mhitachi -nostdlib -DTARGET_PRIZM=1 -Os -Wall -ffunction-sections -fdata-sections -flto

C_FILES := $(wildcard $(C_SRC_DIR)/*.c)
OBJECTS := $(patsubst $(C_SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(C_FILES))

$(OUT_DIR)/libcgutil.a: $(OBJECTS)
	@mkdir -p $(dir $@)
	$(AR) rcs $@ $^

$(BUILD_DIR)/%.o: $(C_SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $^ -o $@

clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR)

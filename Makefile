ROOT_DIR  := .

# architecture
ARCH ?= x86
SUPPORTED_ARCHES := x86 x86_64

ifeq ($(filter $(ARCH),$(SUPPORTED_ARCHES)),)
$(error Unsupported ARCH='$(ARCH)'. Supported values: $(SUPPORTED_ARCHES))
endif

ifeq ($(ARCH), x86)
	ARCH_M 		   = 32
	ARCH_ELFFORMAT = i386
	ARCH_COMMON    = x86_common
	LLVM_TARGET    = i386-unknown-none
else
	ARCH_M 		   = 64
	ARCH_ELFFORMAT = x86_64
	ARCH_COMMON    = x86_common
	LLVM_TARGET    = x86_64-unknown-none
endif

# directories
SRC_DIR        := $(ROOT_DIR)/src
BIN_DIR        := $(ROOT_DIR)/bin/$(ARCH_ELFFORMAT)
ISO_DIR        := $(ROOT_DIR)/iso
BOOT_DIR       := $(ISO_DIR)/boot
GRUB_DIR       := $(BOOT_DIR)/grub
ARCH_DIR       := $(SRC_DIR)/arch/$(ARCH)

# files
KERNEL_BIN     := $(ROOT_DIR)/kernel.bin
ISO_FILE       := $(ROOT_DIR)/AurorOS.iso
LINKER_SCRIPT  := $(ARCH_DIR)/build/linker.ld
GRUB_CONFIG    := $(ARCH_DIR)/build/grub.cfg

# tools
CC   ?= cc
NASM ?= nasm
ZAPC ?= zapc
LLC  ?= llc

CFLAGS := \
	-g -Wall -Wextra -m$(ARCH_M) -mno-sse -mno-sse2 -mno-sse3 -mno-mmx \
	-ffreestanding -nostartfiles -Iinclude -nostdlib -fno-stack-protector

ZAP_FLAGS := -nostdlib -noprelude -O2
LLC_FLAGS := --mtriple=$(LLVM_TARGET)

# sources
C_SOURCES      := $(shell find $(SRC_DIR) -type f -name '*.c' ! -name '*.excluded.c')
ASM_SOURCES    := $(shell find $(SRC_DIR) -type f -name '*.asm')

ZAP_ENTRY      := $(SRC_DIR)/main/main.zp

# filtered sources
C_SOURCES_FILTERED := \
    $(filter-out $(SRC_DIR)/arch/%,$(C_SOURCES)) \
    $(filter $(SRC_DIR)/arch/$(ARCH)/%,$(C_SOURCES)) \
	$(filter $(SRC_DIR)/arch/$(ARCH_COMMON)/%,$(C_SOURCES))
ASM_SOURCES_FILTERED := \
    $(filter-out $(SRC_DIR)/arch/%,$(ASM_SOURCES)) \
    $(filter $(SRC_DIR)/arch/$(ARCH)/%,$(ASM_SOURCES)) \
	$(filter $(SRC_DIR)/arch/$(ARCH_COMMON)/%,$(ASM_SOURCES))

# objects
C_OBJECTS      := $(patsubst $(SRC_DIR)/%.c,$(BIN_DIR)/%.o,$(C_SOURCES_FILTERED))
ASM_OBJECTS    := $(patsubst $(SRC_DIR)/%.asm,$(BIN_DIR)/%.o,$(ASM_SOURCES_FILTERED))
ZAP_LLIR       := $(BIN_DIR)/main/main.ll
ZAP_OBJ        := $(BIN_DIR)/main/main.o

# all objects
OBJECTS        := $(C_OBJECTS) $(ASM_OBJECTS) $(ZAP_OBJ)

# main target
all: build-kernel build-iso
	@echo -e "\033[32mSuccess!\033[0m"

build-kernel: $(KERNEL_BIN)
build-iso:    $(ISO_FILE)

# build c sources
$(BIN_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	@echo -e "\033[1;36m[*]\033[0m $< -> $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# build assembly sources
$(BIN_DIR)/%.o: $(SRC_DIR)/%.asm
	@mkdir -p $(dir $@)
	@echo -e "\033[1;36m[*]\033[0m $< -> $@"
	@$(NASM) -f elf$(ARCH_M) $< -o $@

# build zap entry point
$(ZAP_LLIR): $(ZAP_ENTRY)
	@mkdir -p $(dir $@)
	@echo -e "\033[1;36m[*]\033[0m zap sources -> $@"
	@$(ZAPC) $(ZAP_FLAGS) $< -emit-llvm -o $@

$(ZAP_OBJ): $(ZAP_LLIR)
	@mkdir -p $(dir $@)
	@echo -e "\033[1;36m[*]\033[0m $< -> $@"
	@$(LLC) $(LLC_FLAGS) $< --filetype=obj -o $@

# link the kernel
$(KERNEL_BIN): $(OBJECTS) $(LINKER_SCRIPT)
	@echo -e "\033[1;33m[*]\033[0m Linking objects -> kernel binary"
	@ld -m elf_$(ARCH_ELFFORMAT) -T $(LINKER_SCRIPT) -o $@ $(OBJECTS)

# build the iso
$(ISO_FILE): $(KERNEL_BIN)
	@echo -e "\033[1;33m[*]\033[0m Creating ISO directory structure"
	@mkdir -p $(GRUB_DIR)
	@cp $(KERNEL_BIN) $(BOOT_DIR)
	@cp $(ARCH_DIR)/build/grub.cfg $(GRUB_DIR)/grub.cfg
	@echo -e "\033[1;33m[*]\033[0m Generating ISO with GRUB"
	@grub-mkrescue -o $(ISO_FILE) $(ISO_DIR)

# cleaning up
clean:
	@echo -e "\033[1;33m[*]\033[0m Cleaning..."
	@rm -rf $(BIN_DIR) $(ISO_DIR) $(KERNEL_BIN) $(ISO_FILE)

# running the iso
run: all
	qemu-system-x86_64 -cdrom AurorOS.iso

run-gdb: all
	@chmod +x scripts/run_debug_mode.sh
	./scripts/run_debug_mode.sh $(ARCH_ELFFORMAT)

# recompile
recompile: clean all

ASM=nasm
CC=gcc

SRC_DIR=src
TOOLS_DIR=tools
BUILD_DIR=build

.PHONY: all floppy_image kernel bootloader clean always tools_fat

all: floppy_image

#
# Floppy image
#
floppy_image: $(BUILD_DIR)\steveos.img

$(BUILD_DIR)\steveos.img: bootloader kernel
	REM Create a blank 1.44MB floppy image
	powershell -Command "$$f = '$(BUILD_DIR)\\steveos.img'; $$fs = [System.IO.File]::OpenWrite($$f); $$fs.SetLength(1474560); $$fs.Close()"

	REM Write bootloader to sector 0 (first 512 bytes)
	powershell -Command "$$bootloader = [System.IO.File]::ReadAllBytes('$(BUILD_DIR)\\bootloader.bin'); $$floppy = [System.IO.File]::OpenWrite('$(BUILD_DIR)\\steveos.img'); $$floppy.Write($$bootloader, 0, $$bootloader.Length); $$floppy.Close()"

	REM Write kernel to sector 1 (starting at byte 512)
	powershell -Command "$$kernel = [System.IO.File]::ReadAllBytes('$(BUILD_DIR)\\kernel.bin'); $$floppy = [System.IO.File]::OpenWrite('$(BUILD_DIR)\\steveos.img'); $$floppy.Seek(512, [System.IO.SeekOrigin]::Begin); $$floppy.Write($$kernel, 0, $$kernel.Length); $$floppy.Close()"

#
# Bootloader
#
bootloader: $(BUILD_DIR)\bootloader.bin

$(BUILD_DIR)\bootloader.bin: always
	$(ASM) "$(SRC_DIR)\bootloader\boot.asm" -f bin -o "$(BUILD_DIR)\bootloader.bin"

#
# Kernel
#
kernel: $(BUILD_DIR)\kernel.bin

$(BUILD_DIR)\kernel.bin: always
	$(ASM) "$(SRC_DIR)\kernel\main.asm" -f bin -o "$(BUILD_DIR)\kernel.bin"

#
# Tools
#
tools_fat: $(BUILD_DIR)\tools\fat

$(BUILD_DIR)\tools\fat: always $(TOOLS_DIR)\fat\fat.c
	if not exist "$(BUILD_DIR)\tools" mkdir "$(BUILD_DIR)\tools"
	$(CC) -g -o "$(BUILD_DIR)\tools\fat" "$(TOOLS_DIR)\fat\fat.c"

#
# Always
#
always:
	if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"

#
# Clean
#
clean:
	if exist "$(BUILD_DIR)" rmdir /S /Q "$(BUILD_DIR)"
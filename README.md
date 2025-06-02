# SteveOS

**SteveOS** is a minimal 16-bit x86 operating system built from scratch using Assembly (NASM). It includes a custom bootloader and a simple kernel with a basic command-line interface. The system is packed into a 1.44MB floppy disk image for booting in legacy BIOS environments.

---

## 🧠 Features

- FAT12 bootloader written from scratch  
- Kernel loaded to `0x1000:0000` in real mode  
- Text-based shell with built-in commands:
  - `clear`, `help`, `info`, `version`, `echo`, `date`
- BIOS interrupt-based I/O (INT 10h, INT 13h, INT 16h)
- Sector-based disk reading with retry logic
- Keyboard input with backspace and input buffer handling
- Boots from floppy disk image (`steveos.img`)
- Fully written in Assembly (NASM)

---

## 🛠 Requirements

- **NASM** (Netwide Assembler)
- **GCC** (optional, for FAT tool build)
- **PowerShell** (Windows, used to write to floppy image)
- **QEMU**, **Bochs**, or **VirtualBox** for emulation

---

## 🏗 Build Instructions (Windows)

Make sure `nasm.exe` and `gcc.exe` are available in your PATH.

### 1. Build with `make`

```cmd
make
```

---

## 🚀 Booting the OS

### With QEMU

```cmd
qemu-system-i386 build\steveos.img
```

---

## 💬 Notes

- `steveos.img` is a raw floppy disk image (1.44MB).
- Bootloader resides in sector 0, kernel in sector 1 onward.
- Kernel is loaded to memory segment `0x1000`.
- All screen and keyboard interaction is BIOS interrupt-driven.
- Command dispatch is done via a manual jump table.

---

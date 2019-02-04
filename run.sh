#!/bin/sh
# Compile and run boot block
nasm -f bin boot.asm -o boot.hdd

od -A x -t x1 boot.hdd  > boot.hex    # hex dump, for good measure
ndisasm -o 0x7C00 -b 16 boot.hdd  > boot.dis

qemu-system-i386  -drive format=raw,file=boot.hdd

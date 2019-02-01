"C:\Program Files\nasm\nasm.exe" -f bin  boot.S  -o boot.hdd
"C:\Program Files\qemu\qemu-system-i386.exe" boot.hdd

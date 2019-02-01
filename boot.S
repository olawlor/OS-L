;
;  Operating System - Lawlor (OS-L) 
;  x86 BIOS bootup process
;  

BITS 16 ; awful segmented memory
ORG 0x07C00 ; bios loads this boot block to linear address 0x07C00 

start:
	cli ; turn off interrupts until we get the machine running
	cld ; make string instructions run normal direction (+)

	; Zero out all the segment registers
	xor ax, ax ; ax=0
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7000 ; stack pointer starts just below our boot block
  sti ; restore interrupts

  mov al,'O' ; dribble out boot text, so if we lock up, you can see where
  call printchar

  call enter_unreal_mode

  mov al,'S'
  call printchar
  
  call chain_load

hang: jmp hang
  
; ***************** Chain Load **************
; Chain load: load the bulk of our operating system code.
;  We load it right after this boot sector, so hopefully 
;  jumps and calls still work right.
%define CHAINLOAD_ADDRESS (0x7C00+512)
%define CHAINLOAD_BYTES (30*1024)  ; size of chainload area
%define CHAINLOAD_SIGNATURE 0xC0DE  ; "code"

; Default path uses Logical Block Addressing (LBA)
chain_load:
  ; Do disk read using linear block addressing: BIOS INT 13,42: 
  ;    https://en.wikipedia.org/wiki/INT_13H  
  mov ah,0x42             ;function number for LBA disk read
  mov si,read_DAP         ;memory location of Disk Address Packet (DAP)
  
  ; The boot drive is actually loaded to register dl on startup
  ; mov dl,0x80             ;drive (0x80 is hard drive, 0 is A:, 1 is B:)
  int 0x13                ;read the disk
  
  jc chain_load_CHS ; Error on LBA?  Try fallback.
  jmp chain_load_post
  
; LBA Disk Address Packet (DAP) identifies the data to read.
read_DAP:
  db 0x10 ; Size of this DAP in bytes
  db 0 ; unused
  dw CHAINLOAD_BYTES/512 ; sector read count
  dw CHAINLOAD_ADDRESS ; memory target: offset
  dw 0 ; memory target: segment
  dq 1 ; 0-based disk sector number to read


; Fallback cylinder-head-sector (CHS) load
chain_load_CHS:
  mov al,'h'
  call printchar
  
  mov bx,CHAINLOAD_ADDRESS   ;target location in memory
  mov ah,0x02             ;function number for disk read
  mov al,CHAINLOAD_BYTES/512 ;number of sectors (maximum 63 because BIOS)
  mov ch,0x00             ;cylinder (0-based)
  mov cl,0x02             ;first sector (1-based; boot block is sector 1)
  mov dh,0x00             ;head (0-based)
  
  ; The boot drive is actually loaded to register dl on startup
  ; mov dl,0x80             ;drive (0x80 is hard drive, 0 is A:, 1 is B:)
  int 0x13                ;read sectors to es:bx


chain_load_post:
  mov al,'-'
  call printchar
  
  ; Check first bytes for our signature:
  mov si,CHAINLOAD_ADDRESS
  mov ax,WORD[ds:si]
  cmp ax,CHAINLOAD_SIGNATURE
  jne bad_load
  
  mov al,'L'
  call printchar
  
  ; Hopefully this code exists now!
  jmp chainload_start

bad_load:
  mov si,bad_load_str
  call printstrln
  jmp hang

bad_load_str:
  db "Chainload bad",0


;************* Utility: Text output functions ****************
; Print one character, passed in al.
;   Trashes: none
printchar:
  pusha ; save all registers
	mov bx, 0x0007  ; 'output character' selector
	mov ah, 0x0e; Output a character
	int 0x10  ; "output character" interrupt
	popa
	ret

; Print a string (from the pointer si), then a newline
printstrln:
  call printstr
  ; no ret, so falls through!
println: ; print just the newline
  push ax
  mov al,13 ; CR
  call printchar
  mov al,10 ; LF
  call printchar
  pop ax
  ret

; Print a string, starting address in si
;   Trashes: si
printstr:
  lodsb ; = mov al, BYTE [ds:si]
  cmp al,0 
  je print_done
  call printchar
  jmp printstr
  print_done: ret



;******* Utility: GDT Load for Unreal Mode **********
;  Switches from real mode (where the BIOS works) to protected
;  mode, to initialize the 32-bit address hardware, and SSE hardware.
;  It then switches back, so the BIOS keeps working.

enter_unreal_mode:
  lgdt [flat_gdt_ptr]
  
  cli ; no interrupts
  ; Switch to 32-bit mode
  mov eax,cr0
  or al,1 ; <- set low bit
  mov cr0,eax
  
  ; Do data load
  mov ax, 8 ; 8 bytes into the GDT (plus ring 0)
  mov ds, ax ; initialize 32-bit address hardware
  
  ; While we're in protected mode, turn on SSE via CR4 bit 9 (OSFXSR)
  mov ecx,cr4
  or cx,1<<9
  mov cr4,ecx
  
  ; Back to 16-bit mode (so BIOS works)
  mov eax,cr0
  and al,0xfe ; <- clear low bit
  mov cr0,eax
  
  xor ax,ax ; ax=0, back to segment 0
  mov ds,ax
  sti ; allow interrupts
  
  ret

flat_gdt_ptr:
  dw 2*8 -1 ; length in bytes (minus 1)
  dd gdt_entries ; ptr to gdt

; These are the bytes of our global descriptor table (GDT):
gdt_entries:
   dq 0 ; must start with an invalid entry, 8 bytes long
   
   dw 0xffff ; limit (length of memory)
   dw 0 ; base address 
   db 0 ; first leftover byte of base address
   db 10010010b ; Access Byte: Pr, ring 0, code/data, read/write
   db 11001111b  ; Flags for 4K limit units, , and high bits of limit
   db 0 ; high bits of base address


; pad to make this boot sector exactly 512 bytes long total
	times 512-4-2-64-2-($-start) db 0x90  

; Official PC boot record format:
  dd 'HiM$' ; disk signature (any 4-byte string)
  times 2 db 0 ; null bytes
  
; These 64 bytes are the "MBR Partition Table":
;   four 16-byte records describing the first 4 disk partitions (primary partitions).
  times 64 db 0

; A boot sector's last two bytes must contain this magic flag.
; This tells the BIOS it's OK to boot here; without this, 
;  you'll get the BIOS "Operating system not found" error.
	dw 0xAA55 ; Magic value needed by BIOS

; End of boot sector
; -----------------------------------------------------
; Start of chainload sectors (immediately follows boot sector on disk)
chainload_signature:
  dw CHAINLOAD_SIGNATURE ; our boot signature
  
chainload_start:
  call println
  mov si,full_splash_message
  call printstrln
  
  cmdloop:
    call cmdline_run_cmd
    jmp cmdloop

full_splash_message:
  db 'Welcome to OS-L, the OS with NO RULES and NO FEATURES!',0

%include "commands.S"

%include "utility.S"

; Round up size to full CHAINLOAD_BYTES (VirtualBox wants full 512-byte sectors)
times (CHAINLOAD_BYTES - ($-chainload_signature))  db 0x90 



  

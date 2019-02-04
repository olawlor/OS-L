; Debugging and I/O utility functions
; See also the utility functions in boot.S, like printchar
;  16 bit x86 assembly language for NASM
;  Dr. Orion Lawlor, lawlor@alaska.edu, 2019-01-29 (Public Domain)


; Print eax as 8 hex digits onscreen
;  Trashes: none
printhex32:
  push cx
  mov cl,8*4 ; bit counter: print 8 hex digits, at 4 bits each
  jmp printhex_raw_start
printhex8: ; print al as 2 hex digits onscreen
  push cx
  mov cl,2*4 ; 2 hex digits
printhex_raw_start:
    sub cl,4 ; move down 1 hex digit = 4 bits
    push eax
    
    ; print hex digit from bit number cl
    shr eax,cl ; shift ax's high bits down first
    and al,0xF ; extract the low hex digit
    cmp al,9
    jbe print_number_only
      add al,'A'-10-'0' ; print as ASCII letter
    print_number_only:
    add al,'0' ; convert number to ascii
    call printchar
    
    pop eax
    cmp cl,0
    jne printhex_raw_start ; repeat until cl == 0
  
  pop cx
  ret

; Read one char from the user, return ASCII in al / scancode in ah
;  Trashes: returns in ax
readchar:  
  xor ax, ax; set ax to zero (wait for keypress)
  int 0x16  ; Wait for a keypress
  call printchar ; Always echo user input
  ret

; Read hex digits from the user until hits spacebar, return value in eax
;  Trashes: ax, dx
readhex:
  xor edx, edx ; value we're accumulating
  
  read_hex_loop:
    call readchar
    cmp al,' ' ; we hit a space character
    je read_hex_done
    cmp al,13 ; we hit a (DOS) newline character
    je read_hex_done
    
    ; Else it's a real char: start by shifting old chars up
    shl edx,4 ; 4 bits per hex char
    
    cmp al,'9'
    jle read_hex_number
       ; else it's a letter
       cmp al,'F'
       jle read_hex_uppercase
        ; lowercase
        sub al,'a'-10
        jmp read_hex_add
       
       read_hex_uppercase:
        ; uppercase
        sub al,'A'-10
        jmp read_hex_add
      
      read_hex_number: ; it's a number
      sub al,'0'
    read_hex_add:
      movzx eax,al ; sign-extend al from 8 bits to 16 bits
      add edx,eax
      jmp read_hex_loop
  
read_hex_done:
  mov eax,edx ; return result in eax
  ret

; Crash handling
crash:
  call debugdump
  jmp hang

; Dump all registers, for debugging
;  trashes: none
debugdump:
  call println
  push eax
  push ebx
  push ecx
  push esi
  
  mov bx,'AX' 
  call printreg
  
  pop eax ; grab pushed copy of bx
  push eax ; re-save the copy
  mov bx,'BX'
  call printreg
  
  mov eax,ecx
  mov bx,'CX'
  call printreg
  
  mov eax,edx
  mov bx,'DX'
  call printreg

  call println
  
  
  mov eax,esp
  mov bx,'SP'
  call printreg
  
  mov eax,ebp
  mov bx,'BP'
  call printreg
  
  mov eax,esi
  mov bx,'SI'
  call printreg
  
  mov eax,edi
  mov bx,'DI'
  call printreg
  
  call println
  
  
  mov eax,0
  mov ax,ss
  mov bx,'SS'
  call printreg
  
  mov si,sp
  mov ax,WORD[si+2+16] ; dig down in stack to saved address (we use 16 bytes)
  mov bx,'IP' 
  call printreg
  
  mov ax,cs
  mov bx,'CS'
  call printreg
  
  mov ax,ds
  mov bx,'DS'
  call printreg
  
  mov ax,es
  mov bx,'ES'
  call printreg
  
  call println
  
  pop esi
  pop ecx
  pop ebx
  pop eax
  ret

; Input: bl = char name of register.  eax = value of register
printreg:
  push eax
  push bx
  mov al,bl
  call printchar
  pop bx
  mov al,bh
  call printchar
  mov al,'='
  call printchar
  
  pop eax
  call printhex32
  mov al,' '
  call printchar
  ret

; Restart the machine, by jumping to the BIOS's power-on code.
reboot:
  jmp  0xffff:0x0000 ; Jump to BIOS reset code



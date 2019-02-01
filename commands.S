; This is a big table of command-line commands.
;  16 bit x86 assembly language for NASM
;  Dr. Orion Lawlor, lawlor@alaska.edu, 2019-01-29 (Public Domain)


;  Each command has the format:
;    dq '<command line name>' (8 bytes maximum)
;    dd pointer to the command description (one-line help)
;    dd pointer to the command executable code 
command_list:
  
  dq 'ello'
  dd ello_str
  dd ello_code
  
  dq 'reg'
  dd reg_str
  dd reg_code
  
  
  dq 'mem'
  dd mem_str
  dd mem_code
  
  dq 'hook'
  dd hooktimer_str
  dd hooktimer_code
  
  dq 'unhook'
  dd unhooktimer_str
  dd unhooktimer_code
  
  dq 'help'
  dd help_str
  dd help_code
  
  dq '?'
  dd help_str
  dd help_code

end_command_table:


ello_str: db "Prints 'hello'.",0
ello_print: db "Hello there!",0
ello_code: 
  mov si,ello_print
  call printstrln
  ret

reg_str: db "Prints contents of registers.",0
reg_code:
  call debugdump
  ret

mem_str: db "Print contents of memory at a linear address.",0
mem_code:
  call readhex ; linear address
  mov esi,eax
  call println
  
  ; Dump one row of bytes:
  mov ecx,0
  .start_print:
    mov al, BYTE [esi+ecx] ; load byte from memory
    call printhex8
    mov al, ' '
    call printchar
    
    inc cx
    cmp cx,16
    jl .start_print
  
  call println
  ret

; ----------------- Interrupt magic
hooktimer_str: db "Hooks the timer interrupt.",0
hooktimer_code:
  cmp BYTE[timer_hooked],0
  jne nope
  
  ; Hook interrupt 8: (timer interrupt)
  ; See http://stanislavs.org/helppc/int_table.html
  ; See https://stackoverflow.com/questions/48704725/why-does-pc-halt-when-i-try-to-hook-int-13h-from-my-bootloader
  mov si,4*8 ; each interrupt timer entry is 4 bytes (offset and segment)
  
  cli
  mov eax,DWORD[si] ; save the old handler
  mov DWORD[timer_saved],eax
  
  mov WORD[si],timer_interrupt ; our code
  mov WORD[si+2],0 ; our segment
  mov BYTE[timer_hooked],1
  sti
  ret

timer_hooked: db 0
timer_saved: ; saved copy of original handler
   dw 0,0

timer_interrupt:
  pusha
  ; Do our own work
  mov al,'.'
  call printchar
  mov al,'.'
  call printchar
  
  popa
  jmp far [timer_saved] ; call old handler

unhooktimer_str: db "Unhooks the timer interrupt.",0
unhooktimer_code:
  cmp BYTE[timer_hooked],1
  jne nope
  mov si,4*8 
  mov eax,DWORD[timer_saved] ; restore the old handler
  mov DWORD[si],eax
  mov BYTE[timer_hooked],0
  ret

nope_str: db "NOPE",0
nope:
  mov si,nope_str
  call printstrln
  ret

; ----------------- Command magic
; Walk the list of commands, and print the name and help text
help_str: db "Prints a list of possible commands.",0
help_code:
  mov edx,command_list
  .cmdloop:
    mov ecx,0
    .charloop:
      mov al,BYTE[edx+ecx]
      call printchar
      add cl,1
      cmp cl,8
      jl .charloop
    
    mov al,' '
    call printchar
    
    mov esi,DWORD[edx+8]
    call printstrln
    add edx,16 ; each command entry is 16 bytes
    cmp edx,end_command_table
    jl .cmdloop
  ret


; Find and run the commandline from cmdline_buf
cmdline_run:
  mov edx,command_list
  .cmdloop:
    mov ecx,0
    .charloop:
      mov al,BYTE[edx+ecx] ; char from command name
      
      cmp al,BYTE[cmdline_buf+ecx]
      jne .no_match
      
      cmp al,0
      je .good_match ; full match so far
      
      add ecx,1
      cmp ecx,8
      jl .charloop
    .good_match:
    
    mov eax,DWORD[edx+12]; pointer to command code
    call ax ;<- subtle: can't call eax, need segmented mode
    ret
    
    .no_match:
    add edx,16 ; each command entry is 16 bytes
    cmp edx,end_command_table
    jl .cmdloop
  mov si,cmd_not_found_str
  call printstrln
  ret

cmd_not_found_str:
  db "Unknown command.  Enter 'help' or '?' for a list.",0



; Buffer for command line being entered
cmdline_buf: times 10 dq 0
cmdline_buf_end:

cmd_prompt: db "O>$ ",0

; Read one command from the user into cmdline_buf
cmdline_read:
  mov si,cmd_prompt
  call printstr
  
  mov ecx,0 ; index into cmdline_buf
  cmdline_read_more:
    call readchar
    cmp al,13 ; hit newline
    je cmdline_read_done
    cmp cl,(cmdline_buf_end-cmdline_buf)
    je cmdline_read_done_toobig
    mov BYTE[cmdline_buf+ecx],al
    inc ecx
    jmp cmdline_read_more
  
  cmdline_read_done:
  mov BYTE[cmdline_buf+ecx],0 ; zero terminate string
  cmdline_read_done_toobig:
  call println
  
  mov si,cmdline_buf ; echo command, for debugging
  call printstrln
  ret


; Read one command from the user, and run it.
cmdline_run_cmd:
  call cmdline_read
  call cmdline_run
  ret




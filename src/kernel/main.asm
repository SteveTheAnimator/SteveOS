org 0x0000
bits 16

section .text
global _start

_start:
    ; Set up data segments
    push cs
    pop ds
    mov ax, ds
    mov es, ax

    call cls

    mov si, titleString
    call printStr
    mov si, newLine
    call printStr

main:
    mov si, prompt
    call printStr

    mov di, readBuffer
    call getInput

    mov si, readBuffer
    call splitCommand

    mov si, readBuffer
    cmp byte [si], 0
    je main

    ; Dispatch command
    call dispatchCommand
    jmp main

; -------------------------------
; Command dispatcher via table
; -------------------------------
dispatchCommand:
    mov si, commandTable
nextCmd:
    lodsw               ; Load pointer to command string -> AX
    test ax, ax
    jz cmdNotFound      ; End of table

    push si             ; Save table pointer
    mov si, ax          ; SI = command string
    mov di, command
    call cmpUI
    jc matchFound
    pop si              ; Restore table pointer
    add si, 2           ; Skip handler pointer
    jmp nextCmd

matchFound:
    pop si              ; Restore table pointer
    lodsw               ; Load handler address
    jmp ax              ; Jump to handler

cmdNotFound:
    mov si, badCmd
    call printStr
    ret

; ---------------------------------------
; Utility Functions
; ---------------------------------------

; Print string at DS:SI until null terminator
printStr:
    mov ah, 0x0E
printLoop:
    lodsb
    test al, al
    jz printDone
    int 0x10
    jmp printLoop
printDone:
    ret

; Read input into ES:DI, handle backspace, terminate with null
getInput:
    xor cl, cl
getInputLoop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x08
    je backspace
    cmp al, 0x0D
    je inputDone
    cmp cl, 0x3F
    je getInputLoop
    mov ah, 0x0E
    int 0x10
    stosb
    inc cl
    jmp getInputLoop

backspace:
    cmp cl, 0
    je getInputLoop
    dec di
    mov byte [di], 0
    dec cl
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp getInputLoop

inputDone:
    mov al, 0
    stosb
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; Compare strings at DS:SI and DS:DI, CF=1 if equal
cmpUI:
cmpLoop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne notEqual
    cmp al, 0
    je equalStrings
    inc si
    inc di
    jmp cmpLoop
notEqual:
    clc
    ret
equalStrings:
    stc
    ret

; Split input: first word to 'command', rest to 'arguments'
splitCommand:
    mov di, command
splitLoop:
    lodsb
    cmp al, ' '
    je foundSpace
    stosb
    test al, al
    jnz splitLoop
    jmp splitDone
foundSpace:
    mov di, arguments
copyArgs:
    lodsb
    stosb
    test al, al
    jnz copyArgs
splitDone:
    ret

; Clear the screen
cls:
    push ax
    push bx
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    pop bx
    pop ax
    ret

; ---------------------------------------
; Command Handlers
; ---------------------------------------

clear_screen:
    call cls
    ret

help:
    mov si, msgHelp
    call printStr
    ret

info:
    mov si, msgInfo
    call printStr
    ret

age:
    mov si, msgAge
    call printStr
    ret

version:
    mov si, msgVersion
    call printStr
    ret

echo:
    mov si, arguments
    call printStr
    ret

date:
    call getDate
    ret

methCall:
    mov si, meth
    call printStr
    ret

getDate:
    mov si, msgDate
    call printStr
    ret

; ---------------------------------------
; Data Section
; ---------------------------------------
section .data
cmdClear        db 'clear', 0
cmdHelp         db 'help', 0
cmdInfo         db 'info', 0
cmdAge          db 'age', 0
cmdVersion      db 'version', 0
cmdEcho         db 'echo', 0
cmdDate         db 'date', 0
isSteveOnMeth   db 'meth', 0

commandTable:
    dw cmdClear, clear_screen
    dw cmdHelp, help
    dw cmdInfo, info
    dw cmdAge, age
    dw cmdVersion, version
    dw cmdEcho, echo
    dw cmdDate, date
    dw isSteveOnMeth, methCall
    dw 0, 0

readBuffer      times 64 db 0
prompt          db '>', 0
titleString     db 'SteveOS v0.1', 13, 10, 0
msgHelp         db 'Available commands: help info clear', 13, 10, 0
msgInfo         db 'Info: Simple 16-bit OS kernel', 13, 10, 0
msgAge          db 'Age: 25', 13, 10, 0
badCmd          db 'No such command.', 13, 10, 0
newLine         db 13, 10, 0
msgVersion      db 'SteveOS version 0.1 - Build 2025', 13, 10, 0
msgDate         db 'Date: 2025-05-26', 13, 10, 0
meth            db 'Is Steve on Meth? Yes, always!', 13, 10, 0

; ---------------------------------------
; BSS Section
; ---------------------------------------
section .bss
command     resb 16
arguments   resb 64

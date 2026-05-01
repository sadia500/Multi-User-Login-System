.model small
.stack 100h
.data
    msg1 db 13,10,'1=ADD, 2=SUB, 3=MUL, 4=Exit: $'
    msg2 db 13,10,'Enter First Digit: $'
    msg3 db 13,10,'Enter Second Digit: $'
    msgRes db 13,10,'Result: $'

.code
main:
    mov ax, @data
    mov ds, ax

menu:
    lea dx, msg1
    mov ah, 09h
    int 21h

    mov ah, 01h     
    int 21h
    sub al, '0'
    cmp al, 4
    je exit_prog
    mov bl, al     

    ; Input 1
    lea dx, msg2
    mov ah, 09h
    int 21h
    mov ah, 01h
    int 21h
    sub al, '0'
    mov cl, al     

    ; Input 2
    lea dx, msg3
    mov ah, 09h
    int 21h
    mov ah, 01h
    int 21h
    sub al, '0'      

    ; Branching
    cmp bl, 1
    je do_add
    cmp bl, 2
    je do_sub
    cmp bl, 3
    je do_mul
    jmp menu

do_add:
    add al, cl
    jmp print_result

do_sub:
    sub cl, al    
    mov al, cl
    jmp print_result

do_mul:
    mul cl          
    jmp print_result

print_result:
    mov bl, al      
    lea dx, msgRes
    mov ah, 09h
    int 21h

    mov al, bl     
    mov ah, 0        
    mov cl, 10
    div cl          

    mov bx, ax      
    
    ; Print Tens Digit
    mov dl, bl
    add dl, '0'
    mov ah, 02h
    int 21h

    ; Print Units Digit
    mov dl, bh
    add dl, '0'
    mov ah, 02h
    int 21h

    jmp menu

exit_prog:
    mov ah, 4ch
    int 21h
end main
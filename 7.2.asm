.model small
.stack 100h
.data
    msg1 db 13,10,'enter digit: $'
    msg_e db 13,10,'even$'
    msg_o db 13,10,'odd$'

.code
main:
    mov ax, @data
    mov ds, ax

    lea dx, msg1
    mov ah, 09h
    int 21h

    mov ah, 01h
    int 21h
    sub al, '0'

    mov ah, 0
    mov bl, 2
    div bl

    cmp ah, 0
    je is_even

    lea dx, msg_o
    mov ah, 09h
    int 21h
    jmp exit

is_even:
    lea dx, msg_e
    mov ah, 09h
    int 21h

exit:
    mov ah, 4ch
    int 21h
end main





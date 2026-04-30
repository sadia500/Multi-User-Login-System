.model small
.stack 100h
.data
header db 'Power of 2 table (2^0 to 2^4):',0dh,0ah,'$'
p0 db '2^0 (shl 1,0): $'
p1 db 0dh,0ah,'2^1 (shl 1,1): $'
p2 db 0dh,0ah,'2^2 (shl 1,2): $'
p3 db 0dh,0ah,'2^3 (shl 1,3): $'
p4 db 0dh,0ah,'2^4 (shl 1,4): $'

.code
main proc
    mov ax, @data
    mov ds, ax

    mov ah, 09h
    mov dx, offset header
    int 21h

    mov ah, 09h
    mov dx, offset p0
    int 21h
    mov al, 1
    shl al, 0
    call display_number

    mov ah, 09h
    mov dx, offset p1
    int 21h
    mov al, 1
    shl al, 1
    call display_number

    mov ah, 09h
    mov dx, offset p2
    int 21h
    mov al, 1
    shl al, 2
    call display_number

    mov ah, 09h
    mov dx, offset p3
    int 21h
    mov al, 1
    shl al, 3
    call display_number

    mov ah, 09h
    mov dx, offset p4
    int 21h
    mov al, 1
    shl al, 4
    call display_number

    mov ah, 4ch
    int 21h
main endp

display_number proc
    push ax
    push bx
    push cx
    push dx

    mov cl, al
    cmp al, 10
    jb single_digit

    mov ah, 0
    mov ch, 10
    div ch
    mov bx, ax

    mov dl, bl
    add dl, 30h
    mov ah, 02h
    int 21h

    mov dl, bh
    add dl, 30h
    mov ah, 02h
    int 21h
    jmp display_done

single_digit:
    mov dl, cl
    add dl, 30h
    mov ah, 02h
    int 21h

display_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
display_number endp

end main

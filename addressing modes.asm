.model small
.stack 100h
.data
msg1 db 'Immediate: $'
msg2 db 0dh,0ah,'Register: $'
msg3 db 0dh,0ah,'Direct: $'
storage db ?

.code
main:
    mov ax,@data
    mov ds,ax

    ; Immediate addressing
    mov ah,09h
    mov dx,offset msg1
    int 21h 
    
    mov al,5 
    push ax

    mov dl,al
    add dl,30h
    mov ah,02h
    int 21h


    ; Register addressing 
    pop ax
    mov bl,al
    mov ah,09h
    mov dx,offset msg2
    int 21h

    mov dl,bl
    add dl,30h
    mov ah,02h
    int 21h

   

    ; Direct addressing
    
    mov ah,09h
    mov dx,offset msg3
    int 21h 
    mov storage,bl

    mov dl,storage    ; ? Correct memory value
    add dl,30h
    mov ah,02h
    int 21h


    ; Exit program
    mov ah,4ch
    int 21h

end main

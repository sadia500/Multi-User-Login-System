.model small
.stack 100h

.data
    prompt db "Enter digit (0-9): $"
    even_msg db 0DH, 0AH, "Even$"
    odd_msg db 0DH, 0AH, "Odd$"
    
.code
    main proc
    mov ax, @data
    mov ds, ax
    
    mov ah, 09h
    mov dx, offset prompt
    int 21h
    
    mov ah, 01h
    int 21h
    sub al, 30h
    mov bl, al
    
    and al, 01h
    jz is_even 
    
    mov ah, 09h
    mov dx, offset odd_msg
    jmp display_result
    
    is_even:
        mov ah, 09h
        mov dx, offset even_msg
    
    display_result:
        int 21h
      
    mov ah, 4Ch
    int 21h
    
    main endp
    end main





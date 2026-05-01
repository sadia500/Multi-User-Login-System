;task - 01
.model small
.stack 100h

.data
    prompt db "Enter your score (0-100): $"
    gradeA db 0dh, 0ah, "Grade: A$"
    gradeB db 0dh, 0ah, "Grade: B$"
    gradeC db 0dh, 0ah, "Grade: C$"
    gradeD db 0dh, 0ah, "Grade: D$"
    gradeF db 0dh, 0ah, "Grade: F$"

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
    
    mov ah, 01h
    int 21h
    sub al, 30h
    mov cl, al
    
    mov al, bl
    mov bl, 10
    mul bl
    add al, cl
    mov bl, al
    
    cmp bl, 90
    jge display_A
    
    cmp bl, 80
    jge display_B
    
    cmp bl, 70
    jge display_C
    
    cmp bl, 60
    jge display_D
    
    cmp bl, 0
    jge display_F
    
    display_A:
        mov dx, offset gradeA
        jmp show_grade
    
    display_B:
        mov dx, offset gradeB
        jmp show_grade
    
    display_C:
        mov dx, offset gradeC
        jmp show_grade
    
    display_D:
        mov dx, offset gradeD
        jmp show_grade  
        
    display_F:
        mov dx, offset gradeF
        
    show_grade:
        mov ah, 09h
        int 21h
        
    main endp
    end main




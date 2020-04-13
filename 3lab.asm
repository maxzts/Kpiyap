.model tiny

.data
tmp dw 0 
countSymb dw 0 
minus db 0
result_minus db ' '
znak db 2Dh
end_of_str db 0
msg1 db 'Enter amount: $'
msg2 db 10,13,'Enter your ms: $',10,13 
msg3 db 10,13,'AVERAGE is: $'
Error1 db 10,13,'Only enter was pushed$'
Error2 db 10,13, 'It is not a number$'
over_flow db 10,13, 'Error: overflow$'
ms db 200h dup ('$') 
MAX db 200
amount db 5 dup ('$')
AVERAGE db 7 dup (' ')
ostatok db 0
prob db ' '
.code
print_str macro out_str
    mov ah,09h
    mov dx,offset out_str
    int 21h
endm
start:
    mov ax, @data
    mov ds, ax
    
    mov ah, 00h 
    mov al, 2h
    int 10h 
    
    print_str msg1 
    mov ah, 0Ah 
    lea dx, amount
    int 21h   
    cmp byte ptr amount+2, 0Dh
    je error_input
    print_str msg2

Input:  
    mov ah,MAX
    mov ms,ah
    mov ah, 0Ah
    lea dx, ms
    int 21h 
    cmp word ptr ms+2, 0Dh
    je error_input
     
         
    lea di,znak
    lea SI,amount+2 
    xor al,al
get_Amount:     
    mov cl,es:[si]
    cmp cl, 30h                
    jl err                    
    cmp cl, 39h                 
    jg err
    sub cl,30h 
    add al,cl
    mov cl,amount+1
    cmp cl,2
    jne next
    inc bl

    mov cl,0Ah
    mul cl
    dec amount+1
    inc si
    cmp amount+1,30h
    jne get_Amount
    mov cl,30h 


next: 
    xor cx,cx   
    xchg al,cl
    mov countSymb,cx 
    xor ax,ax
    lea SI,ms+2    
get_Average: 
    
get_num:
    cmp end_of_str,1
    je count    
    cmp cl,00h
    je count
    CLD 
    cmpsb 
    je negative
    dec si
    dec di 
    cmp es:si,0Dh
    je count
    call get_count 
    cmp es:si,20h
    je next_num

    sub es:si,30h
    cmp minus, 1
    je dop_kod

next_num:
    mov minus,0
    inc si 
    jmp get_Average    
    
count:
    mov ax,tmp 
    cmp ah,0f0h 
    ja negative_res
count_if_neg:    
    mov cl,0Ah 
    mul cx 
    jo overflow
    cmp ah,09h
    jl is_checked 
    js get_ah_normal_with_znak
  

is_checked:
    mov cx,countSymb
    cmp cl,1Eh
    ja overflow    
    div cx
    mov cl,0Ah
    cmp ax,00ffh
    ja div_word
    div cl
    call to_float

Output:
    print_str msg3
    print_str AVERAGE
    
    jmp Exit
    
negative:
    mov minus,1 
    dec di
    jmp get_Average
negative_res:
    mov result_minus,'-'

    not ax
    inc ax
 
    jmp count_if_neg   
            
dop_kod:    
    not ax
    add ax,1 
    dec bl 
    jmp add_to_tmp
                  
get_count proc
        push cx
        mov bx,00h
        push di
        lea di,prob  
        inc di
        count_loop:
        cmp es:si,0Dh
        je last_word
        dec di
        inc bl
        cmpsb
        jne count_loop
    mLoop1:     
        sub si,bx
        dec bl
        xor ax,ax
        xor cx,cx
        mov cl,bl
        mov di,10       
    mLoop2:
        mul di                      
        mov bl,[si]                 
        cmp bl, '0'                
        jl err                    
        cmp bl, '9'                 
        jg err                     
        sub bl,30h                 
        add ax,bx                   
        inc si 
        dec cl
        cmp cl,0                      
        ja mLoop2
        pop di
        pop cx 
        dec cl
        cmp minus, 1
        je dop_kod
add_to_tmp:
        cmp minus,1
        je add_checked_to_tmp
        cmp ax,8000h
        ja overflow
add_checked_to_tmp:                                     
        add tmp,ax 
        mov minus,0
        jmp next_num 

last_word:
        mov end_of_str,1
        sub si,bx
        xor ax,ax
        xor cx,cx
        mov cl,bl
        mov di,10 
        jmp mLoop2   
            
to_float proc 
    xor si,si
    lea si,AVERAGE+3
    cmp al,09h
    mov bl,ah 
    ;mov bl,dl
    mov ostatok,bl
    xor ah,ah
    xor cx,cx
    jl get_float
    xor ah,ah
    xor cx,cx
    mov cl,0Ah
    floatLoop:
    div cl
    mov bl,ah
    mov [si],bl
    add [si],30h
    dec si
    cmp al,09h
    ja floatLoop
    get_float:
    
    mov [si],al
    add [si],30h  
    dec si
    mov ah,result_minus
    mov [si],ah
    lea si,AVERAGE+3
    mov [si]+1,','
    mov ah,ostatok
    mov [si]+2,ah
    add [si]+2,30h
    mov [si]+3,'$'
    jmp Output
endp  

error_input:
    print_str Error1
    jmp Exit
err:
    print_str Error2 
    jmp Exit
div_word:
    div cx
    xor si,si
    lea si,AVERAGE+3
    cmp al,09h 
    mov bl,dl
    mov ostatok,bl
    xor ah,ah
    xor cx,cx
    jl get_float
    xor ah,ah
    xor cx,cx
    mov cl,0Ah
    floatLoop_word:
    div cl
    mov bl,ah
    mov [si],bl
    add [si],30h
    dec si
    xor ah,ah
    cmp al,09h
    ja floatLoop_word
    jmp get_float
     
get_ah_normal_with_znak:
    mov result_minus,'-'
    not ax
    inc ax    
                   
overflow:
 
    print_str over_flow               
Exit:
    mov ah, 4ch;
    int 21h
end start 

.MODEL small
.STACK 100h
.DATA
    sum dw 0000
    tempNum db 9 DUP(?)
    result dw 2 DUP(?)
    array dw 30 DUP(?)
    size db 0
    
    negativeFlag db 0
    dotFlag db 0
    overflowFlag db 0
    negativeOne equ -1 
    max dw -32768
    min dw 32767  
    
    errorSumOverflow db "Overflow!$"
    errorOverflow db "Overflow. Enter number between -32768 and 32767!$"
    errorNotANumber db "Not a number!$"
    errorSize db "Size must be between 1 and 30!$"   
    
        
    enterMessage db "Enter number: $"
    sizeMessage db "Enter size: $"
    
    rangeMin dw -32768
    rangeMax dw 32767

.CODE   

PrintString macro string
    push dx
    push ax
    lea dx, string
    mov ah, 09H
    int 21h
    pop ax
    pop dx
    endm

Newline macro
    push dx
    push ax

    mov ah, 02h
        
    mov dl, 0Ah ; \n
    int 21h
    mov dl, 0Dh ; \r
    int 21h

    pop ax
    pop dx
    endm

PrintResult proc
    push si
    push cx
    push ax
    push dx

    lea si, result
    xor cx, cx
    mov cl, 2
    m_printLoop:
        call ToString
        PrintString tempNum
        cmp dotFlag, 1
        je m_end
        mov ah, 02h
        mov dl, '.'
        int 21h
        m_end:
        add si, 2
        mov dotFlag, 1
        loop m_printLoop
    Newline
    pop dx
    pop ax
    pop cx
    pop si
    ret
    PrintResult endp

PrintArray proc
    push si
    push cx
    push ax
    push dx

    lea si, array
    xor cx, cx
    mov cl, size
    printLoop:
        call ToString
        PrintString tempNum
        mov ah, 02h
        mov dl, ' '
        int 21h
        add si, 2
    loop printLoop
    Newline
    pop dx
    pop ax
    pop cx
    pop si
    ret
    PrintArray endp

ReverseStr proc
    push ax
    push di
    push si

    xor di, di
    mov ah, tempNum[di]
    cmp ah, '-'
    jne getSI
    inc di
    getSI:
    mov si, di
    siLoop:
        cmp tempNum[si], '$'
        je loopFin
        inc si
        jmp siLoop
    loopFin:
    dec si

    reverseLoop:
        mov al, tempNum[si]
        mov ah, tempNum[di]
        mov tempNum[si], ah
        mov tempNum[di], al
        inc di
        dec si
        cmp di, si
        jl reverseLoop
    pop si
    pop di
    pop ax
    ret
    ReverseStr endp

ToString proc ;SI points to number
    push ax
    push cx
    push di
    push dx

    xor di, di
    mov ax, [si]
    cmp ax, -1
    jg posit
    mov tempNum[di], '-'
    inc di
    call ABS
    posit:
    mov cx, 10
    toSLoop:
        xor dx, dx
        div cx
        add dx, '0'
        mov tempNum[di], dl
        inc di
    cmp ax, 0
    jne toSLoop
    mov tempNum[di], '$'

    call ReverseStr

    pop dx
    pop di
    pop cx
    pop ax
    ret
    ToString endp

ABS proc ;AX contains number     
    push ax
    and ax, 8000h ;if number is negative upper bit is 1
                  ;== 1000 0000 0000 0000b
    jz done  

    pop ax
    xor ax, negativeOne
    inc ax
    push ax   
    
    done:  
    pop ax   
    ret
    ABS endp

GetString proc
    push si
    mov si, dx
    mov [si], 7

    mov ah, 0Ah
    int 21h 

    xor ax, ax
    inc si
    LODSB
 
    add si, ax
    mov [si + 1], '$'
   
    pop si
    ret
    GetString endp

ToInt proc
    push di
    push si
    push bx

    xor si, si
    mov si, 2
    cmp tempNum[si], '-'
    jne positive
    mov di, 1
    inc si

    positive:
        cmp tempNum[si], '0'
        jb notANumber
        cmp tempNum[si], '9'
        ja notANumber
    
    xor ax, ax
    mov cx, 10
    atoiLoop:
        xor bx, bx
        mov bl, tempNum[si]

        cmp bl, '0'
        jb parsed
        cmp bl, '9'
        ja parsed

        sub bl, '0'
        mul cx
        cmp dl, 0
        jg overflow
        add ax, bx
        
        mov bx, ax
        and bx, 8000h
        jnz overflow  

        inc si
    jmp atoiLoop

    overflow:
        cmp di, 1
        jne error
        cmp ax, 8000h
        je parsed
        error:
        PrintString errorOverflow     
        Newline
        jmp finish
    notANumber:
        PrintString errorNotANumber  
        Newline
        jmp finish

    parsed:      
        xor cx, cx
        cmp di, 1
        jne finish       
        xor ax, negativeOne
        inc ax
    finish:
    pop dx
    pop si
    pop di 
    ret
    ToInt endp  

FindAverage proc
    sub si, 2
    mov ch, 0
    mov cl, size

    sumLoop:
        mov dx, array[si]
        mov ax, sum
        add ax, dx
        jo sumOverflow
        mov sum, ax
        sub si, 2
    loop sumLoop
    
    mov dx, 0
    mov ax, sum
    cmp ax, -1
    jnle notNegative
    mov negativeFlag, 1
    neg ax
    notNegative: 
    mov cl, size
    mov ch, 0
    div cx
    cmp negativeFlag, 1
    jne mNotNegative
    neg ax
    mNotNegative:
    mov di, offset result
    mov [di], ax
    
    mov ax, dx
    mov dx, 0
    mov cx, 100
    mul cx
    mov cl, size
    mov ch, 0
    div cx
    
    mov [di + 2], ax  
    cmp overFlowFlag, 0
    je endFindAvg
    
    sumOverflow:
    mov overFlowFlag, 1 
    PrintString errorSumOverflow
    
    endFindAvg:
    ret        
    FindAverage endp

start:
    mov ax, @DATA
    mov ds, ax

    sizeInput:
    PrintString sizeMessage
    lea dx, tempNum
    call GetString
    Newline

    call ToInt
    cmp cx, 0
    jne sizeInput

    cmp ax, 0
    jle sizeError
    cmp ax, 30
    jg sizeError
    jmp pos
    sizeError:
    PrintString errorSize
    Newline
    jmp sizeInput
    
    pos:
    mov size, al

    xor si, si  
    xor cx, cx
    mov cl, size
    enterLoop:  
        PrintString enterMessage   
        lea dx, tempNum
        call GetString  
        Newline
         
        push cx
        call ToInt          
        cmp cx, 0  
        pop cx
        jne enterLoop

        mov array[si], ax  
        add si, 2 ;Add 2 because array is 2 byte
        inc size
        next:
        dec size
    loop enterLoop
    
    call FindAverage
    cmp overFlowFlag, 1
    jne printSuccess
    mov ax, 4c00h
    int 21h
    printSuccess:
    call PrintResult
    mov ax, 4c00h
    int 21h
end start
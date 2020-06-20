.286
.model small
.stack 100h

.data
    chunk_size equ 256
    chunk db chunk_size dup('$')
    chunk_last dw 0

    wordb_size equ 50
    wordb db wordb_size + 1 dup('$')
    wordb_last dw 0

    fname db 256 dup(0)
    number_buf db 256 dup(0)

    word_num dw 3
    word_counter dw 0

    fdesc dw 0
    read_pos dd 0
    write_pos dd 0

    base dw 10

    bad_file_msg db 'Cannot open file$'
    bad_args_msg db 'Wrong arguments', 10, 13, 'Use: file.exe filename word_number$'
    bad_num_msg  db 'Word number should [0, 32767]$'
    done_msg     db 'Done!$'
    endl         db 10, 13, '$'
.code

main:
    mov ax, @data
    mov ds, ax
    
    mov bl, es:[80h] ;args line length 
    add bx, 80h      ;args line last    
    mov si, 82h      ;args line start
    mov di, offset fname
    
    cmp si, bx
    ja bad_arguments
    
    parse_path:
    
        cmp BYTE PTR es:[si], ' ' 
        je parsed_path 
              
        mov al, es:[si]
        mov [di], al      
              
        inc di
        inc si
    cmp si, bx
    jbe parse_path
    
    parsed_path:  
    mov di, offset number_buf  
    inc si
    cmp si, bx
    ja bad_arguments  
     
    parse_number:
     
        cmp BYTE PTR es:[si], ' ' 
        je parsed_number 
              
        mov al, es:[si]
        mov [di], al      
              
        inc di
        inc si
    cmp si, bx
    jbe parse_number
    
    parsed_number:
    push 0
    mov di, offset number_buf 
    push di
    mov di, offset word_num 
    push di
    call atoi
    pop ax    
    pop ax 
    pop ax;error

    cmp ax, 1
    je bad_number

    cmp word_num, 0
    jl bad_number

    call process_file

    mov ax, offset done_msg 
    push ax
    call print_str  
    pop ax

    exit:
    mov ax, 4C00h
    int 21h

    bad_file:
    mov ax, offset bad_file_msg 
    push ax
    call print_str  
    pop ax
    jmp exit

    bad_arguments:
    mov ax, offset bad_args_msg 
    push ax
    call print_str  
    pop ax
    jmp exit

    bad_number:
    mov ax, offset bad_num_msg 
    push ax
    call print_str  
    pop ax
    jmp exit

    process_file:

        ;open target file
        mov dx, offset fname
        mov ah, 3Dh
        mov al, 02h
        int 21h
        mov fdesc, ax

        mov bx, ax
        jnc read_file_chunk
        jmp bad_file;error on open

        read_file_chunk:  
        mov ah, 42h
        mov cx, WORD PTR [offset read_pos]
        mov dx, WORD PTR [offset read_pos + 2]
        mov al, 0  
        mov bx, fdesc
        int 21h
        
        mov cx, chunk_size
        mov dx, offset chunk
        mov ah, 3Fh
        mov bx, fdesc
        int 21h
        jc close_file

        cmp ax, 0
        je close_file 
        
        mov cx, WORD PTR [offset read_pos]
        mov dx, WORD PTR [offset read_pos + 2]
        add dx, ax
        adc cx, 0
        mov WORD PTR [offset read_pos], cx
        mov WORD PTR [offset read_pos + 2], dx

        mov chunk_last, ax
        call process_chunk

        jmp read_file_chunk

        close_file:
        ;check word buffer
        call check_word   

        mov ah, 40h 
        mov cx, 0
        mov bx, fdesc
        mov dx, offset wordb
        int 21h   

        mov ah, 3Eh
        mov bx, fdesc
        int 21h
    ret

    process_chunk:
        pusha
        xor si, si

        process_chunk_loop:

            mov al, [chunk + si]
            
            mov di, wordb_last
            mov [wordb + di], al
            inc di
            mov wordb_last, di

            call check_separator
            cmp bx, 1 
            jne process_chunk_loop_inc 

            call check_word
            
            cmp al, 13
            jne process_chunk_loop_inc
            mov word_counter, 0

        process_chunk_loop_inc:
        inc si
        cmp si, chunk_last
        jb process_chunk_loop

        popa
    ret 
    
    check_separator:
        ;al - char
        mov bx, 1;separator flag
        
        cmp al, ' '
        je check_separator_exit      
        
        cmp al, 13
        je check_separator_exit  
        
        cmp al, 10
        je check_separator_exit  
                 
        mov bx, 0         
        
        check_separator_exit:
    ret

    check_word:
        mov bx, wordb_last
        dec bx
        cmp bx, 0
        jbe check_word_flush

        mov bx, word_counter
        inc bx  
        mov word_counter, bx
        cmp bx, word_num 
        jne check_word_flush     
        mov di, wordb_last
        dec di   
        mov bl, [wordb + di] 
        mov [wordb], bl 
        mov wordb_last, 1

        check_word_flush:
        call print    
    ret

    print:       
        ;print & clear wordb
        pusha

        mov ah, 42h
        mov cx, WORD PTR [offset write_pos]
        mov dx, WORD PTR [offset write_pos + 2]
        mov al, 0  
        mov bx, fdesc  
        int 21h
                     
        mov ah, 40h 
        mov cx, wordb_last
        mov bx, fdesc
        mov dx, offset wordb
        int 21h 
        
        mov ax, wordb_last
        mov cx, WORD PTR [offset write_pos]
        mov dx, WORD PTR [offset write_pos + 2]
        add dx, ax
        adc cx, 0
        mov WORD PTR [offset write_pos], cx
        mov WORD PTR [offset write_pos + 2], dx 
        
        mov wordb_last, 0

        popa
    ret

    ;first - result code, second - string start, third - 16-bit number address
    atoi:   
        push bp
        mov bp, sp   
        pusha        
        
        ;[ss:bp+4+0] - number address  
        ;[ss:bp+4+2] - string address 
        ;[ss:bp+4+4] - error if 1
        mov di, [ss:bp+4+2]  
        
        xor bx, bx     
        xor ax, ax   
        xor cx, cx
        xor dx, dx
        
        cmp BYTE PTR [di + bx], '-'
            jne atoi_loop
        
        inc cx; set negative after loop  
        inc bx
            
        ;parse until error
        atoi_loop:    
            
            cmp BYTE PTR [di + bx], '0'    
            jb atoi_error 
            cmp BYTE PTR [di + bx], '9'    
            ja atoi_error
                                
            mul base 
            mov dh, 0
            mov dl, [di + bx] 
            sub dl, '0'  
            add ax, dx  
            jo atoi_error      
        
        inc bx 
        cmp BYTE PTR [di + bx], 0
        jne atoi_loop  
        
        jmp atoi_result 
        
        atoi_error:
            mov BYTE PTR [ss:bp+4+4], 1    
            jmp atoi_end 
        
        atoi_result:
            mov BYTE PTR [ss:bp+4+4], 0  
            cmp cx, 1
            jne atoi_end
            neg ax
        
        atoi_end: 
            mov di, [ss:bp+4+0]
            mov [di], ax 
        
        popa
        pop bp
    ret 

    print_str:     
        push bp
        mov bp, sp   
        pusha 
        
        mov dx, [ss:bp+4+0]     
        mov ax, 0900h
        int 21h 
        
        mov dx, offset endl
        mov ax, 0900h
        int 21h  
        
        popa
        pop bp      
    ret  

end main

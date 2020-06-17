.model small
.stack 100h

.data

FILE_NAME_SIZE equ 127

file_name db FILE_NAME_SIZE dup(0)
result_file_name db FILE_NAME_SIZE dup(0)
                
CMD_LINE_SIZE equ 128                
command_line db CMD_LINE_SIZE dup(0)

a_ASCII equ 61h
POINT_ASCII equ 2Eh
SLASH_ASCII equ 2Fh  

file_id dw 0
result_file_id dw 0 

error_message1 db "Unable to open a file",13,10,'$'
error_message2 db "Unable to create and open temp file",13,10,'$'

error_message3 db "Unable to close a file",13,10,'$'
error_message4 db "Unable to delete a file",13,10,'$'
error_message5 db "Invalid input",13,10,'$'
error_message6 db "Unable to rename a file",13,10,'$'
error_message7 db "File name is too long",13,10,'$'

SPACE equ 20h
TAB equ 9h
NEW_LINE equ 0Ah
CARRIAGE_RETURN equ 0Dh

MAX_BUFFER_SIZE equ 2048

buffer db MAX_BUFFER_SIZE dup(0)

.code

show_str MACRO
    push ax
    
    mov ah,9
    int 21h
    
    pop ax    
ENDM

open_file PROC
    push cx dx
    
    mov ah,3Dh
    mov al,02h
    mov cl,0
    int 21h
    
    jnc file_opened
    
    mov dx,offset error_message1
    show_str
    
    file_opened:
    
    pop dx cx
    ret
open_file ENDP

create_and_open_file PROC
    push dx
    
    mov ah,5Bh
    mov cl,0
    int 21h
    
    jnc file_created_and_opened
    
    mov dx,offset error_message2
    show_str
    
    file_created_and_opened:
    
    pop dx
    ret
create_and_open_file ENDP    

read_line_from_file PROC
    push ax bx cx dx
    
    mov bx,file_id
    lea si,buffer
    push si
    mov cx,1
    
    read_character:
    mov ah,3Fh
    mov dx,si
    int 21h
    
    cmp ax,0
    jne read_something
    jmp end_of_reading
    read_something:
    inc si
    
    cmp byte ptr [si-1],NEW_LINE
    jne read_character
    
    end_of_reading:
    
    pop ax
    sub si,ax
    
    pop dx cx bx ax
    ret
read_line_from_file ENDP
    
is_delimiter PROC
    xor ah,ah
    
    cmp al,SPACE
    jne not_space
    mov ah,1
    not_space:
    
    cmp al,TAB
    jne not_tab
    mov ah,1
    not_tab:
    
    ret
is_delimiter ENDP

find_word PROC
    push bp
    mov bp,sp
    push ax cx si 
    
    mov si,[bp+4]
    
    handle_word:
    
    skip_delimiter:
    mov al,[si]
    call is_delimiter
    
    cmp ah,1
    je found_delimiter
    jmp stop_reading_string
    found_delimiter:
    
    cmp cx,0
    jne string_end_not_reached
    jmp stop_reading_string
    string_end_not_reached:
    
    inc si
    dec cx
    
    jmp handle_word
    stop_reading_string:
    
    mov bx,si
    sub bx,[bp+4]
    
    skip_character:
    
    mov al,[si]
    call is_delimiter
    
    cmp ah,1
    jne not_delimiter
    jmp word_read
    not_delimiter:
    
    cmp cx,0
    jne can_read_more
    jmp word_read
    can_read_more:
    
    cmp al,CARRIAGE_RETURN
    jne not_the_end
    jmp word_read
    not_the_end:

    inc si
    dec cx
    jmp skip_character
    
    word_read:
    
    mov di,si
    sub di,[bp+4]
    cmp bx,di
    je word_not_found
    dec dx
    word_not_found:
    
    cmp cx,0
    jne not_end_of_string
    jmp out_of_loop
    not_end_of_string:
    
    cmp dx,0
    jne not_this_word
    jmp out_of_loop
    not_this_word:
    
    cmp byte ptr [si],CARRIAGE_RETURN
    jne not_stop
    jmp out_of_loop
    not_stop:
    
    jmp handle_word
    
    out_of_loop:
    
    pop si cx ax bp
    ret
find_word ENDP

delete_word PROC
    push ax cx
    
    shift_character:
    
    mov al,buffer[di]
    mov buffer[bx],al
    
    inc bx
    inc di
    dec cx
    
    cmp cx,0
    jne shift_character
    
    pop cx ax
    ret
delete_word ENDP

delete_words_in_file PROC
    push bx cx dx si di
    
    handle_line:
    call read_line_from_file

    cmp si,0
    jne read_line
    jmp end_of_file_reached
    read_line:
    
    mov cx,si
    mov dx,ax
    push offset buffer
    call find_word
    add sp,2
    
    cmp dx,0
    jne no_word_to_delete
    
    sub cx,di
    call delete_word
    mov cx,bx
    
    no_word_to_delete:
    
    mov si,cx
    mov buffer[si],'$'
    call write_line_to_file

    jmp handle_line
    
    end_of_file_reached:
    
    pop di si dx cx bx
    ret
delete_words_in_file ENDP

write_line_to_file PROC
    push ax bx
    
    mov ah,40h
    mov bx,[result_file_id]
    mov dx,offset buffer
    int 21h
    
    pop bx ax
    ret
write_line_to_file ENDP

read_command_line PROC
    push cx si di
    
    xor cx,cx
    mov cl,ds:[0080h]
    mov bx,cx
   
    mov si,81h
    lea di,command_line
    
    rep movsb
    
    pop di si cx
    ret
read_command_line ENDP

is_digit PROC
    xor ch,ch
    
    cmp cl,30h
    jge greater_than_zero
    jmp not_a_number
    greater_than_zero:
    
    cmp cl,39h
    jle less_than_nine
    jmp not_a_number
    less_than_nine:
    
    mov ch,1
    not_a_number:
    
    ret
is_digit ENDP    

get_number_from_cmd_line PROC
    push bx cx dx si
    
    mov dx,2
    mov cx,bx
    push offset command_line
    call find_word
    add sp,2
    
    cmp dx,0
    jne invalid_input
    
    mov si,10
    xor ax,ax
    get_another_digit:
    
    mov cl,command_line[bx]
    
    cmp bx,di
    jne not_end_of_number
    jmp end_of_number
    not_end_of_number:
    
    call is_digit
    cmp ch,1
    je digit_read
    jmp invalid_input
    digit_read:
    
    mul si
    jno not_overflow
    jmp invalid_input
    not_overflow:
    
    xor ch,ch
    sub cx,30h
    add ax,cx
    jno not_of
    jmp invalid_input
    not_of:
    
    inc bx
    jmp get_another_digit
    
    end_of_number:
    jmp proc_end 
    
    invalid_input:
    xor ax,ax
    
    proc_end:
    pop si dx cx bx
    ret
get_number_from_cmd_line ENDP

get_file_name_from_cmd_line PROC
    push cx bx dx si di
    
    xor ax,ax
    mov dx,1
    mov cx,bx
    push offset command_line
    call find_word
    add sp,2
    
    cmp dx,0
    jne file_name_not_found
    
    mov cx,di
    sub cx,bx
    mov ax,cx
    
    mov di,offset file_name
    mov si,bx
    add si,offset command_line
    
    rep movsb
    
    file_name_not_found:
    pop di si dx bx cx
    ret
get_file_name_from_cmd_line ENDP

set_temp_file_name PROC
    push ax cx si di 
    
    mov si,offset file_name
    mov di,offset result_file_name
    
    mov cx,ax
    
    rep movsb
    
    sub di,5
    mov al,a_ASCII
    change_file_name:
    
    cmp al,[di]
    jne file_name_changed
    inc al
    jmp change_file_name
    file_name_changed: 
    
    mov [di],al
    
    pop di si cx ax
    ret
set_temp_file_name ENDP    

close_file PROC
    push ax
    
    mov ah,3Eh
    int 21h
    
    jnc file_closed
    mov dx,offset error_message3
    show_str
    file_closed:
    
    pop ax
    ret
close_file ENDP

delete_file PROC
    push ax
    
    mov ah,41h
    int 21h
    
    jnc file_deleted
    mov dx,offset error_message4
    show_str
    file_deleted:
    
    pop ax
    ret
delete_file ENDP

rename_file PROC
    push ax dx di
    
    mov ah,56h
    mov dx,offset result_file_name
    mov di,offset file_name
    int 21h
    
    jnc file_renamed
    mov dx,offset error_message6
    show_str
    file_renamed:
    
    pop di dx ax
    ret
rename_file ENDP

start:

mov ax,@data
mov es,ax

call read_command_line
mov ds,ax

call get_file_name_from_cmd_line
cmp ax,0
je invalid_parameter
call set_temp_file_name
 
call get_number_from_cmd_line
mov bx,ax
cmp ax,0
je invalid_parameter

mov dx,offset file_name
call open_file
jc _end

mov [file_id],ax

mov dx,offset result_file_name
call create_and_open_file
jc _end

mov [result_file_id],ax

mov ax,bx
call delete_words_in_file

mov bx,[result_file_id]
call close_file
jc _end

mov bx,[file_id]
call close_file
jc _end

mov dx,offset file_name
call delete_file
jc _end

call rename_file

_end:
jmp skip_output_msg

invalid_parameter:
mov dx,offset error_message5
show_str

skip_output_msg:

mov ax,4c00h
int 21h

end start

 
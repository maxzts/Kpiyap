.286
.model tiny
.code
org 100h

begin:
	jmp start 

count dw 9
temp dw 0
screen dw 2000 dup (?)
screen_sz equ 2000
oldInt08h dd 0

second_resident db 157


newInt08h proc far
	pushf
	call dword ptr cs:oldInt08h
	
	pusha
	push cs
	pop ds

	call copy_screen

	call check_right_comma
	call check_left_comma

	call push_screen
	
stop_08h:	

	popa
	iret
	
endp newInt08h

copy_screen proc
	pusha
	
	push 0b800h
	pop es
	xor di, di
	mov cx, screen_sz
	copy_screen_loop:
		mov ax, es:[di]
		mov [screen+di], ax
		mov byte ptr [screen+di+1], byte ptr 7
		add di,2
		loop copy_screen_loop

	xor di, di

	popa
	ret
endp copy_screen


push_screen proc
	pusha
	
	push 0b800h
	pop es
	xor di, di
	mov cx, screen_sz
	lea si, screen
	rep movsw	
	popa
	ret
push_screen endp

check_right_comma proc 
	pusha

	xor di, di
	mov temp, 0
	mov cx, screen_sz
	find_right_comma:
		cmp byte ptr [screen+di], byte ptr "("
		jne crc_not_left
		add temp, 1
		crc_not_left:
		cmp byte ptr [screen+di], byte ptr ")"
		jne crc_inc
		cmp temp, 0
		jne crc_dec_temp
		mov byte ptr [screen+di+1], byte ptr 0Cfh
		jmp crc_inc

		crc_dec_temp:
		dec temp
		crc_inc:
		add di, 2
		loop find_right_comma

	popa
	ret 
check_right_comma endp

check_left_comma proc 
	pusha

	mov di, screen_sz
	shl di, 1
	sub di, 2
	mov temp, 0
	mov cx, screen_sz
	find_left_comma:
		cmp byte ptr [screen+di], byte ptr ")"
		jne clc_not_right
		add temp, 1
		clc_not_right:
		cmp byte ptr [screen+di], byte ptr "("
		jne clc_dec
		cmp temp, 0
		jne clc_dec_temp
		mov byte ptr [screen+di+1], byte ptr 0Cfh
		jmp clc_dec

		clc_dec_temp:
		dec temp
		clc_dec:
		sub di, 2
		loop find_left_comma

	popa
	ret 
check_left_comma endp

start:
	
	

	mov al, 08h
	mov ah, 35h
	int 21h
	
	mov word ptr oldInt08h, bx
	mov word ptr oldInt08h +2, es

	call check_resident

	cli
	
	mov ah,25h
	mov al, 08h
	mov dx, offset newInt08h
	int 21h
	
	sti 

	mov dx, offset start
	int 27h


exit:
	mov ah, 4ch
	int 21h



check_resident proc 
	mov di, offset second_resident
	mov al, byte ptr second_resident
	cmp al, byte ptr es:[di]
	jne cr_continue
	mov ah, 09h
	mov dx, offset reload_resident_str
	int 21h 
	jmp exit
	cr_continue:
	ret
check_resident endp



reload_resident_str db "Resident is already in memory", 10, 13, "$"

	end begin
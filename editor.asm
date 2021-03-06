;; mode: nasm

bits 16
org 0x7c00
	jmp main

%macro cls 0
	mov ah, 0x00
	mov al, 0x03
	int 0x10
%endmacro

%macro read_character 0
	mov ah, 0
	int 0x16
%endmacro

%macro print_character 1
	mov ax, %1
	mov ah, 0x0e
	int 0x10
%endmacro

%macro get_position 0
	mov ah, 0x03
	int 0x10
%endmacro

%macro set_position 0
	mov ah, 0x02
	int 0x10
%endmacro

goto_end_of_line:
	mov ah, 0x08
	int 0x10

	;; Iterate until the character is null
	cmp al, 0
	jz .done

	inc dl
	set_position
	jmp goto_end_of_line

.done:
	ret

%macro mov_read_ctrl_flag_intro 1
	mov %1, [0x0417]
	and %1, 0x04 		;; Grab 3rd bit: 0b0100
%endmacro

%macro mov_read_character_into 1
	mov eax, [0x041a]
	add eax, 0x03fe		;; offset from 0x0400 sizeof(uint16)
	and eax, 0xFFFF

	mov %1, [eax]
	and %1, 0xFF
%endmacro

editor_action:
	read_character

	cmp ah, 0x4b	;; Left
	jz .done
	cmp ah, 0x50	;; Down
	jz .done
	cmp ah, 0x4d	;; Right
	jz .done
	cmp ah, 0x48	;; Up
	jz .done

	cmp al, 0x08
	jz .is_backspace

	cmp al, 0x7F 	;; For mac keyboards
	jnz .done_backspace

.is_backspace:
	get_position

	cmp dl, 0
	jz .backspace_at_start_of_line
	dec dl	; Decrement column
	set_position
	jmp .overwrite_character

.backspace_at_start_of_line:
	dec dh	; Decrement row
	set_position

	call goto_end_of_line

.overwrite_character:
	mov al, 0
	mov ah, 0x0a
	int 0x10

	jmp .done

.done_backspace:
	mov_read_character_into ax
	cmp al, 0x0d
	jnz .done_enter

	get_position
	inc dh			;; Increment line
	mov dl, 0		;; Reset column
	set_position

	jmp .done

.done_enter:
	;; Handle ctrl

	;; Check ctrl key
	mov_read_ctrl_flag_intro ax
		jz .ctrl_not_set

;; Handle ctrl-a
	mov_read_character_into ax
	cmp al, 1	;; For some reason with ctrl
	jnz .not_ctrl_a

;; Reset column
	mov dl, 0
	set_position

	jmp .done

.not_ctrl_a:

;; Handle ctrl-e
	mov_read_character_into ax
	cmp al, 5
	jnz .not_ctrl_e

	call goto_end_of_line
	jmp .done

.not_ctrl_e:
	jmp .done

.ctrl_not_set:
	mov_read_character_into ax
	print_character ax

.done:
	ret

main:
	cls

.loop:
	call editor_action
	jmp .loop

times 510 - ($-$$) db 0
dw 0xaa55

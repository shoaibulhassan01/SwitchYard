org 0x100

    jmp start



E1: db 'ENTRY 1>'
E2: db 'ENTRY 2>'
E_Len: dw 8

SA: db 'STATION A'
SB: db 'STATION B'
SC: db 'STATION C'
SD: db 'STATION D'
S_Len: dw 9

msg_ok:  db 'CORRECT: '      ; score labels (9 and 7 characters)
msg_bad: db 'WRONG: '



correct_cnt: db 0             ; trains that reached correct station
wrong_cnt:   db 0             ; trains that reached a wrong station
seed:        dw 0             ; seed for the random number generator
next_entry:  db 0             ; which entry gets the next train (0 = Entry 1, 1 = Entry 2)
spawn_cnt:   db 1             ; frames left before the next train comes



; every stop is 3 bytes: row, col, station id (A=0, B=1, C=2, D=3)
stops:     db 3,58,0,   6,30,1,   10,64,2,   14,46,3,   19,58,3
st_col:    db 0Ch,0Dh,0Ah,09h   ; color of each station id (A red, B magenta, C green, D blue)

; ----- data of every train (8 trains, one byte per train) -----
t_on:   db 0,0,0,0,0,0,0,0    ; 1 = train is running, 0 = slot is free
t_row:  db 0,0,0,0,0,0,0,0    ; train row
t_col:  db 0,0,0,0,0,0,0,0    ; train column
t_dr:   db 0,0,0,0,0,0,0,0    ; direction (row step)
t_dc:   db 0,0,0,0,0,0,0,0    ; direction (column step)
t_dest: db 0,0,0,0,0,0,0,0    ; destination station id (0-3)
t_uch:  db 0,0,0,0,0,0,0,0    ; character under the train
t_uat:  db 0,0,0,0,0,0,0,0    ; color under the train

str_attr:  db 0Fh                             ; print_str ka color

state: db 0,0,0,0                             ; State of every switch (0=straight, 1=diverted)
quit:  db 0                                   ; Becomes 1 on pressing ESC
old9:  dd 0                                   ; old keyboard handler save here



;store every switch's next path(row,col) ; for changing colors after the gates, ie (green = open , red = closed) 
branch_tbl: db 3,15,  4,14      ; S1: east / south
            db 19,15, 18,14     ; S2: east / north
            db 9,30,  10,31     ; S3: north / east
            db 10,47, 11,46     ; S4: east / south




kb_isr:

    push ax
    push bx

    in al, 60h               ; Read scancode from KB, ESC-> 01h, 1->02h, 2->03h, 3->04h, 4->05h
    test al, 80h             ; checking bit 7, key released? do nothing
    jnz kb_done

    cmp al, 01h              ; ESC?
    jne kb_check
    mov byte [cs:quit], 1
    jmp kb_done

 kb_check:
    cmp al, 02h              ; key < 1 ? ignore
    jb kb_done
    cmp al, 05h              ; key  > 4 ? ignore
    ja kb_done
    sub al, 02h              ; 0 -> 3 indexing for state array
    xor ah, ah
    mov bx, ax
    xor byte [cs:state + bx], 1   ; switch toggle (0 <-> 1)

 kb_done:
    mov al, 20h
    out 20h, al              ; EOI
    pop bx
    pop ax
    iret





start:


    mov ax, 3509h            ; remove old keyboard handler, Ah = 35 means read interrupt vector and AL = 09 means int 09h
    int 21h         
    mov [old9], bx           ; old KB handler address saveed in ES:BX
    mov [old9+2], es
    mov dx, kb_isr           ; our handler
    mov ax, 2509h            ; Ah = 25h means set interrupt vector and AL = 09 means int 09h
    int 21h



    mov ax, 0x0003  ; clear screen
    int 10h

    mov ax, 0xb800
    mov es, ax


    mov ax, 3     ; horizontal line printing
    mov bx, 8
    mov cx, 51
    call hline

    mov ax, 19
    mov bx, 8
    mov cx, 51
    call hline

    mov ax, 10
    mov bx, 14
    mov cx, 51
    call hline


    mov ax, 3     ; Vertical line printing
    mov bx, 14
    mov cx, 17
    call vline

    mov ax, 6
    mov bx, 30
    mov cx, 5
    call vline

    mov ax, 10
    mov bx, 46
    mov cx, 5
    call vline


    mov ax, 10      ; prints intersection switches
    mov bx, 14
    mov cl, '+'
    call Print_Switch

    mov ax, 3
    mov bx, 14
    mov cl, '1'
    call Print_Switch

    mov ax, 19
    mov bx, 14
    mov cl, '2'
    call Print_Switch

    mov ax, 10
    mov bx, 30
    mov cl, '3'
    call Print_Switch

    mov ax, 10
    mov bx, 46
    mov cl, '4'
    call Print_Switch



    mov byte [str_attr], 0Fh   ; entries white
    mov ax, 3                ; print Entry1
    mov bx, 0
    mov si, E1
    mov cx, [E_Len]
    call print_str

    mov ax, 19               ; print Entry2
    mov bx, 0
    mov si, E2
    mov cx, [E_Len]
    call print_str



    mov byte [str_attr], 0Ch   ; red
    mov ax, 3                  ; print station A string
    mov bx, 59
    mov si, SA
    mov cx, [S_Len]
    call print_str

    mov byte [str_attr], 0Dh   ; majenta
    mov ax, 5                  ; print station B
    mov bx, 30
    mov si, SB
    mov cx, [S_Len]
    call print_str

    mov byte [str_attr], 0Ah   ; green
    mov ax, 10                 ; print station C
    mov bx, 65
    mov si, SC
    mov cx, [S_Len]
    call print_str

    mov byte [str_attr], 09h   ; blue
    mov ax, 15                 ; print station D
    mov bx, 46
    mov si, SD
    mov cx, [S_Len]
    call print_str

    mov ax, 19                 ; print station D
    mov bx, 59
    mov si, SD
    mov cx, [S_Len]
    call print_str





    xor ah, ah               ; get BIOS timer ticks (comes in DX)
    int 1Ah
    mov [seed], dx           ; use it as random seed




main_loop:

    call erase_trains        ; 1) put track back under every train
    call draw_switches       ; 2) update gate colors (green = open, red = closed)
    call move_trains         ; 3) move every train one step
    call spawn_train         ; 4) send a new train if it is time
    call draw_trains         ; 5) draw every train
    call draw_score          ; 6) show correct / wrong count
    call delay               ; 7) wait for next frame
    cmp byte [quit], 0       ; ESC pressed?
    je main_loop

    ;when ESC key is pressed
    push ds                  ; retreive old keyboard handler 
    lds dx, [old9]
    mov ax, 2509h
    int 21h
    pop ds


    mov ax, 4C00h            ; exit
    int 21h






calculate_di:     ; calculates di offset

    mov dx, 80
    mul dx
    add ax, bx
    add ax, ax
    mov di, ax
    ret



hline:
    call calculate_di

  hloop:
      mov byte [es:di], '-'
      mov byte [es:di+1], 07h
      add di, 2

     loop hloop
     ret


vline:
    call calculate_di

  vloop:
      mov byte [es:di], '|'
      mov byte [es:di+1], 07h
      add di, 160

     loop vloop
     ret


Print_Switch:

    call calculate_di

    mov [es:di], cl
    mov byte [es:di+1], 0x0E

    ret




print_str:

    call calculate_di

  strloop:

     mov al, [si]
     mov [es:di], al
     mov al, [str_attr]
     mov [es:di+1], al
     inc si
     add di, 2

    loop strloop
    ret




print_num:                   ; in: AX = row, BX = col, CL = number (0-255), prints 3 digits
    call calculate_di        ; DI = screen position (CL is not changed)

    mov al, cl
    xor ah, ah
    mov cl, 100
    div cl                   ; AL = hundreds, AH = remaining
    add al, '0'              ; digit -> character
    mov [es:di], al
    mov byte [es:di+1], 0Fh

    mov al, ah
    xor ah, ah
    mov cl, 10
    div cl                   ; AL = tens, AH = ones
    add al, '0'
    mov [es:di+2], al
    mov byte [es:di+3], 0Fh

    add ah, '0'
    mov [es:di+4], ah
    mov byte [es:di+5], 0Fh
    ret




draw_score:                  ; show "CORRECT: 000   WRONG: 000" on row 22
    pusha

    mov byte [str_attr], 0Ah ; green
    mov ax, 22
    mov bx, 0
    mov si, msg_ok
    mov cx, 9
    call print_str

    mov ax, 22
    mov bx, 9
    mov cl, [correct_cnt]
    call print_num

    mov byte [str_attr], 0Ch ; red
    mov ax, 22
    mov bx, 20
    mov si, msg_bad
    mov cx, 7
    call print_str

    mov ax, 22
    mov bx, 27
    mov cl, [wrong_cnt]
    call print_num

    popa
    ret




rand:                        ; in: CL = n    out: AL = random number from 0 to n-1
    push bx
    push dx
    mov ax, [seed]
    mov dx, 25173
    mul dx                   ; seed = seed * 25173 + 13849
    add ax, 13849
    mov [seed], ax
    mov al, ah               ; high byte is more random than low byte
    xor ah, ah
    div cl                   ; AH = remainder = number from 0 to n-1
    mov al, ah
    xor ah, ah
    pop dx
    pop bx
    ret





draw_switches:               ; open route green, closed route red

    pusha
    xor si, si
  sw_loop:
    mov bp, si
    shl bp, 2                ; every switch is of 4 bytes (si * 4)

    ; route 0
    mov cl, 0Ch              ; red (closed)
    cmp byte [state+si], 0
    jne route0_done
    mov cl, 0Ah              ; green (open)

 route0_done:
    xor ah, ah
    mov al, [branch_tbl + bp]
    xor bh, bh
    mov bl, [branch_tbl + bp + 1]
    call calculate_di
    mov [es:di + 1], cl

    ; route 1
    mov cl, 0Ch              ; red (closed)
    cmp byte [state+si], 1
    jne route1_done
    mov cl, 0Ah              ; green (open)

 route1_done:
    xor ah, ah
    mov al, [branch_tbl + bp + 2]
    xor bh, bh
    mov bl, [branch_tbl + bp + 3]
    call calculate_di
    mov [es:di + 1], cl

    inc si
    cmp si, 4
    jb sw_loop      ;loop 4 times for 4 switches
    popa
    ret




erase_trains:                ; put the old track back under every running train
    pusha
    mov si, 7                ; go from the last train (7) to the first (0)
er_loop:
    cmp byte [t_on+si], 0
    je er_next               ; slot is free, skip

    xor ah, ah
    mov al, [t_row+si]
    xor bh, bh
    mov bl, [t_col+si]
    call calculate_di

    mov al, [t_uch+si]       ; old character
    mov [es:di], al
    mov al, [t_uat+si]       ; old color
    mov [es:di+1], al
er_next:
    dec si
    jns er_loop              ; stop after slot 0
    popa
    ret




draw_trains:                 ; draw every running train
    pusha
    xor si, si               ; start from train 0
dr_loop:
    cmp byte [t_on+si], 0
    je dr_next               ; slot is free, skip

    xor ah, ah
    mov al, [t_row+si]
    xor bh, bh
    mov bl, [t_col+si]
    call calculate_di

    mov al, [es:di]          ; save what is under the train
    mov [t_uch+si], al
    mov al, [es:di+1]
    mov [t_uat+si], al

    mov bl, [t_dest+si]      ; BX = destination station id
    mov al, 'A'
    add al, bl               ; letter of the destination (A, B, C or D)
    mov [es:di], al
    mov al, [st_col+bx]      ; color of the destination station
    mov [es:di+1], al
dr_next:
    inc si
    cmp si, 8
    jb dr_loop
    popa
    ret




move_trains:                 ; move every running train one step
    pusha
    xor si, si               ; start from train 0
mv_loop:
    cmp byte [t_on + si], 0
    je mv_next               ; slot is free, skip

    mov al, [t_dr + si]      ; one step in current direction
    add [t_row + si], al
    mov al, [t_dc + si]
    add [t_col + si], al

    call check_switches      ; turn if train is on a switch
    call check_station       ; remove train if it reached a station
mv_next:
    inc si
    cmp si, 8
    jb mv_loop
    popa
    ret




check_switches:              ; in: SI = train number

    ; --- Switch 1 (3,14): state 1 then south ---
    cmp byte [t_row + si], 3
    jne cw_s2
    cmp byte [t_col + si], 14
    jne cw_s2
    cmp byte [state], 0
    je cw_s2                 ; state 0 = east, same direction
    mov byte [t_dr + si], 1  ; else south
    mov byte [t_dc + si], 0

cw_s2:                       ; --- Switch 2 (19,14): state 1 then north ---
    cmp byte [t_row + si], 19
    jne cw_plus
    cmp byte [t_col + si], 14
    jne cw_plus
    cmp byte [state + 1], 1
    jne cw_plus              ; state 0 = east, same direction
    mov byte [t_dr + si], 0FFh   ; -1 = north
    mov byte [t_dc + si], 0

cw_plus:                     ; --- + (10,14): always east ---
    cmp byte [t_row + si], 10
    jne cw_s3
    cmp byte [t_col + si], 14
    jne cw_s3
    mov byte [t_dr + si], 0
    mov byte [t_dc + si], 1  ; east

cw_s3:                       ; --- Switch 3 (10,30): state 0 then north ---
    cmp byte [t_row + si], 10
    jne cw_s4
    cmp byte [t_col + si], 30
    jne cw_s4
    cmp byte [state + 2], 0
    jne cw_s4                ; state 1 = east, same direction
    mov byte [t_dr + si], 0FFh   ; -1 = north
    mov byte [t_dc + si], 0

cw_s4:                       ; --- Switch 4 (10,46): state 1 then south ---
    cmp byte [t_row + si], 10
    jne cw_end
    cmp byte [t_col + si], 46
    jne cw_end
    cmp byte [state + 3], 1
    jne cw_end               ; state 0 = east, same direction
    mov byte [t_dr + si], 1  ; south
    mov byte [t_dc + si], 0

cw_end:
    ret




check_station:               ; in: SI = train number
    xor bx, bx               ; BX = position in stops table
cst_loop:
    mov al, [stops + bx]     ; station row
    cmp al, [t_row + si]
    jne cst_next
    mov al, [stops + bx + 1] ; station column
    cmp al, [t_col + si]
    jne cst_next

    mov byte [t_on + si], 0  ; train reached a station, it disappears

    mov al, [stops + bx + 2] ; id of this station
    cmp al, [t_dest + si]    ; same as train's destination?
    jne cst_wrong
    inc byte [correct_cnt]   ; right station
    ret
cst_wrong:
    inc byte [wrong_cnt]     ; wrong station
    ret

cst_next:
    add bx, 3                ; next stop (3 bytes each)
    cmp bx, 15               ; 5 stops x 3 bytes
    jb cst_loop
    ret




spawn_train:                 ; send a new train when the countdown ends
    pusha
    dec byte [spawn_cnt]
    jnz sp_done              ; not time yet

    xor si, si               ; look for a free slot
sp_find:
    cmp byte [t_on + si], 0
    je sp_found
    inc si
    cmp si, 8
    jb sp_find
    jmp sp_reset             ; no free slot, try again later

sp_found:
    mov byte [t_on + si], 1  ; train is running now
    mov byte [t_col + si], 8 ; both entries start at column 8
    mov byte [t_dr + si], 0
    mov byte [t_dc + si], 1  ; going east

    cmp byte [next_entry], 0
    jne sp_entry2

    mov byte [t_row + si], 3 ; Entry 1 (row 3)
    mov cl, 4
    call rand                ; random destination A, B, C or D (0-3)
    mov [t_dest + si], al
    mov byte [next_entry], 1 ; next train comes from Entry 2
    jmp sp_reset

sp_entry2:
    mov byte [t_row + si], 19 ; Entry 2 (row 19)
    mov cl, 3
    call rand                ; random destination B, C or D (1-3), A is not reachable
    inc al
    mov [t_dest + si], al
    mov byte [next_entry], 0 ; next train comes from Entry 1

sp_reset:
    mov cl, 10
    call rand                ; random 0-9
    add al, 18               ; 18-27 frames = about 2 to 3 seconds
    mov [spawn_cnt], al
sp_done:
    popa
    ret




delay:                       ; wait until 2 timer ticks have passed

    push ax
    push bx
    push cx
    push dx
    xor ah, ah
    int 1Ah                  ; DX = current tick
    mov bx, dx               ; remember the start tick
d_wait:
    xor ah, ah
    int 1Ah
    sub dx, bx               ; ticks passed so far
    cmp dx, 2
    jb d_wait                ; not 2 ticks yet, keep waiting
    pop dx
    pop cx
    pop bx
    pop ax
    ret

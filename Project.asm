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

train_row: db 3       ; train start row & column
train_col: db 8
train_dr:  db 0                               ; train direction row
train_dc:  db 1                               ; train direction column
under_ch:  db '-'                             ; under train character & attribute
under_at:  db 07h                             
stop_tbl:  db 3,58,  6,30,  10,64,  14,46     ; SA, SB, SC, SD stopping points
str_attr:  db 0Fh                             ; print_str ka color

state: db 0,0,0,0                 ; State of every switch (0=straight, 1=diverted)
quit:  db 0                       ; Becomes 1 on pressing ESC
old9:  dd 0                       ; old keyboard handler save here

; har switch: (row,col) route0 ka pehla cell, (row,col) route1 ka pehla cell
branch_tbl: db 3,15,  4,14      ; S1: east / south
            db 19,15, 18,14     ; S2: east / north
            db 9,30,  10,31     ; S3: north / east
            db 10,47, 11,46     ; S4: east / south




kb_isr:

    push ax
    push bx
    in al, 60h               ; keyboard se scancode padho
    test al, 80h             ; key chhodi gayi? to kuch mat karo
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
    sub al, 02h              ; 0 -> 3 
    xor ah, ah
    mov bx, ax
    xor byte [cs:state+bx], 1   ; switch toggle (0 <-> 1)

 kb_done:
    mov al, 20h
    out 20h, al              ; EOI
    pop bx
    pop ax
    iret





start:


    mov ax, 3509h            ; remove old keyboard handler 
    int 21h
    mov [old9], bx
    mov [old9+2], es
    mov dx, kb_isr           ; our handler
    mov ax, 2509h
    int 21h



    mov ax, 0003h  ; clear screen
    int 10h

    mov ax, 0B800h
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

    mov ax, 19              ; print Entry2
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


main_loop:

    call move_train
    call draw_switches       ; <-- naya: gate ke colors (green = open, red = closed)
    call delay
    cmp byte [quit], 0       ; ESC pressed?
    je main_loop

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



draw_switches:               ; open route green, closed route red
    pusha
    xor si, si
sw_loop:
    mov bp, si
    shl bp, 2                ; har switch ki 4 bytes (si * 4)

    ; route 0
    mov cl, 0Ch              ; red (band)
    cmp byte [state+si], 0
    jne route0_done
    mov cl, 0Ah              ; green (khula)
route0_done:
    xor ah, ah
    mov al, [branch_tbl+bp]
    xor bh, bh
    mov bl, [branch_tbl+bp+1]
    call calculate_di
    mov [es:di+1], cl

    ; route 1
    mov cl, 0Ch              ; red (band)
    cmp byte [state+si], 1
    jne route1_done
    mov cl, 0Ah              ; green (khula)
route1_done:
    xor ah, ah
    mov al, [branch_tbl+bp+2]
    xor bh, bh
    mov bl, [branch_tbl+bp+3]
    call calculate_di
    mov [es:di+1], cl

    inc si
    cmp si, 4
    jb sw_loop
    popa
    ret




move_train:
    pusha

                              
    xor ah, ah               ; 1) Printing - at the previous train location
    mov al, [train_row]
    xor bh, bh
    mov bl, [train_col]
    call calculate_di

    mov al, [under_ch]
    mov [es:di], al
    mov al, [under_at]
    mov [es:di+1], al



                            
    mov al, [train_dr]         ; 2) one step increasing (row or column)
    add [train_row], al
    mov al, [train_dc]
    add [train_col], al


    ; 3) switch checks (train ne naya cell le liya, ab dekho switch par hai ya nahi)

    ; --- Switch 1 (3,14): state 1 ho to south ---
    cmp byte [train_row], 3
    jne chk_plus
    cmp byte [train_col], 14
    jne chk_plus
    cmp byte [state], 0
    je chk_plus              ; state 0 = east, direction wahi rahe
    mov byte [train_dr], 1   ; south
    mov byte [train_dc], 0

chk_plus:                    ; --- + (10,14): hamesha east ---
    cmp byte [train_row], 10
    jne chk_s3
    cmp byte [train_col], 14
    jne chk_s3
    mov byte [train_dr], 0
    mov byte [train_dc], 1   ; east

chk_s3:                      ; --- Switch 3 (10,30): state 0 ho to north ---
    cmp byte [train_row], 10
    jne chk_s4
    cmp byte [train_col], 30
    jne chk_s4
    cmp byte [state+2], 0
    jne chk_s4               ; state 1 = east, direction wahi rahe
    mov byte [train_dr], 0FFh   ; -1 = north
    mov byte [train_dc], 0

chk_s4:                      ; --- Switch 4 (10,46): state 1 ho to south ---
    cmp byte [train_row], 10
    jne chk_stop
    cmp byte [train_col], 46
    jne chk_stop
    cmp byte [state+3], 1
    jne chk_stop             ; state 0 = east, direction wahi rahe
    mov byte [train_dr], 1   ; south
    mov byte [train_dc], 0



chk_stop:                    ; checking that any station location arrives or not
    xor si, si

stop_loop:
    mov al, [stop_tbl+si]
    cmp al, [train_row]
    jne stop_next
    mov al, [stop_tbl+si+1]
    cmp al, [train_col]
    jne stop_next
    mov byte [train_dr], 0
    mov byte [train_dc], 0

stop_next:
    add si, 2
    cmp si, 8
    jb stop_loop

                    
    xor ah, ah        ; 4) calculating new train cell location then printing train on that
    mov al, [train_row]
    xor bh, bh
    mov bl, [train_col]
    call calculate_di

    mov al, [es:di]
    mov [under_ch], al
    mov al, [es:di+1]
    mov [under_at], al
    mov byte [es:di], 'A'
    mov byte [es:di+1], 0Ch

    popa
    ret





delay:
    push cx
    push dx
    mov dx, 20               
d_outer:
    mov cx, 0FFFFh
d_inner:
    loop d_inner
    dec dx
    jnz d_outer
    pop dx
    pop cx
    ret
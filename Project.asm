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
msg_time: db 'TIME: '         ; 6 characters
msg_fast: db 'SPEED UP!'      ; 9 characters

; ----- menu / result / hint texts (length is written in mov cx, where printed) -----
m_title:  db 'S W I T C H Y A R D'
m_single: db '1 - SINGLE PLAYER'
m_coop:   db '2 - TWO PLAYER CO-OP'
m_exit:   db 'ESC - EXIT'
m_win:    db 'YOU WIN!'
m_lose:   db 'GAME OVER - YOU LOSE'
m_again:  db 'R - REPLAY     M - MAIN MENU     ESC - EXIT'
hint_single: db '1-4: SWITCHES     ESC: QUIT'
hint_coop:   db 'P1: KEYS 1,2     P2: KEYS J,K     ESC: QUIT'



correct_cnt: db 0             ; trains that reached correct station
wrong_cnt:   db 0             ; trains that reached a wrong station
seed:        dw 0             ; seed for the random number generator
next_entry:  db 0             ; which entry gets the next train (0 = Entry 1, 1 = Entry 2)
spawn_cnt:   db 1             ; ticks left before the next train comes

mode:        db 0             ; 0 = single player, 1 = co-op
playing:     db 0             ; 1 while the game is running (keys 1-4 / J / K work only then)
result:      db 0             ; 0 = game running, 1 = win, 2 = lose
last_key:    db 0             ; last key pressed (scancode), used by the menus
speed_done:  db 0             ; 1 after the one-time speed increase
speed_goal:  db 6             ; correct deliveries needed for speed increase (6 or 12)
win_goal:    db 10            ; correct deliveries needed to win (10 or 20)
move_interval: db 6           ; shared movement interval of all trains (in ticks, normal = 6)
move_cnt:    db 6             ; ticks left before the next movement update
last_tick:   dw 0             ; last BIOS timer tick we saw
tick_acc:    dw 0             ; helps to turn ticks into seconds (18.2 ticks = 1 sec)
seconds:     dw 0             ; elapsed time in seconds
score_row:   db 22            ; row where draw_score prints



; every stop is 3 bytes: row, col, station id (A=0, B=1, C=2, D=3)
stops:     db 3,64,3,   6,30,1,   10,64,2,   14,46,0,   19,64,3
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

; ----- copy of train positions taken at the start of every movement update -----
o_on:   db 0,0,0,0,0,0,0,0    ; was the train running at the start of the update
o_row:  db 0,0,0,0,0,0,0,0    ; its row at the start of the update
o_col:  db 0,0,0,0,0,0,0,0    ; its column at the start of the update

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

    in al,60h               ; Read scancode from KB, ESC-> 01h, 1->02h, 2->03h, 3->04h, 4->05h
    test al,80h             ; checking bit 7, key released? do nothing
    jnz kb_done

    mov [cs:last_key], al   ; remember the key for the menus

    cmp al, 01h              ; ESC?
    jne kb_check
    mov byte [cs:quit], 1
    jmp kb_done

 kb_check:
    cmp byte [cs:playing], 0 ; switches work only while the game is running
    je kb_done
    cmp al, 02h              ; key < 1 ? ignore
    jb kb_done
    cmp al, 05h              ; key  > 4 ? go and check J and K
    ja kb_jk
    cmp byte [cs:mode], 0    ; single player: keys 1-4 all work
    je kb_toggle
    cmp al, 03h              ; co-op: player 1 has only keys 1 and 2
    ja kb_done
    jmp kb_toggle

 kb_jk:
    cmp byte [cs:mode], 1    ; J and K work only in co-op
    jne kb_done
    cmp al, 24h              ; J ? (switch 3)
    je kb_j
    cmp al, 25h              ; K ? (switch 4)
    jne kb_done
    mov al, 05h              ; K acts like key 4
    jmp kb_toggle
 kb_j:
    mov al, 04h              ; J acts like key 3

 kb_toggle:
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


    xor ah, ah               ; get BIOS timer ticks (comes in DX)
    int 1Ah
    mov [seed], dx           ; use it as random seed
    mov [last_tick], dx      ; also the start point of the tick counter



menu:
    call show_menu           ; main menu: choose single player or co-op
    cmp byte [quit], 0       ; ESC in menu?
    jne exit_game

new_game:
    call init_game           ; reset trains, switches, counters and timer
    call draw_board          ; draw track, switches and names
    mov byte [playing], 1    ; keys for switches work now


main_loop:

    call erase_trains        ; 1) put track back under every train
    call draw_switches       ; 2) update gate colors (green = open, red = closed)
    call update_clock        ; 3) count the elapsed time
    call move_if_due         ; 4) move every train one step (only when the interval is over)
    call spawn_train         ; 5) send a new train if it is time
    call draw_trains         ; 6) draw every train
    call draw_score          ; 7) show correct / wrong count and time
    call check_end           ; 8) check win or lose
    call wait_tick           ; 9) wait for next timer tick
    cmp byte [quit], 0       ; ESC pressed?
    jne exit_game
    cmp byte [result], 0     ; game finished?
    je main_loop

    ; game is finished (win or lose)
    mov byte [playing], 0
    call show_result         ; shows result, returns AL = key (R or M)
    cmp byte [quit], 0
    jne exit_game
    cmp al, 13h              ; R = replay with same mode
    jne go_menu
    jmp new_game
go_menu:
    jmp menu


exit_game:
    ;when ESC key is pressed
    push ds                  ; retreive old keyboard handler 
    lds dx, [old9]
    mov ax, 2509h
    int 21h
    pop ds

    mov ax, 0003h            ; clear screen before going back to DOS
    int 10h

    mov ax, 4C00h            ; exit
    int 21h






calculate_di:     ; calculates di offset

    mov dx, 80
    mul dx
    add ax, bx
    add ax, ax
    mov di, ax
    ret



clear_screen:                ; clear screen and point ES to video memory
    mov ax, 0x0003
    int 10h
    mov ax, 0xb800
    mov es, ax
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




draw_board:                  ; draws the fixed track, switches, entries and stations

    call clear_screen

    mov byte [score_row], 22   ; score is shown at the bottom during the game

    mov ax, 3     ; horizontal line printing (all end at column 64)
    mov bx, 8
    mov cx, 57
    call hline

    mov ax, 19
    mov bx, 8
    mov cx, 57
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



    mov byte [str_attr], 09h   ; blue
    mov ax, 3                  ; print station D (top right)
    mov bx, 65
    mov si, SD
    mov cx, [S_Len]
    call print_str

    mov byte [str_attr], 0Dh   ; majenta
    mov ax, 5                  ; print station B
    mov bx, 30
    mov si, SB
    mov cx, [S_Len]
    call print_str

    mov byte [str_attr], 0Ah   ; green
    mov ax, 10                 ; print station C (middle right)
    mov bx, 65
    mov si, SC
    mov cx, [S_Len]
    call print_str

    mov byte [str_attr], 0Ch   ; red
    mov ax, 15                 ; print station A (below switch 4 line)
    mov bx, 46
    mov si, SA
    mov cx, [S_Len]
    call print_str

    mov byte [str_attr], 09h   ; blue
    mov ax, 19                 ; print station D (bottom right)
    mov bx, 65
    mov si, SD
    mov cx, [S_Len]
    call print_str


    mov byte [str_attr], 0Eh   ; game heading on top (yellow)
    mov ax, 0
    mov bx, 30
    mov si, m_title
    mov cx, 19
    call print_str


    mov byte [str_attr], 07h   ; key help on the last row (depends on mode)
    mov ax, 23
    mov bx, 0
    mov si, hint_single
    mov cx, 27
    cmp byte [mode], 0
    je hint_go
    mov si, hint_coop
    mov cx, 43
hint_go:
    call print_str

    ret




init_game:                   ; reset everything for a new game
    mov byte [correct_cnt], 0
    mov byte [wrong_cnt], 0
    mov byte [next_entry], 0
    mov byte [spawn_cnt], 1
    mov byte [speed_done], 0
    mov byte [result], 0
    mov byte [move_interval], 6   ; normal interval = 6 ticks
    mov byte [move_cnt], 6
    mov word [seconds], 0
    mov word [tick_acc], 0

    xor si, si               ; all 4 switches back to straight
    mov cx, 4
ig_sw:
    mov byte [state + si], 0
    inc si
    loop ig_sw

    xor si, si               ; all 8 train slots become free
    mov cx, 8
ig_tr:
    mov byte [t_on + si], 0
    inc si
    loop ig_tr

    mov byte [speed_goal], 6     ; single player goals
    mov byte [win_goal], 10
    cmp byte [mode], 0
    je ig_done
    mov byte [speed_goal], 12    ; co-op goals
    mov byte [win_goal], 20
ig_done:
    ret




show_menu:                   ; main menu, waits for key 1, 2 or ESC
    call clear_screen

    mov byte [str_attr], 0Eh     ; yellow title
    mov ax, 6
    mov bx, 30
    mov si, m_title
    mov cx, 19
    call print_str

    mov byte [str_attr], 0Fh     ; white options
    mov ax, 10
    mov bx, 30
    mov si, m_single
    mov cx, 17
    call print_str

    mov ax, 12
    mov bx, 30
    mov si, m_coop
    mov cx, 20
    call print_str

    mov ax, 14
    mov bx, 30
    mov si, m_exit
    mov cx, 10
    call print_str

    mov byte [last_key], 0
sm_wait:
    cmp byte [quit], 0       ; ESC pressed?
    jne sm_done
    mov al, [last_key]
    cmp al, 02h              ; key 1 = single player
    je sm_single
    cmp al, 03h              ; key 2 = co-op
    jne sm_wait
    mov byte [mode], 1
    jmp sm_done
sm_single:
    mov byte [mode], 0
sm_done:
    ret




show_result:                 ; shows win / lose screen, waits for R, M or ESC (out: AL = key)
    call clear_screen

    mov byte [str_attr], 0Ah     ; green for win
    mov si, m_win
    mov cx, 8
    cmp byte [result], 1
    je sr_print
    mov byte [str_attr], 0Ch     ; red for lose
    mov si, m_lose
    mov cx, 20
sr_print:
    mov ax, 8
    mov bx, 30
    call print_str

    mov byte [score_row], 11     ; show final score and time in the middle
    call draw_score

    mov byte [str_attr], 0Fh
    mov ax, 15
    mov bx, 18
    mov si, m_again
    mov cx, 43
    call print_str

    mov byte [last_key], 0
sr_wait:
    cmp byte [quit], 0       ; ESC pressed?
    jne sr_done
    mov al, [last_key]
    cmp al, 13h              ; R = replay
    je sr_done
    cmp al, 32h              ; M = main menu
    jne sr_wait
sr_done:
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




print_num2:                  ; in: AX = row, BX = col, CL = number (0-99), prints 2 digits
    call calculate_di

    mov al, cl
    xor ah, ah
    mov cl, 10
    div cl                   ; AL = tens, AH = ones
    add al, '0'
    mov [es:di], al
    mov byte [es:di+1], 0Fh

    add ah, '0'
    mov [es:di+2], ah
    mov byte [es:di+3], 0Fh
    ret




draw_score:                  ; show "CORRECT: 000   WRONG: 000   TIME: 00:00" on row score_row
    pusha

    mov byte [str_attr], 0Ah ; green
    xor ah, ah
    mov al, [score_row]
    mov bx, 0
    mov si, msg_ok
    mov cx, 9
    call print_str

    xor ah, ah
    mov al, [score_row]
    mov bx, 9
    mov cl, [correct_cnt]
    call print_num

    mov byte [str_attr], 0Ch ; red
    xor ah, ah
    mov al, [score_row]
    mov bx, 20
    mov si, msg_bad
    mov cx, 7
    call print_str

    xor ah, ah
    mov al, [score_row]
    mov bx, 27
    mov cl, [wrong_cnt]
    call print_num

    mov byte [str_attr], 0Fh ; white, elapsed time
    xor ah, ah
    mov al, [score_row]
    mov bx, 40
    mov si, msg_time
    mov cx, 6
    call print_str

    mov ax, [seconds]
    xor dx, dx
    mov bx, 60
    div bx                   ; AX = minutes, DX = seconds
    push dx                  ; keep the seconds
    mov cl, al               ; minutes
    xor ah, ah
    mov al, [score_row]
    mov bx, 46
    call print_num2

    xor ah, ah               ; print ':' between minutes and seconds
    mov al, [score_row]
    mov bx, 48
    call calculate_di
    mov byte [es:di], ':'
    mov byte [es:di+1], 0Fh

    pop cx                   ; seconds
    xor ah, ah
    mov al, [score_row]
    mov bx, 49
    call print_num2

    cmp byte [speed_done], 0 ; show message after the speed increase
    je ds_end
    mov byte [str_attr], 0Eh
    xor ah, ah
    mov al, [score_row]
    mov bx, 60
    mov si, msg_fast
    mov cx, 9
    call print_str
ds_end:
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




update_clock:                ; counts elapsed seconds from timer ticks (18.2 ticks = 1 second)
    add word [tick_acc], 10
    cmp word [tick_acc], 182
    jb uc_done
    sub word [tick_acc], 182
    inc word [seconds]
uc_done:
    ret




move_if_due:                 ; call move_trains only when the shared movement interval is over
    dec byte [move_cnt]
    jnz md_done              ; not time yet
    mov al, [move_interval]
    mov [move_cnt], al       ; start counting the next interval
    call move_trains
md_done:
    ret




move_trains:                 ; move every running train one step (if the next cell is free)
    pusha

    xor si, si               ; take a copy of all train positions (state at start of update)
snap_loop:
    mov al, [t_on + si]
    mov [o_on + si], al
    mov al, [t_row + si]
    mov [o_row + si], al
    mov al, [t_col + si]
    mov [o_col + si], al
    inc si
    cmp si, 8
    jb snap_loop

    xor si, si               ; start from train 0
mv_loop:
    cmp byte [t_on + si], 0
    je mv_next               ; slot is free, skip

    call check_switches      ; turn if train is standing on a switch
    call cell_free           ; is the next cell free?
    jc mv_next               ; no, the train waits for the next update (no penalty)

    mov al, [t_dr + si]      ; one step in current direction
    add [t_row + si], al
    mov al, [t_dc + si]
    add [t_col + si], al

    call check_station       ; remove train if it reached a station
mv_next:
    inc si
    cmp si, 8
    jb mv_loop
    popa
    ret




cell_free:                   ; in: SI = train number   out: CF = 1 if next cell is NOT free
    mov dl, [t_row + si]     ; DL, DH = cell where this train wants to go
    add dl, [t_dr + si]
    mov dh, [t_col + si]
    add dh, [t_dc + si]

    xor bx, bx               ; check all 8 trains
cf_loop:
    cmp byte [o_on + bx], 0  ; was a train in that cell at the start of the update?
    je cf_claim
    cmp dl, [o_row + bx]
    jne cf_claim
    cmp dh, [o_col + bx]
    je cf_busy

cf_claim:                    ; did a train already move into that cell in this update?
    cmp byte [t_on + bx], 0
    je cf_next
    cmp dl, [t_row + bx]
    jne cf_next
    cmp dh, [t_col + bx]
    je cf_busy

cf_next:
    inc bx
    cmp bx, 8
    jb cf_loop
    clc                      ; cell is free
    ret
cf_busy:
    stc                      ; cell is taken, train must wait
    ret




check_switches:              ; in: SI = train number (sets direction if train is on a switch)

    ; --- Switch 1 (3,14): state 0 east, state 1 south ---
    cmp byte [t_row + si], 3
    jne cw_s2
    cmp byte [t_col + si], 14
    jne cw_s2
    mov byte [t_dr + si], 0  ; east
    mov byte [t_dc + si], 1
    cmp byte [state], 0
    je cw_s2
    mov byte [t_dr + si], 1  ; state 1 = south
    mov byte [t_dc + si], 0

cw_s2:                       ; --- Switch 2 (19,14): state 0 east, state 1 north ---
    cmp byte [t_row + si], 19
    jne cw_plus
    cmp byte [t_col + si], 14
    jne cw_plus
    mov byte [t_dr + si], 0  ; east
    mov byte [t_dc + si], 1
    cmp byte [state + 1], 1
    jne cw_plus
    mov byte [t_dr + si], 0FFh   ; state 1 = north (-1)
    mov byte [t_dc + si], 0

cw_plus:                     ; --- + (10,14): always east ---
    cmp byte [t_row + si], 10
    jne cw_s3
    cmp byte [t_col + si], 14
    jne cw_s3
    mov byte [t_dr + si], 0
    mov byte [t_dc + si], 1  ; east

cw_s3:                       ; --- Switch 3 (10,30): state 0 north, state 1 east ---
    cmp byte [t_row + si], 10
    jne cw_s4
    cmp byte [t_col + si], 30
    jne cw_s4
    mov byte [t_dr + si], 0  ; east
    mov byte [t_dc + si], 1
    cmp byte [state + 2], 0
    jne cw_s4
    mov byte [t_dr + si], 0FFh   ; state 0 = north (-1)
    mov byte [t_dc + si], 0

cw_s4:                       ; --- Switch 4 (10,46): state 0 east, state 1 south ---
    cmp byte [t_row + si], 10
    jne cw_end
    cmp byte [t_col + si], 46
    jne cw_end
    mov byte [t_dr + si], 0  ; east
    mov byte [t_dc + si], 1
    cmp byte [state + 3], 1
    jne cw_end
    mov byte [t_dr + si], 1  ; state 1 = south
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
    call check_speed         ; maybe time for the speed increase
    ret
cst_wrong:
    inc byte [wrong_cnt]     ; wrong station
    ret

cst_next:
    add bx, 3                ; next stop (3 bytes each)
    cmp bx, 15               ; 5 stops x 3 bytes
    jb cst_loop
    ret




check_speed:                 ; one-time speed increase when the score reaches the goal
    cmp byte [speed_done], 0
    jne csp_done             ; already done
    mov al, [correct_cnt]
    cmp al, [speed_goal]
    jb csp_done              ; goal not reached yet

    mov byte [speed_done], 1
    shr byte [move_interval], 1  ; halve the interval (integer division)
    jnz csp_clamp
    mov byte [move_interval], 1  ; minimum is 1 tick
csp_clamp:
    mov al, [move_interval]  ; the running countdown must not be longer than new interval
    cmp [move_cnt], al
    jbe csp_done
    mov [move_cnt], al
csp_done:
    ret




check_end:                   ; sets result: 1 = win, 2 = lose
    mov al, [correct_cnt]
    cmp al, [win_goal]
    jb ce_lose
    mov byte [result], 1     ; enough correct deliveries
    ret
ce_lose:
    cmp byte [wrong_cnt], 5
    jb ce_done
    mov byte [result], 2     ; 5 mistakes
ce_done:
    ret




entry_busy:                  ; in: AL = entrance row   out: CF = 1 if a train stands on that entrance
    push bx
    xor bx, bx
eb_loop:
    cmp byte [t_on + bx], 0
    je eb_next
    cmp al, [t_row + bx]
    jne eb_next
    cmp byte [t_col + bx], 8 ; entrance cell is column 8
    je eb_busy
eb_next:
    inc bx
    cmp bx, 8
    jb eb_loop
    pop bx
    clc                      ; entrance is empty
    ret
eb_busy:
    pop bx
    stc
    ret




spawn_train:                 ; send a new train when the countdown ends
    pusha
    dec byte [spawn_cnt]
    jnz sp_done              ; not time yet

    mov al, 3                ; row of the entrance which is next
    cmp byte [next_entry], 0
    je sp_check
    mov al, 19
sp_check:
    call entry_busy          ; spawn only on an empty entrance
    jc sp_retry

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
    mov cl, 4
    call rand                ; random destination A, B, C or D (0-3), all are reachable now
    mov [t_dest + si], al
    mov byte [next_entry], 0 ; next train comes from Entry 1

sp_reset:
    mov cl, 20
    call rand                ; random 0-19
    add al, 36               ; 36-55 ticks = about 2 to 3 seconds
    mov [spawn_cnt], al
    jmp sp_done
sp_retry:
    mov byte [spawn_cnt], 1  ; entrance busy, check again on next tick
sp_done:
    popa
    ret




wait_tick:                   ; wait until the BIOS timer tick changes (one tick = about 55 ms)
    push ax
    push cx
    push dx
wt_loop:
    xor ah, ah
    int 1Ah                  ; DX = current tick
    cmp dx, [last_tick]
    je wt_loop               ; same tick, keep waiting
    mov [last_tick], dx
    pop dx
    pop cx
    pop ax
    ret
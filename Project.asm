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



start:

    mov ax, 0003h  ; clear screen       
    int 10h

    mov ax, 0B800h       
    mov es, ax



    mov ax, 3     ; horizoontal line printing
    mov bx, 8
    mov cx, 50
    call hline

    mov ax, 19
    mov bx, 8
    mov cx, 50
    call hline

    mov ax, 10
    mov bx, 14
    mov cx, 50
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



    

    mov ax, 3            ; print Entry1     
    mov bx, 0
    mov si, E1
    mov cx, [E_Len]
    call print_str

    mov ax, 19            ; print Entry2
    mov bx, 0
    mov si, E2
    mov cx, [E_Len]
    call print_str

    mov ax, 3              ;print station A string
    mov bx, 59
    mov si, SA
    mov cx, [S_Len]
    call print_str

    mov ax, 5              ; print station B 
    mov bx, 30
    mov si, SB
    mov cx, [S_Len]
    call print_str

    mov ax, 10             ; print station C
    mov bx, 65
    mov si, SC
    mov cx, [S_Len]
    call print_str

    mov ax, 15             ; print station D 
    mov bx, 46
    mov si, SD
    mov cx, [S_Len]
    call print_str

    mov ax, 19             ; print station D 
    mov bx, 59
    mov si, SD
    mov cx, [S_Len]
    call print_str



   
    mov ah, 0
    int 16h

   
    mov ax, 4C00h  ; exit
    int 21h



calculate_di:     ; calculates di offfset

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
     mov byte [es:di+1], 0Fh    
     inc si                 
     add di, 2 
           

    loop strloop
    ret



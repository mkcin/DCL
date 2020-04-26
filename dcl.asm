SYS_READ  equ 0
SYS_WRITE equ 1
SYS_EXIT  equ 60
STDIN     equ 0
STDOUT    equ 1
BUFFER_SIZE equ 4096
ONE       equ 49

; Wykonanie programu zaczyna się od etykiety _start.
global _start

section .bss
; miejsce zarezerwowane na wczytany tekst 
buffer resb BUFFER_SIZE
; tablica zliczająca powtórzenia znaków w argumentach
letter_ocurencies times 42 resb 0
; inwersja permutacji R
R_inversed times 42 resb 1
; inwersja permutacji L
L_inversed times 42 resb 1

section .text

; Wypisywanie bufora
; print_buffer b, c wypisuje c znaków tekstu o początku w b
; Modyfikuje rejestry rax, rdi, rsi, rdx i r11 przez funkcję systemową
%macro print_buffer 2
        mov     rdx, %2
        mov     rsi, %1
        mov     rax, SYS_WRITE
        mov     rdi, STDOUT
        syscall 
%endmacro

; Wczytywanie do bufora
; Po wykonaniu read, buffer to początek wczytanego 
; bloku tekstu o maksymalnej wielkości BUFFER_SIZE
; Modyfikuje rejestry rax, rdi, rsi, rdx i r11 przez funkcję systemową
%macro read 0
        mov     rax, SYS_READ
        mov     rdi, STDIN
        mov     rsi, buffer
        mov     rdx, BUFFER_SIZE
        syscall
%endmacro

; Permutacja Q 
; Q_permutation x, y wykonuje Q o indeksie %2 na literze %1
%macro Q_permutation 2
        add     %1, %2
        mov     edx, %1
        sub     edx, 42
        cmp     %1, 42
        cmovge  %1, edx
%endmacro

; Odwrotność permutacji Q
; r_Q_permutation x, y wykonuje odwrotność 
; Q o indekie %2 na literze %1
; Modyfikuje rejestr rdx
%macro r_Q_permutation 2
        sub     %1, %2
        mov     edx, %1
        add     edx, 42
        test    %1, %1
        cmovs   %1, edx
%endmacro

; Permutacja R, Odwrotności R, L, odwrotności L, 
; lub T (która jest taka sama jak swoja odwrotność)
; L_R_T_permutation x P x_r wykonuje na x (czyli %1 i %3 
; tylko %1 to ostatnie 8 bitów, a %3 to 64 bity) permutację  
; R jeśli %2 to adres permutacji R
; L jeśli %2 to adres permutacji L
; T jeśli %2 to adres permutacji T
; lub odwrotność
; R jeśli %2 to adres odwrotności permutacji R
; L jeśli %2 to adres odwrotności permutacji L 
%macro L_R_T_permutation 3
        mov     %1, [%2 + %3]
%endmacro


_start:
        call    arguments_validation
        mov     r9, [rsp + 5 * 8]
        xor     r14, r14 
        xor     r13, r13 
        mov     r14b, [r9 + 1]         ; pozycja początkowa bębenka R
        mov     r13b, [r9]             ; pozycja początkowa bębenka L
        sub     r13b, ONE 
        sub     r14b, ONE
        mov     r9, [rsp + 2 * 8]       ; permutacja L
        mov     r10, [rsp + 3 * 8]      ; permutacja R
        mov     r12, [rsp + 4 * 8]      ; permutacja T
        call    inverse_and_decrement_permutations

        xor     r15, r15
read_and_print_loop:
        read
        cmp     rax, 0
        je      read_and_print_loop_end
        mov     rdi, buffer     ; Zapisuję wskaźnik na początek bufora
        xor     rsi, rsi        ; Liczba przepermutowanych znaków bufora  
apply_permutations_loop_increment:
        xor     r15, r15
        mov     r15b, r13b
        inc     r15b
        inc     r14b            ; Obracam bębenek R
        cmp     r14b, 27        ; Sprawdzam czy r nie jest w którejś z pozycji obrotowych 
        cmove   r13, r15
        cmp     r14b, 33
        cmove   r13, r15
        cmp     r14b, 35
        cmove   r13, r15
        xor     r15, r15
        cmp     r14b, 42        ; Kontroluję cykliczny obrót bębenka R
        cmove   r14, r15        ; i jeśli się przekręca, zamieniam wartość z powrotem na 0
        cmp     r13b, 42        ; Kontroluję cykliczny obrót bębenka L
        cmove   r13, r15        ; i jeśli się przekręca, zamieniam wartość z powrotem na 0

        mov     r15b, [rdi]

        sub     r15b, ONE
        cmp     r15b, 0          ; Sprawdzam czy wczytany znak jest z dobrego zakresu
        jl      exit_1
        cmp     r15b, 41
        jg      exit_1
                                                ; Wykonuję permutacje na kolejnej literze
        Q_permutation r15d, r14d                 ; Qr
        L_R_T_permutation r15b, r10, r15         ; R
        r_Q_permutation r15d, r14d               ; odwrotność Qr
        Q_permutation r15d, r13d                 ; Ql
        L_R_T_permutation r15b, r9, r15          ; L
        r_Q_permutation r15d, r13d               ; odwrotność Ql
        L_R_T_permutation r15b, r12, r15         ; T
        Q_permutation r15d, r13d                 ; Ql
        L_R_T_permutation r15b, L_inversed, r15  ; odwrotność L
        r_Q_permutation r15d, r13d               ; odwrotność Ql
        Q_permutation r15d, r14d                 ; Qr
        L_R_T_permutation r15b, R_inversed, r15  ; odwrotność R
        r_Q_permutation r15d, r14d               ; odwrotność Qr

        add     r15b, ONE
        mov     byte [rdi], r15b
        inc     rdi
        inc     rsi
        cmp     rax, rsi                                ; Sprawdzam, czy rozpatrzony znak był 
                                                        ; ostatnim wczytanym do bufora znakiem
        jne     apply_permutations_loop_increment       ; Jeśli nie był, rozpatruję kolejny znak
        
        print_buffer buffer, rax                        ; Wypisuję zaszyfrowany bufor
        cmp     rax, BUFFER_SIZE                        ; Sprawdzam 
        je      read_and_print_loop
read_and_print_loop_end:

        mov     eax, SYS_EXIT
        mov     rdi, 0        ; kod powrotu 0
        syscall

;       SEKCJE POMOCNICZE
        
; Wypełnia R_inversed oraz L_inversed odpowiednio inwersjami 
; Permutacji R oraz L i zmniejsza wartości znaków tych
; permutacji oraz oraz permutacji T o 49
; r9 - początek permutacji L (modyfikowane przez funkcję)
; r10 - początek permutacji R (modyfikowane przez funkcję)
; r12 - początek permutacji T (modyfikowane przez funkcję)
; Modyfikuje rejestry rdi, rsi, rdx
inverse_and_decrement_permutations:
        push    r9
        push    r10
        push    r12
        xor     rdi, rdi        ; Rejestr na kolejne elementy permutacji
        xor     rsi, rsi        ; Indeks aktualnie rozpatrywanego elementu
        xor     rdx, rdx        ; Rejestr służący do przesunięcia elementów
                                ; Permutacji T o 49
inverse_L_permutation_loop:
        mov     dil, [r9]
        cmp     dil, 0          ; Koniec permutacji L
        je      inverse_L_permutation_end

        mov     dl, [r12]       ; Zmniejszenie kolejnego znaku w permutacji T o 49
        sub     dl, ONE
        mov     byte [r12], dl

        sub     dil, ONE
        mov     byte [r9], dil  ; Przesunięcie elementu L o 49 do tyłu w ASCII
        mov     byte [L_inversed + rdi], sil ; Wypełnienie inwersjii L
        inc     r9
        inc     r12
        inc     rsi
        jmp     inverse_L_permutation_loop
inverse_L_permutation_end:
        xor     rdi, rdi        ; rejestr na kolejne elementy permutacji
        xor     rsi, rsi        ; indeks aktualnie rozpatrywanego elementu
inverse_R_permutation_loop:
        mov     dil, [r10]
        cmp     dil, 0          ; Koniec permutacji R
        je      inverse_R_permutation_end
        sub     dil, ONE
        mov     byte [r10], dil ; Przesunięcie elementu R o 49 do tyłu w ASCII
        mov     byte [R_inversed + rdi], sil ; Wypełnienie inwersjii R
        inc     r10
        inc     rsi
        jmp     inverse_R_permutation_loop
inverse_R_permutation_end:
        pop     r12
        pop     r10
        pop     r9
        ret

; Sprawdzam, czy liczba argumentów jet poprawna oraz czy poszczególne argumenty są poprawne
; Modyfikuje rejestry rax, rcx, rsi, rdx
arguments_validation:
        mov     rax, 5                  ; program ma przyjąć 4 argumenty (args[0] to nazwa programu)
        cmp     rax, [rsp + 8]
        jne     exit_1
        mov     rcx, 42
        mov     rsi, 1
        mov     rdx, [rsp + 3 * 8]
        call    check_valid_argument    ; Poprawność permutacji L
        mov     rdx, [rsp + 4 * 8]
        call    check_valid_argument    ; Poprawność permutacji R
        mov     rdx, [rsp + 5 * 8]
        call    check_valid_argument
        mov     rdx, [rsp + 5 * 8]      ; Poprawność permutacji T
        call    check_valid_T_permutation
        mov     rcx, 2
        xor     rsi, rsi
        mov     rdx, [rsp + 6 * 8]
        call    check_valid_argument    ; Poprawność klucza szyfrowania
        ret

; Sprawdzam poprawność wczytanych argumentów pod kątem długości, poprawności znaków
; dodatkowo opcjonalnie sprawdzam, czy wszystkie znaki argumentu się różnią
; rcx - oczekiwaną długość argumentu
; rdx - adres argumentu do sprawdzenia
; rsi - 0 jeśli nie chcę, żeby została sprawdzona znaków w argumencie
;       1 w przeciwnym wypadku
; Modyfikuje rejestry rbx, rbp, rax, r8, rdx 
check_valid_argument:
        xor     rbx, rbx        ; długość argumentu        
        mov     rbp, rdx        ; zapisuję wskaźnik na początek argumentu
check_valid_argument_characters_loop:
        mov     al, [rdx]
        cmp     al, 0           ; sprawdzam, czy napotkałem koniec argumentu
        je      check_valid_argument_length

        cmp     al, ONE          ; sprawdzam, czy znak jest w dozwolonym przedziale
        jl      exit_1
        cmp     al, 90
        jg      exit_1

        inc     rbx             ; zwiększam licznik długości
        inc     rdx
        jmp     check_valid_argument_characters_loop
check_valid_argument_length:
        cmp     rbx, rcx        ; sprawdzam, czy argument jest oczekiwanej długości
        jne     exit_1

        cmp     rsi, 0          ; jeśli nie chcę sprawdzać czy litery są różne, pomijam ten etap
        je      check_valid_argument_end
check_valid_argument_distinct:
        mov     r8, 0           
check_valid_argument_distinct_clear_array:
        mov     byte [letter_ocurencies + r8], 0 ; zeruję tablicę zliczającą powtórzenia liter
        inc     r8
        cmp     r8, 42
        jne     check_valid_argument_distinct_clear_array

        xor     rax, rax        ; w rejestrze al będę zapisywał kolejne litery
check_valid_argument_distinct_loop:
        mov     al, [rbp]
        sub     al, ONE          ; al należy do [0, 49]
        mov     rdx, letter_ocurencies
        add     rdx, rax
        cmp     byte [rdx], 0   ; sprawdzam, czy litera nie wystąpiła do tej pory
        jne     exit_1
        mov     byte [rdx], 1   ; zaznaczam wystąpienie litery
        inc     rbp             ; przesuwam wskaźnik po argumencie
        mov     al, [rbp]       
        cmp     al, 0           ; sprawdzam, czy nie napotkałem końca argumentu
        jne     check_valid_argument_distinct_loop
check_valid_argument_end:
        ret

; Sprawdzam, czy permutacja T składa się z 21 rozłącznych cykli 2-elementowych
; rdx - adres argumentu T
; modyfukuje rejestry rax, rdi, rcx, r8
check_valid_T_permutation:
        xor     rax, rax        ; zeruję rejestry, na których części będę trzymał znaki z permutacji
        xor     rcx, rcx
        xor     r8, r8
        mov     rdi, rdx        ; zapisuję początek argumentu
check_valid_T_permutation_loop:
        mov     al, [rdx]
        cmp     al, 0           ; sprawdzam, czy nie napotkałem końca argumentu
        je      check_valid_T_permutation_end
        sub     al, ONE
        add     rdi, rax
        mov     cl, [rdi]       ; zapisuję, na jaką literę w permutacji przechodzi litera argumentu
        sub     rdi, rax
        sub     cl, ONE
        cmp     al, cl
        je      exit_1          ; wykryto cykl jednoelementowy
        add     rdi, rcx
        mov     r8b, [rdi]      ; zapisuję na jaką literę w permutacji przechodzi litera,
                                ; na którą przechodzi litera argumentu
        sub     rdi, rcx
        sub     r8b, ONE
        cmp     al, r8b
        jne     exit_1          ; cykl nie jest dwuelementowy
        inc     rdx
        jmp     check_valid_T_permutation_loop
check_valid_T_permutation_end:
        ret
        
exit_1:
        mov     eax, SYS_EXIT
        mov     rdi, 1        ; kod powrotu 1
        syscall

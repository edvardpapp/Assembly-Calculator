DEF UC   0x88                ; USRT kontroll regiszter (csak írható)
DEF US   0x89                ; USRT FIFO státusz regiszter (csak olvasható)
DEF UIE  0x8A                ; USRT megszakítás eng. reg. (írható/olvasható)
DEF UD   0x8B                ; USRT adatregiszter (írható/olvasható)
DEF DIG0 0x90
DEF DIG1 0x91
DEF DIG2 0x92
DEF DIG3 0x93

DEF RXNE 0b00000100

DEF BASE_STATE  0
DEF OPA         1
DEF OPB         2
DEF OPERATION   3
DEF Equal       4

DEF ADD_A_B 0x2b
DEF SUB_A_B 0x2d
DEF MUL_A_B 0x2a
DEF DIV_A_B 0x2f
DEF ESC     0x1B

DEF MASK_DIG3_2_1_0 0b11110000
DEF MASK_DIG2_1_0   0b01110000
DEF MASK_DIG1_0     0b00110000

DEF NEW_DATA        0x01
DEF DATA_PROCESSED  0x00

DEF MASK_OP 0x0F

DATA ; adatszegmens kijelölése
; A hétszegmenses dekóder szegmensképei (0-9, A-F) az adatmemóriában.
sgtbl: DB 0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f, 0x77, 0x7c, 0x39, 0x5e, 0x79, 0x71




;r7 dig3|dig2  r6 dig1|dig0 r8 blank|dp
CODE
reset: jmp main

;a két digit kezelhetõ egységesen, hisz mindkettõre E-t kell kiírni illetve tiltani kell
ISR:
    MOV r15, UD     ;jött adat beolvasása
    MOV r5, #NEW_DATA   ;jelezzük, hogy jött adat 
    MOV r14, r12    ;elmentjük az elõzõ state-t
    CMP r15, #ESC   ;ha ESC jött, akkor a STATE alapállapot, 0 és visszatérünk
    JNZ JUMP_STATE
    MOV r12, #BASE_STATE
    JMP RTI_ISR     
    ;state reg: r12
JUMP_STATE:
    CMP r12, #OPA   ;elõzõleg OPA volt-e a STATE
    JZ OP_A     
    CMP r12, #OPB   ;elõzõleg OPB volt-e a STATE
    JZ OP_B
    CMP r12, #OPERATION ;elõzõleg OPERATION volt-e a STATE
    JZ STATE_OPERATION
    CMP r12, #Equal     ;elõzõleg Equal volt-e a STATE
    JZ EQUAL
START:
    ;ide akkor jutunk, ha alapállapotban vagyunk
    MOV r6, r15     ;megnézzük, hogy a jött adat decimális szám-e
    JSR check_operand_validity
    JZ RTI_ISR
    MOV r12, #OPA   ;ha decimális szám, a STATE OPA lesz
    JMP RTI_ISR
OP_A:
    ;ide akkor jutunk, ha az elõzõ adat az A bemeneti operandus volt
    ;ha nem mûvelet jött, nem csinálunk semmit
    CMP r15, #ADD_A_B   ;a jött adat '+'?
    JZ SET_OPERATION
    CMP r15, #SUB_A_B   ;a jött adat '-'?
    JZ SET_OPERATION
    CMP r15, #MUL_A_B   ;a jött adat '*'?
    JZ SET_OPERATION
    CMP r15, #DIV_A_B   ;a jött adat '/'?
    JZ SET_OPERATION
    JMP RTI_ISR
SET_OPERATION:
    ;ide akkor jutunk, ha az elõzõ adat az A operandus volt és most mûvelet jött
    MOV r12, #OPERATION
    JMP RTI_ISR
STATE_OPERATION:
    ;ide akkor jutunk, ha az elõzõ adat mûvelet volt
    MOV r6, r15     ;ellenõrizzük, hogy decimális szám jött-e
    JSR check_operand_validity
    JZ CHECK_PREV_STATE ;ha nem szám jött, megnézzük változott-e az elõzõ állapothoz képest a STATE
    MOV r12, #OPB
    JMP RTI_ISR
OP_B:
    ;ide akkor jutunk, ha az elõzõ adat a B operandus volt
    CMP r15, #0x3d  ;a jött adat '='?
    JZ SET_EQUAL
    CMP r15, #0x0d  ;a jött adat '\r', azaz enter?
    JZ SET_EQUAL
    JMP RTI_ISR
SET_EQUAL:
    ;ide akkor jutunk, ha az elõzõ adat a B operandus volt és a jelenlegi adat '=' vagy enter
    MOV r12, #Equal
    JMP CHECK_PREV_STATE ;ha nem '=' vagy enter jött, megnézzük változott-e az elõzõ állapothoz képest a STATE
EQUAL:
;ide akkor jutunk, ha az elõzõ adat '=' vagy enter volt
    MOV r6, r15     ;ellenõrizzük, hogy decimális szám jött-e
    JSR check_operand_validity
    JZ CHECK_PREV_STATE  ;ha nem szám jött, megnézzük változott-e az elõzõ állapothoz képest a STATE
    MOV r12, #OPA
CHECK_PREV_STATE:
    ;ha nem változott az elõzõhöz képest a STATE, akkor nem tekintünk rá érvényes adatként
    CMP r12, r14
    JNZ RTI_ISR
    MOV r5, #DATA_PROCESSED
RTI_ISR:
    RTI



main:
    ;inicializálások
    MOV r5, #NEW_DATA   ;alapesetben nem jött még új adat
    MOV r12, #BASE_STATE;alap STATE az 0
    MOV r0, #0x0f       ;adás és vételi FIFO törlése, adás és vétel engedélyezése
    MOV UC, r0
    MOV r0, #RXNE       ;intgerrupt engedélyezáse
    MOV UIE, r0
    STI                 ;globális IT engedélyezés
loop:
    CMP r5, #NEW_DATA   ;van új adat?
    JC loop
    CMP r15, #ESC   ;ESC az új adat?
    JNZ Check_OPA
    MOV r8, #MASK_DIG3_2_1_0   ;ha ESC jött, tiltjuk a kimeneteket
    JSR basic_display
    JMP loop
Check_OPA:
    CMP r12, #OPA   ;az A operandus jött?
    JNZ Check_OPERATION
    MOV r6, r15     ;megnézzük, hogy érvényes-e, mert lehet hogy OPA STATE van, de nem szám a bemenet
    JSR check_operand_validity
    MOV r5, #DATA_PROCESSED   ;jelezzük, hogy feldolgoztuk az adatot
    JZ loop         ;ha nem szám jött visszaugrunk
    AND r15, #MASK_OP  ;ha A operandus jött, kimentjük r15bõl az adatot
    MOV r0, r15
    MOV r8, #MASK_DIG2_1_0   ;csak az elsõ digit ég
    JSR set_operands;kijelezzük A-t
    JSR basic_display
    JMP loop
Check_OPERATION:
    CMP r12, #OPERATION ;mûvelet jött?
    JNZ Check_OPB
    MOV r2, r15         ;ha mûvelet jött, r2-be kimentjük 
    MOV r5, #DATA_PROCESSED       ;jelezzük, hogy feldolgoztuk az adatot
    JMP loop
Check_OPB:
    CMP r12, #OPB   ;B operandus jött?  
    JNZ Check_Equal
    MOV r6, r15     ;megnézzük, hogy érvényes-e, mert lehet hogy OPB STATE van, de nem szám a bemenet
    JSR check_operand_validity
    MOV r5, #DATA_PROCESSED   ;jelezzük, hogy feldolgoztuk az adatot
    JZ loop
    AND r15, #MASK_OP  ;ha OPB jött, kimentjük r15bõl az adatot
    MOV r1, r15
    MOV r8, #MASK_DIG1_0   ;elsõ 2 digit ég csak
    JSR set_operands
    JSR basic_display
    JMP loop
Check_Equal:
    CMP r12, #Equal     ;'=' vagy enter jött?
    MOV r5, #DATA_PROCESSED;innentõl kezdve már csak mûveletvégzés után ugrunk vissza, lehet állítani, hogy fel lett dolgozva
    JNZ loop
    ;végre kell hajtani a r2 mûveletét
    CMP r2, #ADD_A_B
    JNZ Try_SUB_A_B
    ;'+' volt
    MOV r6, r0      ;a+b, eredmény r6-ban
    ADD r6, r1
    MOV r3, r7      ;bcd konvertálás elrontja r7-et
    JSR bin_2_BCD
    MOV r7, r3
    MOV r8, #0x00   ;minden ég és nincs dp    
    JMP Main_display;kiírjuk
Try_SUB_A_B:
    CMP r2, #SUB_A_B
    JNZ Try_MUL_A_B
    ;'-' volt
    MOV r6, r0      ;a-b, eredmény r6-ban
    SUB r6, r1
    MOV r8, #0x00   ;minden ég és nincs dp
    JNC No_sub_err  ;ha nem hibás az eredmény, ugrunk
    MOV r6, #0xEE   ;error beállítása
No_sub_err:
    JMP Main_display;kiírjuk
Try_MUL_A_B:
    CMP r2, #MUL_A_B
    JNZ DO_DIV_A_B
    ;'*' volt
    MOV r3, r7      ;bcd konvertálás ép paraméterátadás elrontja r7-et
    MOV r6, r0      ;a operandus átadása
    MOV r7, r1      ;b operandus átadása
    JSR mul_a_b     
    JSR bin_2_BCD   ;eredmény bcd konvertálása
    MOV r7, r3
    MOV r8, #0x00   ;minden ég és nincs dp
    JMP Main_display;kiírjuk
DO_DIV_A_B:
    MOV r3, r7      ;bcd konvertálás ép paraméterátadás elrontja r7-et
    MOV r6, r0      ;a operandus átadása
    MOV r7, r1      ;b operandus átadása
    JSR div_a_b     
    MOV r8, #0x02   ;tizedespont
    MOV r7, r3
    JNZ Main_display
    MOV r6, #0xEE   ;error beállítása
    MOV r8, #0x00   ;minden ég és nincs dp
Main_display:
    JSR basic_display
    JMP loop
    


;betölti a és b operandusokat az r7 regiszterbe
set_operands:
    MOV r7, r0
    SWP r7
    OR r7, r1
    RTS
 
 
;eredmény r6-ban
mul_a_b:
    AND r10,#0      ;eredmény
    MOV r9, #0x01   ;mask
    MOV r8, #3      ;iterátor
    TST r7, r9      ;egyes-e
    JZ mul_cycle
    ADD r10, r6     ;elso iteráció elott hozzáadjuk, ha kell
mul_cycle:
    SL0 r9          ;maszk shiftelése
    SL0 r6          ;a szorzása 2vel
    TST r7, r9      ;egyes
    JZ no_add
    ADD r10, r6     ;eredményes hozzáadjuk a résszorzatot
no_add:
    SUB r8, #1      ;ciklusvég ellenorzés
    JNZ mul_cycle   
    MOV r6, r10     ;eredmény r6-ban tárolása
    RTS
    
;eredmény r6-ban egész rész|maradék 4-4 biten
;r6/r7 mûvelet
;használja: r6, r7, r8 ,r9, r10
div_a_b:
    OR r7, r7
    JZ ret_div      ;0 volt a b operandus
    MOV r8, #0      ;segédregiszter
    MOV r9, #0      ;eredmény
    MOV r10, #8     ;ciklusszámláló
div_loop:
    SR0 r7
    RRC r8          ;regiszterpár forgatása
    TST r7, r7
    JZ need_sub     ;felso 8 bit 0 esetén kivonással ellenorizni
    SL0 r9
    JMP div_end
need_sub:
    SUB r6, r8      ;betöltött digit ellenorzése C flaggel
    JC shift_0
    SL1 r9
    JMP div_end
shift_0:
    SL0 r9
    ADD r6, r8      ;ha 0 a betöltött digit, akkor vissza kell adni az osztót
div_end:    
    SUB r10, #1
    JNZ div_loop
    SWP r9          ;2x8 bites értékek 8 bitbe kimentése 
    OR r9, r6
    MOV r6, r9
    ADD r10, #1     ;ne legyen beállítva a Z flag 0.0 eredmény esetén
ret_div:
    RTS
    
;kijelzi az r7-r6 számokat a 7szegmenses kijelzõn  
;használja: r6, r7, r8, r9
basic_display:
    ;r7 dig3|dig2  r6 dig1|dig0 r8 blank|dp
    ;DIG2 kiírása
    TST r8, #0x40   ;blank tesztelése
    JNZ DIG2_blank  ;ugrunk, ha üres a digit
    MOV r9, r7      ;dig0 mozgatása
    AND r9, #0x0F   ;maszkolás, megkapjuk a dig0 számot
    ADD r9, #sgtbl  ;szegmens logika
    MOV r9, (r9)
    TST r8, #0x04   ;tizedespont tesztelése
    JZ load_DIG2    ;ugrunk, ha nem kell állítani
    OR r9, #0x80    ;tizedespont beállítása
load_DIG2:
    MOV DIG2, r9    ;szegmensek beállítása
    JMP DIG3_logic
DIG2_blank:
    MOV r9, #0x00   ;üres szegmens
    MOV DIG2, r9    ;szegmensek beállítása
DIG3_logic:
    ;DIG3 kiírása
    TST r8, #0x80   ;blank tesztelése
    JNZ DIG3_blank  ;ugrunk, ha üres a digit
    MOV r9, r7      ;dig1 mozgatása
    AND r9, #0xF0   ;maszkolás, megkapjuk a dig1 számot
    SWP r9          ;dig1 felsõ 4 bitrõl alsó 4 bitre konvertálása
    ADD r9, #sgtbl  ;szegmens logika
    MOV r9, (r9)
    TST r8, #0x08   ;tizedespont tesztelése
    JZ load_DIG3    ;ugrunk, ha nem kell állítani
    OR r9, #0x80    ;tizedespont beállítása
load_DIG3:
    MOV DIG3, r9    ;szegmensek beállítása
    JMP test_error_basic_display
DIG3_blank:
    MOV r9, #0x00   ;üres szegmens
    MOV DIG3, r9    ;szegmensek beállítása
test_error_basic_display:
    TST r4, #0x01
    JNZ RTS_basic_display
    ;DIG0 kiírása
DIG0_logic:
    TST r8, #0x10   ;blank tesztelése
    JNZ DIG0_blank  ;ugrunk, ha üres a digit
    MOV r9, r6      ;dig0 mozgatása
    AND r9, #0x0F   ;maszkolás, megkapjuk a dig0 számot
    ADD r9, #sgtbl  ;szegmens logika
    MOV r9, (r9)
    TST r8, #0x01   ;tizedespont tesztelése
    JZ load_DIG0    ;ugrunk, ha nem kell állítani
    OR r9, #0x80    ;tizedespont beállítása
load_DIG0:
    MOV DIG0, r9    ;szegmensek beállítása
    JMP DIG1_logic
DIG0_blank:
    MOV r9, #0x00   ;üres szegmens
    MOV DIG0, r9    ;szegmensek beállítása
DIG1_logic:
    ;DIG1 kiírása
    TST r8, #0x20   ;blank tesztelése
    JNZ DIG1_blank  ;ugrunk, ha üres a digit
    MOV r9, r6      ;dig1 mozgatása
    AND r9, #0xF0   ;maszkolás, megkapjuk a dig1 számot
    SWP r9          ;dig1 felsõ 4 bitrõl alsó 4 bitre konvertálása
    ADD r9, #sgtbl  ;szegmens logika
    MOV r9, (r9)
    TST r8, #0x02   ;tizedespont tesztelése
    JZ load_DIG1    ;ugrunk, ha nem kell állítani
    OR r9, #0x80    ;tizedespont beállítása
load_DIG1:
    MOV DIG1, r9    ;szegmensek beállítása
    RTS
DIG1_blank:
    MOV r9, #0x00   ;üres szegmens
    MOV DIG1, r9    ;szegmensek beállítása
RTS_basic_display:
    RTS


;r6-ot átalakítja BCD-re
;eredmény r6-ban
;használja r6, r7, r8, r9, r10
bin_2_BCD:
    MOV r7, #10
    JSR div_a_b
    RTS
    
;0x30<= r6 < 0x40
;ha ez nem teljesül, a Z flaget állítja
check_operand_validity:
    CMP r6, #0x30    
    JC NOT_BETWEEN 
    CMP r6, #0x40  
    JNC NOT_BETWEEN
    RTS
NOT_BETWEEN: 
    AND r6, #0x00   ;Z flag állítása
    RTS


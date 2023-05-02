DEF LD   0x80                ; LED adatregiszter                    (írható/olvasható)
DEF SW   0x81                ; DIP kapcsoló adatregiszter           (csak olvasható)
DEF TR   0x82                ; Timer kezdõállapot regiszter         (csak írható)
DEF TM   0x82                ; Timer számláló regiszter             (csak olvasható)
DEF TC   0x83                ; Timer parancs regiszter              (csak írható)
DEF TS   0x83                ; Timer státusz regiszter              (csak olvasható)
DEF BT   0x84                ; Nyomógomb adatregiszter              (csak olvasható)
DEF BTIE 0x85                ; Nyomógomb megszakítás eng. regiszter (írható/olvasható)
DEF BTIF 0x86                ; Nyomógomb megszakítás flag regiszter (olvasható és a bit 1 beírásával törölheto)
DEF BT0  0x01
DEF BT1  0x02
DEF BT2  0x04
DEF BT3  0x08
DEF DIG0 0x90
DEF DIG1 0x91
DEF DIG2 0x92
DEF DIG3 0x93

DEF TC_INI 0b11110011 ;IT en., 65536-os elõosztás, ismétléses, Timer en.
DEF TIT 0b10000000

DATA ; adatszegmens kijelölése
; A hétszegmenses dekóder szegmensképei (0-9, A-F) az adatmemóriában.
sgtbl: DB 0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f, 0x77, 0x7c, 0x39, 0x5e, 0x79, 0x71




;r7 dig3|dig2  r6 dig1|dig0 r8 blank|dp
CODE
reset: jmp main

;a két digit kezelhetõ egységesen, hisz mindkettõre E-t kell kiírni illetve tiltani kell
ISR:
    MOV r15, TS ;IT törlése
    TST r4, #0x01
    JZ IT_END
    MOV r15, DIG0   ;digit beolvasása
    TST r15, #0xFF  ;teszt, hogy nulla volt-e
    JZ DIG_zero     
    MOV r15, #0x00  ;digitek tiltása, ha égett
    MOV DIG0, r15
    MOV DIG1, r15
    RTI
DIG_zero:
    MOV r15, #0x79  ;E kiírása, ha tiltva voltak
    MOV DIG0, r15
    MOV DIG1, r15
IT_END:
    RTI ;visszatérés az IT-bõl

main:
    ;inicializálások
    MOV r4, #0x00   ;alapesetben nincs error
    MOV r6, #0x00   ;a kimenet nulla
    MOV r8, #0x00   ;minden ég és nincs dp alapesetben
    MOV r0, #122    ;Timer osztás konstans
    MOV TR, r0      ;16e6/(65536*122) -> kb. 0,5 sec
    MOV r0, #TC_INI
    MOV TC, r0      ;Timer inicializálása
    MOV r0, TS      ;esetleges jelzés törlése
    STI             ;globális IT engedélyezés
loop:
    ;a operandus kinyerése
    MOV r0, SW
    MOV r1, r0
    AND r0, #0xF0   
    SWP r0          ;r0 a operandus
    ;b operandus kinyerése
    AND r1, #0x0F   ;r1 b operandus
    ;operadnusok ellenõrzése
    CMP r0, #10     ;a < 10?
    JC a_ok
    MOV r0, #0x0E   ;ha a>10 E-t kell kiírni helyette
    OR r8, #0x70    ;alsó 3 digitet tiltjuk
    JSR set_operands
    JSR basic_display
    JMP loop        ;nem végeztetünk mûveletet ha hibás a bemenet
a_ok:
    CMP r1, #10     ;b < 10?
    AND r8, #0xBF   ;b digit tiltásának kikapcsolása
    JC b_ok
    MOV r1, #0x0E   ;ha b>10 E-t kell kiírni helyette
    OR r8, #0x30    ;alsó 2 digitet tiltjuk
    JSR set_operands
    JSR basic_display
    JMP loop        ;nem végeztetünk mûveletet ha hibás a bemenet
b_ok:
    JSR set_operands
    JSR basic_display
    MOV r2, BT      ;nyomógombok beolvasása
    MOV r3, BTIF    ;megváltozott nyomógombnál a megfelelo BTIF bit 1-lesz
    MOV BTIF, r3    ;jelzés(ek) törlése (az törlodik, ahova 1-et írunk!)
    AND r2, r3      ;azon bit lesz 1, amelyhez tartozó gombot lenyomták
BT0_tst:
    TST r2, #BT0    ;BT0 lenyomásának tesztelése (Z=0, ha lenyomták)
    JZ BT1_tst      ;következo BT tesztelése, ha nincs BT0 lenyomás
    MOV r6, r0      ;a+b, eredmény r6-ban
    ADD r6, r1
    MOV r3, r7      ;eredmény bcd konvertálása
    JSR bin_2_BCD
    MOV r7, r3
    MOV r4, #0x00   ;biztosan nincs error
    MOV r8, #0x00   ;minden ég és nincs dp
BT1_tst:
    TST r2, #BT1    ;BT1 lenyomásának tesztelése (Z=0, ha lenyomták)
    JZ BT2_tst      ;következo BT tesztelése, ha nincs BT0 lenyomás
    MOV r6, r0      ;a-b, eredmény r6-ban
    SUB r6, r1
    MOV r8, #0x00   ;minden ég és nincs dp
    JNC No_sub_err  ;ha nem hibás az eredmény, ugrunk
    MOV r4, #0x01   ;error beállítása
    JMP BT2_tst
No_sub_err:
    MOV r4, #0x00   ;nincs error
BT2_tst:
    TST r2, #BT2    ;BT2 lenyomásának tesztelése (Z=0, ha lenyomták)
    JZ BT3_tst      ;következo BT tesztelése, ha nincs BT0 lenyomás
    MOV r6, r0      ;a operandus átadása
    MOV r7, r1      ;b operandus átadása
    JSR mul_a_b     ;a BT2 lenyomása esetén végrehajtandó szubrutin
    MOV r3, r7      ;eredmény bcd konvertálása
    JSR bin_2_BCD
    MOV r7, r3
    MOV r4, #0x00   ;nincs error
    MOV r8, #0x00   ;minden ég és nincs dp
BT3_tst:
    TST r2, #BT3    ;BT3 lenyomásának tesztelése (Z=0, ha lenyomták)
    JZ Main_display
    MOV r6, r0      ;a operandus átadása
    MOV r7, r1      ;b operandus átadása
    JSR div_a_b     ;a BT3 lenyomása esetén végrehajtandó szubrutin
    JNZ No_div_err
    MOV r4, #0x01   ;error beállítása
    MOV r8, #0x00   ;minden ég és nincs dp
    JMP Main_display
No_div_err:
    MOV r4, #0x00   ;nincs error
    MOV r8, #0x02   ;tizedespont
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
    SL0 r9          ;2x8 bites értékek 8 bitbe kimentése 
    SL0 r9
    SL0 r9
    SL0 r9
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
    AND r9, #0x0F   ;maszkolás, megkapjuk a dig2 számot
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
    AND r9, #0xF0   ;maszkolás, megkapjuk a dig3 számot
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


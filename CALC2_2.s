DEF LD   0x80                ; LED adatregiszter                    (írható/olvasható)
DEF SW   0x81                ; DIP kapcsoló adatregiszter           (csak olvasható)
DEF BT   0x84                ; Nyomógomb adatregiszter              (csak olvasható)
DEF BTIE 0x85                ; Nyomógomb megszakítás eng. regiszter (írható/olvasható)
DEF BTIF 0x86                ; Nyomógomb megszakítás flag regiszter (olvasható és a bit 1 beírásával törölheto)
DEF BT0  0x01
DEF BT1  0x02
DEF BT2  0x04
DEF BT3  0x08


main:
    MOV r0, SW
    MOV r1, r0
    AND r0, #0xF0   ;r0 a operandus
    SWP r0          
    AND r1, #0x0F   ;r1 b operandus
    MOV r2, BT      ;nyomógombok beolvasása
    MOV r3, BTIF    ;megváltozott nyomógombnál a megfelelo BTIF bit 1-lesz
    MOV BTIF, r3    ;jelzés(ek) törlése (az törlodik, ahova 1-et írunk!)
    AND r2, r3      ;azon bit lesz 1, amelyhez tartozó gombot lenyomták
BT0_tst:
    TST r2, #BT0    ;BT0 lenyomásának tesztelése (Z=0, ha lenyomták)
    JZ BT1_tst      ;következo BT tesztelése, ha nincs BT0 lenyomás
    JSR add_a_b     ;a BT0 lenyomása esetén végrehajtandó szubrutin
BT1_tst:
    TST r2, #BT1    ;BT1 lenyomásának tesztelése (Z=0, ha lenyomták)
    JZ BT2_tst      ;következo BT tesztelése, ha nincs BT0 lenyomás
    JSR sub_a_b     ;a BT1 lenyomása esetén végrehajtandó szubrutin
    JZ error
BT2_tst:
    TST r2, #BT2    ;BT2 lenyomásának tesztelése (Z=0, ha lenyomták)
    JZ BT3_tst      ;következo BT tesztelése, ha nincs BT0 lenyomás
    JSR mul_a_b     ;a BT2 lenyomása esetén végrehajtandó szubrutin
BT3_tst:
    TST r2, #BT3    ;BT3 lenyomásának tesztelése (Z=0, ha lenyomták)
    JZ main         ;újratesztelés indítása
    JSR bin_div_a_b     ;a BT3 lenyomása esetén végrehajtandó szubrutin
    JNZ main
error:
    MOV r8, #0xFF   
    MOV LD, r8      ;error kiírása ledekre
    JMP main




add_a_b:
    MOV r6, r0      ;a operandus elmentése
    MOV r7, r1      ;b operandus elmentése
    ADD r6, r7      ;a és b operandus összeadása
    MOV LD, r6      ;eredmény kiírása ledekre
    RTS
    
sub_a_b:
    MOV r6, r0      ;a operandus elmentése
    MOV r7, r1      ;b operandus elmentése
    SUB r6, r7      ;a-b
    JNC no_error    ;nincs elojelváltás
    AND r6, #0x00   ;Z flag beállítás
    JZ ret_sub
no_error:
    MOV LD, r6      ;eredmény kiírása ledekre
ret_sub:
    RTS
    
mul_a_b:
    MOV r6, r0      ;a operandus elmentése
    MOV r7, r1      ;b operandus elmentése
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
    MOV LD, r10     ;eredmény kiiírása leddekre
    RTS
    
bin_div_a_b:
    MOV r6, r0      ;a operandus elmentése
    MOV r7, r1      ;b operandus elmentése
    OR r7, r7
    JZ ret_bin_div      ;0 volt a b operandus
    MOV r8, #0      ;segédregiszter
    MOV r9, #0      ;eredmény
    MOV r10, #8     ;ciklusszámláló
bin_div_loop:
    SR0 r7
    RRC r8          ;regiszterpár forgatása
    TST r7, r7
    JZ need_sub     ;felso 8 bit 0 esetén kivonással ellenorizni
    SL0 r9
    JMP bin_div_end
need_sub:
    SUB r6, r8      ;betöltött digit ellenorzése C flaggel
    JC shift_0
    SL1 r9
    JMP bin_div_end
shift_0:
    SL0 r9
    ADD r6, r8      ;ha 0 a betöltött digit, akkor vissza kell adni az osztót
bin_div_end:    
    SUB r10, #1
    JNZ bin_div_loop
    SL0 r9          ;2x8 bites értékek 8 bitbe kimentése 
    SL0 r9
    SL0 r9
    SL0 r9
    OR r9, r6
    MOV LD, r9
    ADD r10, #1     ;ne legyen beállítva a Z flag 0.0 eredmény esetén
ret_bin_div:
    RTS
    

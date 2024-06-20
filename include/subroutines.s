; For simplicity, all subroutines herein mirror the names used in
; pret/pokeplatinum
;
; https://github.com/pret/pokeplatinum

_s32_div_f              equ 0x020E1F6C  ; ARM division

LCRNG_GetSeed           equ 0x0201D2D0
LCRNG_SetSeed           equ 0x0201D2DC
LCRNG_Next              equ 0x0201D2E8

Heap_AllocFromHeap      equ 0x02018144
Heap_FreeToHeap         equ 0x020181C4

Party_InitWithCapacity  equ 0x0207A014
Party_AddPokemon        equ 0x0207A048

Pokemon_New             equ 0x02073C74
Pokemon_InitWith        equ 0x02073D80
Pokemon_SetValue        equ 0x02074B30
Pokemon_SetMoveSlot     equ 0x02077230
Pokemon_SetBallSeal     equ 0x02078AEC

TrainerClass_Gender     equ 0x020793AC
TrainerData_LoadParty   equ 0x0207939C

; These values are control codes for Pokemon_SetValue
MON_DATA_HELD_ITEM  equ 6
MON_DATA_FORM       equ 112

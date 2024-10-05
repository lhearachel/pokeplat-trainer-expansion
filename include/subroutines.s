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
Pokemon_GetValue        equ 0x02074470
Pokemon_SetValue        equ 0x02074B30
BoxPokemon_SetMoveSlot  equ 0x02077238
Pokemon_SetMoveSlot     equ 0x02077230
Pokemon_SetBallSeal     equ 0x02078AEC
Pokemon_CalcStats       equ 0x020741B8

TrainerClass_Gender     equ 0x020793AC
TrainerData_LoadParty   equ 0x0207939C

PokemonPersonalData_GetFormValue equ 0x020759CC

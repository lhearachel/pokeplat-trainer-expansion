.nds
.thumb

.open "base/arm9.bin", 0x02000000

.include "include/constants.s"
.include "include/subroutines.s"
.include "include/trpoke.s"

stack_heapID        equ [sp, #0x10]         // local_50
stack_trdataOfs     equ [sp, #0x14]         // local_4c
stack_battlerOfs    equ [sp, #0x18]         // local_48
stack_monSpecies    equ [sp, #0x1C]         // local_44
stack_monLevel      equ [sp, #0x20]         // local_40
stack_monDV         equ [sp, #0x24]         // local_3c
stack_haveMoves     equ [sp, #0x28]         // local_38
stack_haveItems     equ [sp, #0x2C]         // local_34
stack_paramsWithOfs equ [sp, #0x30]         // local_30
stack_oldSeed       equ [sp, #0x34]         // local_2c
stack_rnd           equ [sp, #0x38]         // local_28
stack_loopCounter   equ [sp, #0x3C]         // local_24
stack_trpokeBuf     equ [sp, #0x40]         // local_20
// 0x44 (reserved for form ID)
stack_pidMod        equ [sp, #0x48]         // local_18

.org 0x020793B8     ; the vanilla routine is located at this memory address
.area 0x0408, 0xFF  ; limit to 0x408 bytes of space
TrainerData_BuildParty:
    ; Inputs:
    ;   r0: ptr to BattleParams struct
    ;   r1: battler ID (in range [0..3])
    ;   r2: heap ID
    push    {r4-r7,lr}
    sub     sp, #0x4C

    mov     r4, r1              ; r4 -> battler ID
    mov     r7, r0              ; r7 -> pointer to BattleParams
    str     r2, stack_heapID

    ; Remember the current RNG seed
    bl      LCRNG_GetSeed       ; r0 -> current RNG seed
    str     r0, stack_oldSeed

    ; Allocate space for the party on the heap
    lsl     r0, r4, #2
    str     r0, stack_battlerOfs
    add     r0, r7
    ldr     r0, [r0, #0x04]     ; r0 -> pointer to Party for battlerID
    mov     r1, #6              ; r1 -> Max party size (6 mons)
    bl      Party_InitWithCapacity

    ; Allocate size for the trpoke buffer on the heap
    ldr     r0, stack_heapID    ; r0 -> heap ID
    mov     r1, #0x6C           ; r1 -> Maximum size of a single trpoke entry
    bl      Heap_AllocFromHeap  ; r0 -> pointer to heap allocation
    str     r0, stack_trpokeBuf

    ; Allocate a Pokemon struct on the heap
    ldr     r0, stack_heapID    ; r0 -> heap ID
    bl      Pokemon_New         ; r0 -> pointer to Pokemon
    mov     r6, r0              ; r6 -> pointer to Pokemon

    ; Load the trpoke buffer
    ldr     r0, stack_battlerOfs
    add     r0, r7
    ldr     r0, [r0, #0x18]     ; r0 -> trainer ID for battlerID
    ldr     r1, stack_trpokeBuf ; r1 -> pointer to trpoke buffer
    bl      TrainerData_LoadParty

    ; Load the magic gender constant for this battler's trainer class
    mov     r0, #0x34
    mul     r0, r4
    str     r0, stack_trdataOfs
    add     r0, r7              ; r0 -> pointer to TrainerData for battlerID
    add     r0, #0x29           ; r0 -> pointer to class for this trainer
    ldrb    r0, [r0, #0x00]     ; r0 -> class for this trainer
    bl      TrainerClass_Gender

    ; Compute a magic PID modifier for this trainer's gender.
    cmp     r0, #1              ; gender 1 is female
    bne     _trainerIsNotFemale

_trainerIsFemale:
    mov     r0, #0x78
   b       _continueFromCalcPID

_trainerIsNotFemale:
    mov     r0, #0x88

_continueFromCalcPID:
    str     r0, stack_pidMod

    ; Setup the loop
    ldr     r0, stack_trdataOfs
    add     r0, r7              ; r0 -> pointer to TrainerData for battlerID
    mov     r1, r0              ; r1 -> pointer to TrainerData for battlerID
    add     r0, #0x28           ; r0 -> pointer to data flags for this trainer
    add     r1, #0x2B           ; r1 -> pointer to party size for this trainer
    ldrb    r0, [r0]            ; r0 -> data flags for this trainer
    ldrb    r1, [r1]            ; r1 -> party size for this trainer

    mov     r2, #0
    str     r2, stack_loopCounter

    cmp     r1, #0
    bgt     _preLoop
    b       _cleanup

_preLoop:
    ldr     r1, stack_battlerOfs
    add     r1, r7
    str     r1, stack_paramsWithOfs
    mov     r1, #2
    and     r1, r0
    str     r1, stack_haveItems
    mov     r1, #1
    and     r1, r0
    str     r1, stack_haveMoves
    ldr     r5, stack_trpokeBuf

_mainLoop:
    ldrb    r0, [r5, #0]        ; r0 -> DV for this mon
    ldrb    r2, [r5, #1]        ; r2 -> data flags for this mon
    str     r0, stack_monDV

    ldrb    r0, [r5, #3]        ; r0 -> high byte of level
    lsl     r1, r0, #8          ; r1 -> high byte of level
    ldrb    r0, [r5, #2]        ; r0 -> low byte of level
    orr     r0, r1              ; r0 -> level for this mon
    str     r0, stack_monLevel

    ldrb    r0, [r5, #5]        ; r0 -> high byte of mon ID
    lsl     r1, r0, #8          ; r1 -> high byte of mon ID
    ldrb    r0, [r5, #4]        ; r0 -> low byte of mon ID
    orr     r0, r1              ; r0 -> mon ID for this mon (species + form)
    add     r5, r5, #6          ; Chomp through 6 bytes read so far

    ldr     r1, =0x03FF
    and     r1, r0              ; r1 -> species for this mon
    str     r1, stack_monSpecies

    asr     r0, r0, #10
    add     r1, sp, #0x44
    strb    r0, [r1]            ; sp + 0x44 -> form ID for this mon

    ; Check PID modifier override flags for gender and ability
    mov     r1, r0              ; r1 -> form ID for this mon
    ldr     r0, stack_monSpecies
    add     r3, sp, #0x48       ; r3 -> address of PID modifier
    bl      TrainerMon_CheckOverrideFlags

    ; Setup the RNG seed for this mon
    ldr     r1, stack_monDV
    ldr     r0, stack_monLevel
    add     r1, r0              ; r1 -> DV + level
    ldr     r0, stack_monSpecies
    add     r1, r0              ; r1 -> DV + level + species
    ldr     r0, stack_paramsWithOfs
    ldr     r0, [r0, #0x18]     ; r0 -> trainer ID for battler ID
    add     r0, r1              ; r0 -> DV + level + species + trainer ID
    str     r0, stack_rnd
    bl      LCRNG_SetSeed

    ; Setup the RNG chomp to generate a PID
    ldr     r0, stack_trdataOfs
    add     r0, r7
    add     r0, #0x29
    ldrb    r0, [r0]            ; r0 -> pointer to trainer class for this battler
    mov     r4, #0              ; r4 -> loop counter for RNG
    cmp     r0, #0
    ble     _continueFromChompRNG

_chompRNG:
    bl      LCRNG_Next
    str     r0, stack_rnd

    add     r4, r4, #1
    ldr     r0, stack_trdataOfs
    add     r0, r7
    add     r0, #0x29
    ldrb    r0, [r0]            ; r0 -> pointer to trainer class for this battler
    cmp     r4, r0
    blt     _chompRNG

_continueFromChompRNG:
    ldr     r0, stack_rnd       ; r0 -> generated PID
    lsl     r1, r0, #8          ; r1 -> generated PID << 8
    ldr     r0, stack_pidMod
    add     r4, r1, r0          ; r4 -> final PID

    ; Compute the IV for each stat
    ldr     r1, stack_monDV
    mov     r0, #0x1F           ; r0 -> 31 (max IV for a stat)
    mul     r0, r1
    mov     r1, #0xFF           ; r1 -> 255 (max DV)
    blx     _s32_div_f          ; r0 -> (DV * 31) / 255

    ; Initialize the new Pokemon
    mov     r3, r0              ; r3 -> IV per stat
    mov     r0, #1
    str     r0, [sp, #0x00]     ; param4 -> 1 (use input PID value)
    str     r4, [sp, #0x04]     ; param5 -> computed PID
    mov     r0, #2
    str     r0, [sp, #0x08]     ; param6 -> 2 (do not generate a shiny mon)
    mov     r0, #0
    str     r0, [sp, #0x0C]     ; param7 -> 0 (original trainer ID)
    mov     r0, r6              ; r0 -> pointer to Pokemon
    ldr     r1, stack_monSpecies
    ldr     r2, stack_monLevel
    bl      Pokemon_InitWith

    ; Set items, if the trainer flags say so
    ldr     r0, stack_haveItems
    cmp     r0, #0
    beq     _continueFromSetItem

    ldrb    r0, [r5, #1]        ; r0 -> high byte for this mon's held item
    lsl     r1, r0, #8          ; r1 -> high byte for this mon's held item
    ldrb    r0, [r5, #0]        ; r0 -> low byte for this mon's held item
    orr     r1, r0              ; r1 -> this mon's held item
    add     r5, r5, #2          ; Chomp through these two bytes

    add     r2, sp, #0x44
    add     r2, #2              ; r2 -> stack address for this mon's held item
    strh    r1, [r2]
    mov     r0, r6              ; r0 -> pointer to Pokemon
    mov     r1, #MON_DATA_HELD_ITEM
    bl      Pokemon_SetValue

_continueFromSetItem:
    ; Set moves, if the trainer flags say so
    ldr     r0, stack_haveMoves
    cmp     r0, #0
    beq     _continueFromSetMoves
    mov     r4, #0

_setMovesLoop:
    ldrb    r0, [r5, #1]        ; r0 -> high byte for this move
    lsl     r1, r0, #8          ; r1 -> high byte for this move
    ldrb    r0, [r5, #0]        ; r0 -> low byte for this move
    orr     r1, r0              ; r1 -> ID for this move
    add     r5, r5, #2          ; Chomp through these two bytes

    mov     r0, r6              ; r0 -> pointer to Pokemon
    mov     r2, r4              ; r2 -> inner loop counter (move slot)
    bl      BoxPokemon_SetMoveSlot

    add     r4, r4, #1
    cmp     r4, #4
    blt     _setMovesLoop

_continueFromSetMoves:
    ; Set the mon's friendship value
    mov     r0, r6              ; r0 -> pointer to Pokemon
    bl      TrainerMon_SetFriendship

    ; Set the mon's ball seal
    ldrb    r0, [r5, #1]        ; r0 -> high byte for this mon's ball seal
    lsl     r1, r0, #8          ; r1 -> high byte for this mon's ball seal
    ldrb    r0, [r5, #0]        ; r0 -> low byte for this mon's ball seal
    orr     r0, r1              ; r0 -> this mon's ball seal
    add     r5, r5, #2          ; Chomp through these two bytes

    mov     r1, r6              ; r1 -> pointer to Pokemon
    ldr     r2, stack_heapID
    bl      Pokemon_SetBallSeal

    ; Set the mon's form ID
    mov     r0, r6              ; r0 -> pointer to Pokemon
    mov     r1, #MON_DATA_FORM
    add     r2, sp, #0x44       ; r2 -> stack address of form ID
    bl      Pokemon_SetValue

    ; Recompute the mon's stats
    mov     r0, r6              ; r0 -> pointer to Pokemon
    bl      Pokemon_CalcStats

    ; Add the Pokemon to the party
    ldr     r0, stack_paramsWithOfs
    ldr     r0, [r0, #4]        ; r0 -> pointer to this battler's party
    mov     r1, r6              ; r1 -> pointer to Pokemon
    bl      Party_AddPokemon

    ; Setup for next iteration
    ldr     r0, stack_trdataOfs
    add     r0, r7
    add     r0, #0x2B           ; r0 -> address of trainer's party size
    ldrb    r1, [r0]            ; r1 -> trainer's party size
 
    ldr     r0, stack_loopCounter
    add     r0, r0, #1
    str     r0, stack_loopCounter

    cmp     r0, r1
    bge     _cleanup
    b       _mainLoop

_cleanup:
    ldr     r0, stack_trpokeBuf
    bl      Heap_FreeToHeap

    mov     r0, r6
    bl      Heap_FreeToHeap

    ldr     r0, stack_oldSeed
    bl      LCRNG_SetSeed

    add     sp, #0x4C
    pop     {r4-r7,pc}

.pool

TrainerMon_SetFriendship:
    ; Inputs:
    ;   r0 -> pointer to Pokemon struct
    push    {r3-r7,lr}

    mov     r5, r0              ; r5 -> pointer to Pokemon
    mov     r4, #0              ; r4 -> loop counter
    mov     r7, #0xFF           ; r7 -> max friendship value
    mov     r3, #MON_DATA_MOVE1

_checkMovesLoop:
    mov     r0, r5              ; r0 -> pointer to Pokemon
    mov     r1, r4              ; r1 -> loop counter
    add     r1, r3              ; r1 -> move slot
    mov     r2, #0
    bl      Pokemon_GetValue

    cmp     r0, #MOVE_FRUSTRATION
    bne     _iterCheckMovesLoop
    mov     r7, #0

_iterCheckMovesLoop:
    add     r4, r4, #1
    cmp     r4, #4
    blt     _checkMovesLoop

    mov     r0, r5              ; r0 -> pointer to Pokemon
    mov     r1, #MON_DATA_FRIENDSHIP
    mov     r2, sp              ; r2 -> stack address of friendship value
    strb    r7, [r2]
    bl      Pokemon_SetValue

    pop     {r3-r7,pc}

.pool

TrainerMon_CheckOverrideFlags:
    ; Inputs:
    ;   r0: species ID
    ;   r1: form ID
    ;   r2: override flags
    ;   r3: pointer to the PID modifier
    push    {r4-r7,lr}

    mov     r5, r3              ; r5 -> pointer to the PID modifier

    mov     r3, #0x0F
    and     r3, r2              ; r3 -> gender override chunk of flags
    mov     r6, r3              ; r6 -> gender override chunk of flags
    lsr     r4, r2, #4          ; r4 -> ability override chunk of flags

    cmp     r2, #0
    beq     _doneWithOverrides

    ; Override gender, if requested
    cmp     r6, #0
    beq     _skipGenderOverride

    ; Get the mon's gender ratio
    mov     r2, #MON_DATA_PERSONAL_GENDER
    bl      PokemonPersonalData_GetFormValue

    cmp     r6, #1
    bne     _forceGenderToFemale
    add     r0, r0, #2
    b       _continueFromGenderCheck

_forceGenderToFemale:
    sub     r0, r0, #2

_continueFromGenderCheck:
    str     r0, [r5]            ; PID modifier override

_skipGenderOverride:
    cmp     r4, #1
    bne     _checkAbilityOverride2
    mov     r1, #1
    bic     r0, r1              ; r0 = r0 & ~1
    str     r0, [r5]            ; PID modifier override
    pop     {r4-r7,pc}

_checkAbilityOverride2:
    cmp     r4, #2
    bne     _doneWithOverrides
    mov     r1, #1
    orr     r0, r1              ; r0 = r0 | 1
    str     r0, [r5]            ; PID modifier override

_doneWithOverrides:
    pop     {r4-r7,pc}

.pool

.endarea

.close

.nds
.thumb

.open "base/arm9.bin", 0x02000000

.include "include/subroutines.s"
.include "include/trpoke.s"

@PIDModifierOffset  equ 0x14
@FormIDOffset       equ 0x3C

@StackParam4        equ [sp, #0x00]
@StackParam5        equ [sp, #0x04]
@StackParam6        equ [sp, #0x08]
@StackParam7        equ [sp, #0x0C]
@StackHeapID        equ [sp, #0x10]
@StackPIDModifier   equ [sp, #@PIDModifierOffset]
@StackSpeciesID     equ [sp, #0x34]
@StackTrainerOffset equ [sp, #0x38]
@StackFormID        equ [sp, #@FormIDOffset]
@StackTrainerType   equ [sp, #0x40]
@StackBufferOffset  equ [sp, #0x44]
@StackMonFlags      equ [sp, #0x48]
@StackMonStruct     equ [sp, #0x50]
@StackSeedBackup    equ [sp, #0x54]
@StackRand          equ [sp, #0x58]
@StackMonLoopCtr    equ [sp, #0x5C]
@StackReadBuffer    equ [sp, #0x60]

@BattlerPartyStruct         equ 0x04
@BattlerTrainerID           equ 0x18
@BattlerTrainerType         equ 0x28    ; trdata byte 0
@BattlerTrainerClass        equ 0x29    ; trdata byte 1
@BattlerTrainerPartySize    equ 0x2B    ; trdata byte 3


.macro malloc, size, dest
    ldr     r0, @StackHeapID
    mov     r1, #size
    bl      Heap_AllocFromHeap
    str     r0, dest
.endmacro

.macro free, spofs
    ldr     r0, spofs
    bl      Heap_FreeToHeap
.endmacro

.macro ldrs, dest, offset_reg, imm
    add     dest, r4, offset_reg
    ldr     dest, [dest, #imm]
.endmacro

.macro ldrsb, dest, offset, imm
    add     dest, r4, offset
    add     dest, #imm
    ldrb    dest, [dest]
.endmacro

.macro strimm, imm, offset
    mov     r0, #imm
    str     r0, offset
.endmacro

.macro tstimm, reg, imm
    mov     r1, imm
    tst     reg, r1
.endmacro


.org 0x020793B8     ; the vanilla routine is located at this memory address
.area 0x0408, 0xFF  ; limit to 0x408 bytes of space
TrainerData_BuildParty:
    ; Inputs:
    ;   r0: ptr to BattleParams struct
    ;   r1: battler ID (in range [0..3])
    ;   r2: heap ID
    push    {r3-r7, lr}
    sub     sp, #0x68
    mov     r7, r1
    mov     r4, r0

    ; Preserve the current RNG seed
    str     r2, @StackHeapID
    bl      LCRNG_GetSeed
    str     r0, @StackSeedBackup

    ; Initialize the battler's Party struct
    lsl     r6, r7, #2      ; r6: one of [0, 4, 8, 12]
    ldrs    r0, r6, @BattlerPartyStruct
    mov     r1, #6
    bl      Party_InitWithCapacity

    ; Allocate temporary read-buffer and Pokemon struct
    malloc  0x6C, @StackReadBuffer
    ldr     r0, @StackHeapID
    bl      Pokemon_New
    str     r0, @StackMonStruct

    ; Load file from trpoke.narc
    ldrs    r0, r6, @BattlerTrainerID
    ldr     r1, @StackReadBuffer
    bl      TrainerData_LoadParty

    ; Get gender of trainer's class (one of 0, 1, or 2)
    mov     r0, 0x34
    mov     r5, r7
    mul     r5, r0
    ldrsb   r0, r5, @BattlerTrainerClass
    bl      TrainerClass_Gender

    ; Calculate magic gender constant for RNG re-seed
    mov     r1, #1
    mov     r2, #0x10
    and     r0, r1          ; r0: [0, 1, 0]
    mul     r0, r2          ; r0: [0x00, 0x10, 0x00]
    add     r0, #0x78       ; r0: [0x78, 0x88, 0x78]
    str     r0, @StackPIDModifier

    ; Set up for per-mon loop
    strimm  0, @StackMonLoopCtr
    ldrsb   r0, r5, @BattlerTrainerPartySize
    cmp     r0, #0
    ble     @Cleanup

    add     r0, r4, r6
    str     r0, @StackTrainerOffset
    ldrsb   r0, r5, @BattlerTrainerType
    str     r0, @StackTrainerType
    ldr     r7, @StackReadBuffer

@LoopPerMon:
    ; Extract species ID and form ID
    ldrh    r6, [r7, #trpoke_species]
    mov     r1, #0x3F
    lsl     r1, #10         ; r1: 0xFC00
    and     r1, r6          ; r1: 6 most-significant bits
    asr     r1, r1, #10     ; r1: form ID
    str     r1, @StackFormID

    ldr     r0, =0x03FF
    and     r0, r6          ; r0: 10 least-significant bits

    ; Handle override flags
    mov     r0, r6
    ; r1 is the form ID
    ldrb    r2, [r7, #trpoke_flags]
    add     r3, sp, @PIDModifierOffset
    bl      TrainerMon_ParseOverrideFlags

    ; Set up this mon's RNG seed
    ldrb    r1, [r7, #trpoke_dv]
    ldrh    r2, [r7, #trpoke_level]
    ldr     r3, @StackTrainerOffset
    ldr     r3, [r3, #@BattlerTrainerID]
    add     r0, r0, r1
    add     r0, r0, r2
    add     r0, r0, r3      ; r0: species + trainer ID + mon DV + mon level
    bl      LCRNG_SetSeed

    ldrsb   r0, r5, @BattlerTrainerClass
    mov     r6, #0
    cmp     r0, #0
    ble     @ContinueAfterRNG

@ChompRNG:
    bl      LCRNG_Next
    ldrsb   r1, r5, @BattlerTrainerClass
    add     r6, #1
    cmp     r6, r1
    blt     @ChompRNG

@ContinueAfterRNG:
    lsl     r1, r0, #8
    ldr     r0, @StackPIDModifier
    add     r6, r1, r0      ; r6: final personality val

    ; Compute IVs from DV
    ldrb    r3, [r7, #trpoke_dv]
    mov     r0, #0x1F       ; max IVs for a single stat (31)
    mov     r1, #0xFF       ; max DV value (255)
    mul     r3, r0
    blx     _s32_div_f

    ; Initialize this Pokemon
    mov     r3, r0              ; r3: IV value per stat
    strimm   1, @StackParam4    ; p4: init routine should take our personality input
    str     r6, @StackParam5    ; p5: personality input
    strimm   2, @StackParam6    ; p6: init routine should generate a trainer ID to force non-shiny mons
    strimm   0, @StackParam7    ; p7: irrelevant data entry
    ldr     r0, @StackMonStruct
    ldrh    r1, [r7, #trpoke_species]
    ldrh    r2, [r7, #trpoke_level]
    bl      Pokemon_InitWith

    ; From here, we will be chomping through r7 byte-by-byte, starting
    ; from 6 bytes ahead (which we have already read)
    add     r7, #trpoke_headsize

@ReadHeldItem:
    ; If bit 2 of the trainer type is set, then trpoke entries
    ; list held items for each party member
    ldr     r0, @StackTrainerType
    mov     r1, #2
    and     r0, r1
    cmp     r0, #0
    beq     @ReadMoves

    ; Set the held item
    ldr     r0, @StackMonStruct
    mov     r1, #MON_DATA_HELD_ITEM
    mov     r2, r7
    bl      Pokemon_SetValue

    add     r7, #trpoke_itemsize

@ReadMoves:
    ; If bit 1 of the trainer type is set, then trpoke entries
    ; list moves for each party member's move set
    ldr     r0, @StackTrainerType
    mov     r1, #1
    and     r0, r1
    cmp     r0, #0
    beq     @SetCommonValues

    mov     r6, #0              ; r6: read moves loop counter

@@ReadOneMove:
    ldr     r0, @StackMonStruct
    ldrh    r1, [r7]
    mov     r2, r6
    bl      Pokemon_SetMoveSlot

    add     r7, #trpoke_movesize
    add     r6, #1              ; check if we've read 4 moves
    cmp     r6, #4
    blt     @@ReadOneMove

@SetCommonValues:
    ; Set the form ID
    ldr     r0, @StackMonStruct
    mov     r1, #MON_DATA_FORM
    add     r2, sp, @FormIDOffset
    bl      Pokemon_SetValue

    ; Set the ball seal
    ldrh    r0, [r7]
    ldr     r1, @StackMonStruct
    ldr     r2, @StackHeapID
    bl      Pokemon_SetBallSeal

    ; Copy data to the party
    ldr     r0, @StackTrainerOffset
    ldr     r0, [r0, #4]
    ldr     r1, @StackMonStruct
    bl      Party_AddPokemon

    ; Set up for next iteration
    ldr     r0, @StackMonLoopCtr
    add     r0, #1
    str     r0, @StackMonLoopCtr
    add     r7, #2
    ldrsb   r1, r5, @BattlerTrainerPartySize
    cmp     r0, r1
    blt     @LoopPerMon

@Cleanup:
    free    @StackReadBuffer
    free    @StackMonStruct
    ldr     r0, @StackSeedBackup
    bl      LCRNG_SetSeed

    add     sp, #0x68
    pop     {r3-r7, pc}

.pool

TrainerMon_ParseOverrideFlags:
    ; Utility function to parse override flags for each entry in trpoke.
    ;
    ; Expected entry state is that r7 contains the address of the read-buffer
    ; for the trainer's trpoke file, and that it currently points to the head of
    ; a party member's entry in that file.
    ;
    ; Inputs:
    ;   r0: species ID
    ;   r1: form ID
    ;   r2: the mon's flags
    ;   r3: address of the PID modifier
    push    {r4-r7, lr}
    mov     r7, r0      ; mon's species ID (set back to r0 before exit)
    cmp     r2, #0
    beq     @OverrideFlagsReturn

    mov     r4, r2      ; mon's flags
    mov     r5, r3      ; address of PID modifier

    ; Check the lower half. If any bit in this range is toggled, then a gender
    ; override will occur. If *only* the least-significant bit is toggled, then
    ; the PID modifier will be set to the species' gender ratio + 2, which
    ; effectively forces the gender to male, if possible. Otherwise, the PID
    ; modifier will be set to the species' gender ratio - 2, which effectively
    ; forces the gender to female, if possible.
    ;
    ; An offset of 2 is used so that a potential parity flip as part of the
    ; ability overrides does not change the gender back from the override.
@CheckGenderOverride:
    mov     r6, #0x0F
    and     r6, r4
    cmp     r6, #0
    beq     @CheckAbilityOverride

    mov     r2, #MON_DATA_PERSONAL_GENDER
    bl      PokemonPersonalData_GetFormValue

    cmp     r6, #1
    beq     @@GenderOverrideMale

@@GenderOverrideFemale:
    sub     r0, #2
    b       @@WithGenderOverride

@@GenderOverrideMale:
    add     r0, #2

@@WithGenderOverride:
    str     r0, [r5]

    ; Check the upper half. If the least-significant bit in this range is
    ; toggled, then the PID modifier's least-significant bit will be toggled on,
    ; which effectively forces the mon's ability to be slot 1. If, instead, the
    ; second-least-significant bit is set, then the PID's modifier will be
    ; toggled on, which effectively forces the mon's ability to be slot 2.
@CheckAbilityOverride:
    ldr     r0, [r5]
    mov     r1, #1

    mov     r6, #0xF0
    and     r6, r4
    asr     r6, #4
    cmp     r6, #1
    beq     @@AbilityOverrideSlot1
    cmp     r6, #2
    bne     @OverrideFlagsReturn

@@AbilityOverrideSlot2:
    orr     r0, r1
    b       @@WithAbilityOverride

@@AbilityOverrideSlot1:
    mvn     r2, r1
    and     r0, r2

@@WithAbilityOverride:
    str     r0, [r5]

@OverrideFlagsReturn:
    mov     r0, r7
    pop     {r4-r7, pc}

.endarea ; 0x0408, 0xFF

.org 0x20797C0      ; code signature for identification by other tools
.area 0x08
.word  0x1948BA48
.ascii "LHEA"
.endarea

.close

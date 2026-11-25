.syntax unified
.arm
.text
.global _start

@ Chain the seven operations using values produced by previous instructions.
_start:
    SUB   R0, R15, R15
    ADD   R2, R0, #9
    ADD   R3, R0, #5
    ADD   R1, R2, R3         @ 14
    SUB   R4, R1, R3         @ 9
    AND   R5, R1, R4         @ 8
    ORR   R6, R5, R2         @ 9
    STR   R6, [R0, #64]
    LDR   R7, [R0, #64]      @ read 9 written by STR
    SUBS  R8, R6, R7         @ equality -> Z=1
    BEQ   equal              @ PC 0x28 -> 0x34
    ADD   R9, R0, #0xEE     @ skipped
    ADD   R9, R0, #0xEF     @ skipped
equal:
    ADD   R9, R7, #1         @ 10
done:

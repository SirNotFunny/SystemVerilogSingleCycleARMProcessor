.syntax unified
.arm
.text
.global _start

_start:
    SUB   R0, R15, R15
    ADD   R1, R0, #5
    ADD   R2, R0, #6
    SUBS  R3, R1, R1         @ equal -> Z=1
    BEQ   equal_path         @ PC 0x10 -> 0x1C, imm24 = 1
    ADD   R4, R0, #0x7E     @ skipped
    ADD   R4, R0, #0x7F     @ skipped
equal_path:
    ADD   R4, R0, #1
    SUBS  R3, R1, R2         @ unequal -> Z=0
    BEQ   done               @ PC 0x24 -> 0x28 (not taken)
    ADD   R5, R0, #2
    ADD   R6, R0, #0
loop_head:
    ADD   R6, R6, #1
    SUBS  R3, R6, #1
    BEQ   loop_head          @ PC 0x38 -> 0x30 once, then -> 0x3C
    ADD   R8, R6, #0         @ R8 = 2
done:

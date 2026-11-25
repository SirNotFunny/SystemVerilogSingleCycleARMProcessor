.syntax unified
.arm
.text
.global _start

@ The value at byte 0x0C is 0x80000000 for creating C=1 and V=1.
_start:
    SUB   R0, R15, R15
    LDR   R1, [R0, #0]       @ 0xFFFFFFFF
    LDR   R2, [R0, #4]       @ 0xAAAAAAAA
    LDR   R3, [R0, #8]       @ 0x55555555
    ADD   R4, R0, #8         @ a single set bit
    LDR   R5, [R0, #12]
    ADDS  R5, R5, R5         @ NZCV = 0111
    AND   R6, R0, R1         @ zero
    AND   R7, R1, R1         @ all ones
    ORRS  R9, R2, R3         @ all ones, NZCV = 1011
    ANDS  R8, R2, R3         @ zero, NZCV = 0111
    AND   R10, R1, R4        @ 8
    ORR   R11, R0, R0        @ zero
    ORR   R12, R1, R1        @ all ones
    ORR   R13, R0, R4        @ 8
    AND   R14, R2, #0x0F     @ 0x0A
    ORR   R4, R14, #0x05     @ 0x0F
done:

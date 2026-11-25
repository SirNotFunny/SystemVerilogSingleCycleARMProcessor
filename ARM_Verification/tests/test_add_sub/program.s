.syntax unified
.arm
.text
.global _start

@ Data at byte 0x00, 0x04, 0x08: INT_MAX, INT_MIN, -1.
_start:
    SUB   R0, R15, R15       @ R0 = 0 using the two read ports
    LDR   R1, [R0, #0]
    LDR   R2, [R0, #4]
    LDR   R3, [R0, #8]
    ADD   R4, R1, R0         @ 0x7FFFFFFF
    ADD   R5, R3, #1         @ zero, S=0
    ADDS  R6, R1, #1         @ 0x80000000, NZCV = 1001
    ADDS  R7, R2, R2         @ zero, NZCV = 0111
    ADDS  R8, R3, #1         @ zero, NZCV = 0110
    SUBS  R9, R2, #1         @ 0x7FFFFFFF, NZCV = 0011
    SUBS  R10, R0, R3        @ one, NZCV = 0000 (borrow)
    SUBS  R11, R1, R1        @ zero, NZCV = 0110 (no borrow)
    SUB   R12, R0, #1        @ -1, S=0 retains NZCV = 0110
    ADD   R13, R12, R12      @ -2
    ADD   R14, R15, #0       @ at byte 0x38, reads R15 as 0x40
done:

.syntax unified
.arm
.text
.global _start

@ Byte 0x24 contains 0, byte 0x28 contains 0xDEADBEEF.
_start:
    SUB   R0, R15, R15
    ADD   R1, R0, #32        @ base byte address 0x20
    LDR   R2, [R1, #4]
    LDR   R3, [R1, #8]
    ADD   R4, R0, #0x5A
    STR   R3, [R1, #12]      @ MEM[0x2C] = 0xDEADBEEF
    STR   R4, [R1, #16]      @ MEM[0x30] = 0x0000005A
    LDR   R5, [R1, #12]
    LDR   R6, [R1, #16]
    STR   R2, [R1, #12]      @ overwrite MEM[0x2C] with zero
    LDR   R7, [R1, #12]      @ read back the overwritten word
done:

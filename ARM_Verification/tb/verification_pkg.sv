`timescale 1ns/1ps

package verification_pkg;
    localparam integer MEMORY_WORDS = 64;
    localparam integer GPR_COUNT = 15;

    typedef enum logic [2:0] {
        K_ADD, K_SUB, K_AND, K_ORR, K_LDR, K_STR, K_BEQ, K_INVALID
    } instruction_kind_t;

    // Tat ca tin hieu trong mau nay thuoc lenh tai PC truoc canh len.
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr;
        logic [31:0] pc_next;
        logic [3:0]  flags;
        logic [31:0] src_a;
        logic [31:0] src_b;
        logic [31:0] alu_result;
        logic        pc_src;
        logic        reg_write;
        logic [3:0]  rd;
        logic [31:0] result;
        logic        mem_read;
        logic        mem_write;
        logic [31:0] read_data;
        logic [31:0] write_data;
    } cycle_sample_t;
endpackage

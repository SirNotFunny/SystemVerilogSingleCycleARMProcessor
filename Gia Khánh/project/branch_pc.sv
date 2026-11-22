`timescale 1ns/1ps

module beq_next_pc (
    input  logic [31:0] pc,
    input  logic [31:0] instr,
    input  logic        zero_flag,
    output logic [31:0] pc_plus4,
    output logic [31:0] pc_plus8,
    output logic [31:0] pc_next,
    output logic        is_beq,
    output logic        branch_taken
);
    logic [31:0] branch_offset;

    assign pc_plus4 = pc + 32'd4; //địa chỉ pc+4
    assign pc_plus8 = pc + 32'd8; //địa chỉ pc+8

    // A32 BEQ: EQ condition, branch opcode, link bit clear.
    assign is_beq = (instr[31:24] == 8'h0A);
    assign branch_taken = is_beq && zero_flag;

    // Sign-extend the word offset and convert it to bytes.
    assign branch_offset = {{6{instr[23]}}, instr[23:0], 2'b00};
    assign pc_next = branch_taken ? pc_plus8 + branch_offset : pc_plus4;
endmodule

module branch_pc #(
    parameter logic [31:0] RESET_PC = 32'h00000000
) (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] instr,
    input  logic        zero_flag,
    output logic [31:0] pc,
    output logic [31:0] pc_plus4,
    output logic [31:0] pc_plus8,
    output logic [31:0] pc_next,
    output logic        is_beq,
    output logic        branch_taken
);
    beq_next_pc next_address (
        .pc(pc),
        .instr(instr),
        .zero_flag(zero_flag),
        .pc_plus4(pc_plus4),
        .pc_plus8(pc_plus8),
        .pc_next(pc_next),
        .is_beq(is_beq),
        .branch_taken(branch_taken)
    );

    always_ff @(posedge clk) begin
        if (reset)
            pc <= RESET_PC;
        else
            pc <= pc_next;
    end
endmodule

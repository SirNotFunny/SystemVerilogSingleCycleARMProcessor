`timescale 1ns/1ps

module monitor (
    input logic        clk, reset,
    input logic [31:0] pc, instr, pc_next, src_a, src_b,
    input logic [3:0]  flags,
    input logic [31:0] alu_result, result, read_data, write_data,
    input logic        pc_src, reg_write, mem_to_reg, mem_write
);
    // Sample pre-NBA. tb_top doi #1 sau canh len truoc khi so sanh.
    verification_pkg::cycle_sample_t sampled;

    always @(posedge clk) begin
        if (!reset) begin
            sampled.pc         = pc;
            sampled.instr      = instr;
            sampled.pc_next    = pc_next;
            sampled.flags      = flags;
            sampled.src_a      = src_a;
            sampled.src_b      = src_b;
            sampled.alu_result = alu_result;
            sampled.pc_src     = pc_src;
            sampled.reg_write  = reg_write;
            sampled.rd         = instr[15:12];
            sampled.result     = result;
            sampled.mem_read   = mem_to_reg & reg_write;
            sampled.mem_write  = mem_write;
            sampled.read_data  = read_data;
            sampled.write_data = write_data;
        end
    end
endmodule

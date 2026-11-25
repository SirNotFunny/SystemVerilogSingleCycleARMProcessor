`timescale 1ns/1ps

// Kieu giao tiep top theo HDL Example 7.13. Hai bo nho doc to hop.
module top (
    input  logic        clk, reset,
    output logic [31:0] WriteData, DataAdr,
    output logic        MemWrite
);
    logic [31:0] PC, Instr, ReadData;

    arm arm_proc (
        .clk(clk), .reset(reset), .PC(PC), .Instr(Instr),
        .MemWrite(MemWrite), .ALUResult(DataAdr),
        .WriteData(WriteData), .ReadData(ReadData)
    );
    imem imem_i (.a(PC), .rd(Instr));
    dmem dmem_i (
        .clk(clk), .we(MemWrite), .a(DataAdr),
        .wd(WriteData), .rd(ReadData)
    );
endmodule

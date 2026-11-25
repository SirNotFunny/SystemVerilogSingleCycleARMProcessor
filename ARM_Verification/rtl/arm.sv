`timescale 1ns/1ps

// CPU single-cycle. PC, thanh ghi dich, Flags va RAM ghi cung canh len.
module arm (
    input  logic        clk, reset,
    output logic [31:0] PC,
    input  logic [31:0] Instr,
    output logic        MemWrite,
    output logic [31:0] ALUResult, WriteData,
    input  logic [31:0] ReadData
);
    logic [1:0] RegSrc, ImmSrc, ALUControl;
    logic       RegWrite, ALUSrc, MemtoReg, PCSrc;
    logic [3:0] ALUFlags, Flags;

    controller c (
        .clk(clk), .reset(reset), .Instr(Instr[31:12]), .ALUFlags(ALUFlags),
        .RegSrc(RegSrc), .RegWrite(RegWrite), .ImmSrc(ImmSrc), .ALUSrc(ALUSrc),
        .ALUControl(ALUControl), .MemWrite(MemWrite), .MemtoReg(MemtoReg),
        .PCSrc(PCSrc), .Flags(Flags)
    );
    datapath dp (
        .clk(clk), .reset(reset), .RegSrc(RegSrc), .RegWrite(RegWrite),
        .ImmSrc(ImmSrc), .ALUSrc(ALUSrc), .ALUControl(ALUControl),
        .MemtoReg(MemtoReg), .PCSrc(PCSrc), .ALUFlags(ALUFlags),
        .PC(PC), .Instr(Instr), .ALUResult(ALUResult),
        .WriteData(WriteData), .ReadData(ReadData)
    );
endmodule

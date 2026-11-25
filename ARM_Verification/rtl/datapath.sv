`timescale 1ns/1ps

module datapath (
    input  logic        clk, reset,
    input  logic [1:0]  RegSrc, ImmSrc, ALUControl,
    input  logic        RegWrite, ALUSrc, MemtoReg, PCSrc,
    output logic [3:0]  ALUFlags,
    output logic [31:0] PC,
    input  logic [31:0] Instr,
    output logic [31:0] ALUResult, WriteData,
    input  logic [31:0] ReadData
);
    logic [31:0] PCNext, PCPlus4, PCPlus8;
    logic [31:0] ExtImm, SrcA, SrcB, Result;
    logic [3:0] RA1, RA2;

    // Hai bo cong PC va mux PCSrc trong Hinh 7.13.
    assign PCPlus4 = PC + 32'd4;
    assign PCPlus8 = PCPlus4 + 32'd4;
    assign PCNext = PCSrc ? Result : PCPlus4;

    always_ff @(posedge clk or posedge reset)
        if (reset)
            PC <= 32'd0;
        else
            PC <= PCNext;

    assign RA1 = RegSrc[0] ? 4'd15 : Instr[19:16];
    assign RA2 = RegSrc[1] ? Instr[15:12] : Instr[3:0];
    assign Result = MemtoReg ? ReadData : ALUResult;

    regfile rf (
        .clk(clk), .we3(RegWrite), .ra1(RA1), .ra2(RA2),
        .wa3(Instr[15:12]), .wd3(Result), .r15(PCPlus8),
        .rd1(SrcA), .rd2(WriteData)
    );
    extend ext (.Instr(Instr[23:0]), .ImmSrc(ImmSrc), .ExtImm(ExtImm));
    assign SrcB = ALUSrc ? ExtImm : WriteData;

    alu alu_i (
        .a(SrcA), .b(SrcB), .control(ALUControl),
        .result(ALUResult), .flags(ALUFlags)
    );
endmodule

module regfile (
    input  logic        clk, we3,
    input  logic [3:0]  ra1, ra2, wa3,
    input  logic [31:0] wd3, r15,
    output logic [31:0] rd1, rd2
);
    logic [31:0] RF [0:14];

    assign rd1 = (ra1 == 4'd15) ? r15 : RF[ra1];
    assign rd2 = (ra2 == 4'd15) ? r15 : RF[ra2];

    // Dich R15 di qua PCSrc, nen RF chi chua R0 den R14.
    always_ff @(posedge clk)
        if (we3 && (wa3 != 4'd15))
            RF[wa3] <= wd3;
endmodule

module extend (
    input  logic [23:0] Instr,
    input  logic [1:0]  ImmSrc,
    output logic [31:0] ExtImm
);
    always_comb begin
        case (ImmSrc)
            2'b00: ExtImm = {24'b0, Instr[7:0]};                // DP imm8
            2'b01: ExtImm = {20'b0, Instr[11:0]};               // LDR/STR imm12
            2'b10: ExtImm = {{6{Instr[23]}}, Instr[23:0], 2'b00}; // B imm24
            default: ExtImm = 32'hxxxxxxxx;
        endcase
    end
endmodule

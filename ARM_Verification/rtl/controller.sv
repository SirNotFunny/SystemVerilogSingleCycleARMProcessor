`timescale 1ns/1ps

module controller (
    input  logic         clk, reset,
    input  logic [31:12] Instr,
    input  logic [3:0]   ALUFlags,
    output logic [1:0]   RegSrc, ImmSrc, ALUControl,
    output logic         RegWrite, ALUSrc, MemWrite, MemtoReg, PCSrc,
    output logic [3:0]   Flags
);
    logic [1:0] FlagW;
    logic PCS, RegW, MemW;

    decoder dec (
        .Op(Instr[27:26]), .Funct(Instr[25:20]), .Rd(Instr[15:12]),
        .FlagW(FlagW), .PCS(PCS), .RegW(RegW), .MemW(MemW),
        .MemtoReg(MemtoReg), .ALUSrc(ALUSrc), .ImmSrc(ImmSrc),
        .RegSrc(RegSrc), .ALUControl(ALUControl)
    );
    condlogic cl (
        .clk(clk), .reset(reset), .Cond(Instr[31:28]), .ALUFlags(ALUFlags),
        .FlagW(FlagW), .PCS(PCS), .RegW(RegW), .MemW(MemW),
        .PCSrc(PCSrc), .RegWrite(RegWrite), .MemWrite(MemWrite), .Flags(Flags)
    );
endmodule

module decoder (
    input  logic [1:0] Op,
    input  logic [5:0] Funct,
    input  logic [3:0] Rd,
    output logic [1:0] FlagW, ImmSrc, RegSrc, ALUControl,
    output logic       PCS, RegW, MemW, MemtoReg, ALUSrc
);
    logic Branch, ALUOp, ValidDP;

    // Main Decoder: DP Reg, DP Imm, STR, LDR va B.
    always_comb begin
        RegSrc = 2'b00;
        ImmSrc = 2'b00;
        ALUSrc = 1'b0;
        MemtoReg = 1'b0;
        MemW = 1'b0;
        Branch = 1'b0;
        ALUOp = 1'b0;

        case (Op)
            2'b00: begin
                ALUOp = 1'b1;
                ALUSrc = Funct[5];  // I = Instr[25]
            end
            2'b01: begin
                // Word, positive immediate offset, no writeback: I P U B W.
                if (Funct[5:1] == 5'b01100) begin
                    ImmSrc = 2'b01;
                    ALUSrc = 1'b1;
                    MemtoReg = Funct[0];  // L = Instr[20]
                    MemW = ~Funct[0];
                    RegSrc[1] = ~Funct[0];  // STR: RA2 = Rd
                end
            end
            2'b10: begin
                if (Funct[5:4] == 2'b10) begin  // B encoding, link = 0
                    Branch = 1'b1;
                    RegSrc = 2'b01;  // RA1 = R15 = PC + 8
                    ImmSrc = 2'b10;
                    ALUSrc = 1'b1;
                end
            end
            default: begin end
        endcase
    end

    // ALU Decoder: the same two-bit encoding as Table 7.3.
    always_comb begin
        ALUControl = 2'b00;
        ValidDP = 1'b0;
        if (ALUOp) begin
            case (Funct[4:1])
                4'b0100: begin ALUControl = 2'b00; ValidDP = 1'b1; end // ADD
                4'b0010: begin ALUControl = 2'b01; ValidDP = 1'b1; end // SUB
                4'b0000: begin ALUControl = 2'b10; ValidDP = 1'b1; end // AND
                4'b1100: begin ALUControl = 2'b11; ValidDP = 1'b1; end // ORR
                default: begin end
            endcase
        end
    end

    assign RegW = ValidDP | MemtoReg;
    assign FlagW[1] = ValidDP & Funct[0];                    // N, Z
    assign FlagW[0] = ValidDP & Funct[0] & ~ALUControl[1];   // C, V
    assign PCS = Branch | (RegW & (Rd == 4'd15));
endmodule

module condlogic (
    input  logic       clk, reset,
    input  logic [3:0] Cond, ALUFlags,
    input  logic [1:0] FlagW,
    input  logic       PCS, RegW, MemW,
    output logic       PCSrc, RegWrite, MemWrite,
    output logic [3:0] Flags
);
    logic N, Z, C, V, CondEx;
    assign {N, Z, C, V} = Flags;

    always_comb begin
        case (Cond)
            4'h0: CondEx = Z;                // EQ
            4'h1: CondEx = ~Z;               // NE
            4'h2: CondEx = C;                // CS/HS
            4'h3: CondEx = ~C;               // CC/LO
            4'h4: CondEx = N;                // MI
            4'h5: CondEx = ~N;               // PL
            4'h6: CondEx = V;                // VS
            4'h7: CondEx = ~V;               // VC
            4'h8: CondEx = C & ~Z;           // HI
            4'h9: CondEx = ~C | Z;           // LS
            4'ha: CondEx = (N == V);         // GE
            4'hb: CondEx = (N != V);         // LT
            4'hc: CondEx = ~Z & (N == V);    // GT
            4'hd: CondEx = Z | (N != V);     // LE
            4'he: CondEx = 1'b1;             // AL
            default: CondEx = 1'b0;
        endcase
    end

    assign PCSrc    = PCS  & CondEx & ~reset;
    assign RegWrite = RegW & CondEx & ~reset;
    assign MemWrite = MemW & CondEx & ~reset;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            Flags <= 4'b0000;
        end else begin
            if (CondEx && FlagW[1])
                Flags[3:2] <= ALUFlags[3:2];
            if (CondEx && FlagW[0])
                Flags[1:0] <= ALUFlags[1:0];
        end
    end
endmodule

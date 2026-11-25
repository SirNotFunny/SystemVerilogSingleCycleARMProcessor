`timescale 1ns/1ps

// 64 word x 32 bit. a la dia chi byte, a[7:2] la chi so word.
module imem (
    input  logic [31:0] a,
    output logic [31:0] rd
);
    logic [31:0] RAM [0:63];
    logic valid_address;

    assign valid_address = (a[31:8] == 24'd0) && (a[1:0] == 2'b00);
    assign rd = valid_address ? RAM[a[7:2]] : 32'hxxxxxxxx;
endmodule

module dmem (
    input  logic        clk, we,
    input  logic [31:0] a, wd,
    output logic [31:0] rd
);
    logic [31:0] RAM [0:63];
    logic valid_address;

    assign valid_address = (a[31:8] == 24'd0) && (a[1:0] == 2'b00);
    assign rd = valid_address ? RAM[a[7:2]] : 32'hxxxxxxxx;

    // Testbench nap RAM khi reset. Lenh STR ghi dong bo o canh len.
    always @(posedge clk)
        if (we && valid_address)
            RAM[a[7:2]] <= wd;
endmodule

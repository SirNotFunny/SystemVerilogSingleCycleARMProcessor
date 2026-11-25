`timescale 1ns/1ps

module alu (
    input  logic [31:0] a, b,
    input  logic [1:0]  control,
    output logic [31:0] result,
    output logic [3:0]  flags
);
    logic subtract, carry, overflow;
    logic [31:0] add_b;
    logic [32:0] sum;

    assign subtract = (control == 2'b01);
    assign add_b = subtract ? ~b : b;
    assign sum = {1'b0, a} + {1'b0, add_b} + {32'b0, subtract};

    always_comb begin
        case (control)
            2'b00, 2'b01: result = sum[31:0];
            2'b10: result = a & b;
            2'b11: result = a | b;
            default: result = 32'hxxxxxxxx;
        endcase
    end

    // Trong phep tru, C = 1 khi khong can muon.
    assign carry = ~control[1] & sum[32];
    assign overflow = ~control[1] & ~(a[31] ^ add_b[31]) &
                      (a[31] ^ sum[31]);
    assign flags = {result[31], (result == 32'd0), carry, overflow};
endmodule

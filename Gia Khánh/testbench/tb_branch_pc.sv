`timescale 1ns/1ps

module tb_branch_pc;
    localparam logic [31:0] RESET_PC = 32'h00000100;
    localparam logic [31:0] ADD_WORD = 32'hE2811001;
    localparam logic [31:0] BEQ_FORWARD = 32'h0A000001;
    localparam logic [31:0] BEQ_BACKWARD = 32'h0AFFFFFC;
    localparam logic [31:0] BEQ_ZERO_OFFSET = 32'h0A000000;
    localparam logic [31:0] BNE_WORD = 32'h1A000001;

    logic clk = 0;
    logic reset = 1;
    logic [31:0] instr = ADD_WORD;
    logic zero_flag = 0;

    wire [31:0] pc, pc_plus4, pc_plus8, pc_next;
    wire is_beq, branch_taken;

    logic [31:0] reference_pc;
    int taken_count = 0;
    int not_taken_count = 0;

    branch_pc #(.RESET_PC(RESET_PC)) dut (
        .clk(clk),
        .reset(reset),
        .instr(instr),
        .zero_flag(zero_flag),
        .pc(pc),
        .pc_plus4(pc_plus4),
        .pc_plus8(pc_plus8),
        .pc_next(pc_next),
        .is_beq(is_beq),
        .branch_taken(branch_taken)
    );
    scoreboard sb();

    always #5 clk = ~clk;

    task automatic reset_pc(input string name);
        @(negedge clk);
        reset = 1;
        @(posedge clk);
        #1;
        reference_pc = RESET_PC;
        sb.check_word(name, pc, reference_pc);
        $display("%s: PC=%08h", name, pc);
    endtask

    task automatic run_case(
        input string name,
        input logic [31:0] word,
        input logic [31:0] lhs,
        input logic [31:0] rhs,
        input bit expected_beq,
        input logic [31:0] target
    );
        bit expected_taken;
        logic [31:0] expected_next;

        // Driver: model the Z flag from a prior subtraction.
        @(negedge clk);
        reset = 0;
        instr = word;
        zero_flag = ((lhs - rhs) == 32'd0);

        // Reference: use operand equality and the known label address.
        expected_taken = expected_beq && (lhs == rhs);
        expected_next = expected_taken ? target : reference_pc + 32'd4;

        // Monitor the current instruction before the PC update.
        @(posedge clk);
        sb.check_word({name, ".pc"}, pc, reference_pc);
        sb.check_word({name, ".pc_plus4"}, pc_plus4, reference_pc + 32'd4);
        sb.check_word({name, ".pc_plus8"}, pc_plus8, reference_pc + 32'd8);
        sb.check_word({name, ".is_beq"}, {31'b0, is_beq}, {31'b0, expected_beq});
        sb.check_word({name, ".taken"}, {31'b0, branch_taken}, {31'b0, expected_taken});
        sb.check_word({name, ".pc_next"}, pc_next, expected_next);
        $display("%s: PC=%08h Z=%b taken=%b next=%08h expected=%08h",
                 name, pc, zero_flag, branch_taken, pc_next, expected_next);

        if (is_beq === 1'b1) begin
            case (branch_taken)
                1'b1: taken_count++;
                1'b0: not_taken_count++;
                default: ; // The scoreboard detects an unknown decision.
            endcase
        end

        // Wait for the register update before checking committed PC.
        #1;
        reference_pc = expected_next;
        sb.check_word({name, ".committed_pc"}, pc, reference_pc);
    endtask

    initial begin
        reset_pc("startup_reset");
        run_case("sequential", ADD_WORD, 5, 5, 0, 0);                 // 100 -> 104
        run_case("beq_equal_forward", BEQ_FORWARD, 5, 5, 1, 'h110);   // 104 -> 110
        run_case("beq_equal_backward", BEQ_BACKWARD, 7, 7, 1, 'h108); // 110 -> 108

        reset_pc("restart_reset");
        run_case("restart_sequential", ADD_WORD, 5, 5, 0, 0);         // 100 -> 104
        run_case("beq_unequal", BEQ_FORWARD, 5, 6, 1, 'h110);         // 104 -> 108
        run_case("beq_zero_offset", BEQ_ZERO_OFFSET, 0, 0, 1, 'h110); // 108 -> 110
        run_case("bne_not_beq", BNE_WORD, 5, 6, 0, 0);                // 110 -> 114

        $display("COVERAGE: BEQ taken=%0d not-taken=%0d", taken_count, not_taken_count);
        sb.check_word("coverage.taken", taken_count, 32'd3);
        sb.check_word("coverage.not_taken", not_taken_count, 32'd1);
        sb.report();
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: timeout");
    end
endmodule

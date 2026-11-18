`timescale 1ns/1ps

module scoreboard;
    int checks = 0;
    int failures = 0;

    task automatic check_word(
        input string name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        checks++;
        // Treat X and Z as mismatches against a known value.
        if (actual !== expected) begin
            failures++;
            $error("%s: expected=%08h actual=%08h", name, expected, actual);
        end
    endtask

    task automatic report();
        if (checks == 0 || failures != 0)
            $fatal(1, "FAIL: %0d failures in %0d checks", failures, checks);
        $display("PASS: %0d checks", checks);
    endtask
endmodule

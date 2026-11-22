// Dùng cùng thang thời gian với testbench.
`timescale 1ns/1ps

// So sánh kết quả và tổng kết bài kiểm thử.
module scoreboard;
    int checks = 0;   // Tổng lượt kiểm tra.
    int failures = 0; // Tổng lượt sai.

    // So sánh hai giá trị 32 bit.
    task automatic check_word(
        input string name,          // Tên lượt kiểm tra.
        input logic [31:0] actual,  // Giá trị thực tế.
        input logic [31:0] expected // Giá trị kỳ vọng.
    );
        checks++; // Đếm lượt kiểm tra.
        if (actual !== expected) begin // So sánh cả X và Z.
            failures++; // Đếm lượt sai.
            $error("%s: expected=%08h actual=%08h", name, expected, actual); // In sai lệch.
        end
    endtask

    // Báo kết quả chung.
    task automatic report();
        if (checks == 0 || failures != 0) // Báo lỗi nếu thiếu lượt kiểm tra hoặc có sai lệch.
            $fatal(1, "FAIL: %0d failures in %0d checks", failures, checks);
        $display("PASS: %0d checks", checks); // In tổng lượt đạt.
    endtask
endmodule
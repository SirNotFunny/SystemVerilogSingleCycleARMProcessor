// Đơn vị mô phỏng 1 ns, độ chính xác 1 ps.
`timescale 1ns/1ps

// Cấp lệnh và kiểm tra PC của DUT.
module tb_branch_pc;
    localparam logic [31:0] RESET_PC = 32'h00000100;        // Địa chỉ reset.
    localparam logic [31:0] ADD_WORD = 32'hE2811001;        // Lệnh ADD.
    localparam logic [31:0] BEQ_FORWARD = 32'h0A000001;     // BEQ tiến.
    localparam logic [31:0] BEQ_BACKWARD = 32'h0AFFFFFC;    // BEQ lùi.
    localparam logic [31:0] BEQ_ZERO_OFFSET = 32'h0A000000; // BEQ có offset 0.
    localparam logic [31:0] BNE_WORD = 32'h1A000001;        // Lệnh BNE.

    logic clk = 0;                // Clock bắt đầu ở mức thấp.
    logic reset = 1;              // Bật reset lúc khởi động.
    logic [31:0] instr = ADD_WORD; // Lệnh đầu vào mặc định.
    logic zero_flag = 0;          // Cờ Z đầu vào mặc định.

    wire [31:0] pc, pc_plus4, pc_plus8, pc_next; // Các địa chỉ từ DUT.
    wire is_beq, branch_taken;                 // Các cờ từ DUT.

    logic [31:0] reference_pc; // PC kỳ vọng.
    int taken_count = 0;       // Số lần BEQ lấy nhánh.
    int not_taken_count = 0;   // Số lần BEQ đi tuần tự.

    // Tạo khối kiểm thử với địa chỉ reset đã chọn.
    branch_pc #(.RESET_PC(RESET_PC)) dut (
        .clk(clk),                   // Cấp clock.
        .reset(reset),               // Cấp reset.
        .instr(instr),               // Cấp mã lệnh.
        .zero_flag(zero_flag),       // Cấp cờ Z.
        .pc(pc),                     // Đọc PC hiện tại.
        .pc_plus4(pc_plus4),         // Đọc PC + 4.
        .pc_plus8(pc_plus8),         // Đọc PC + 8.
        .pc_next(pc_next),           // Đọc PC kế tiếp.
        .is_beq(is_beq),             // Đọc kết quả giải mã.
        .branch_taken(branch_taken) // Đọc quyết định nhánh.
    );
    scoreboard sb(); // Tạo bộ kiểm tra.

    always #5 clk = ~clk; // Đảo clock mỗi 5 ns, chu kỳ 10 ns.

    // Reset PC và kiểm tra giá trị đã chốt.
    task automatic reset_pc(input string name);
        @(negedge clk);                        // Đợi cạnh xuống.
        reset = 1;                             // Bật reset.
        @(posedge clk);                        // DUT lấy mẫu reset.
        #1;                                    // Đợi PC cập nhật.
        reference_pc = RESET_PC;               // Đặt PC kỳ vọng.
        sb.check_word(name, pc, reference_pc); // So sánh PC.
        $display("%s: PC=%08h", name, pc);      // In PC dạng hex.
    endtask

    // Chạy và kiểm tra một lệnh.
    task automatic run_case(
        input string name,         // Tên ca kiểm thử.
        input logic [31:0] word,   // Mã lệnh đầu vào.
        input logic [31:0] lhs,    // Toán hạng trái.
        input logic [31:0] rhs,    // Toán hạng phải.
        input bit expected_beq,    // Kết quả giải mã kỳ vọng.
        input logic [31:0] target  // Đích nhánh kỳ vọng.
    );
        bit expected_taken;         // Quyết định nhánh kỳ vọng.
        logic [31:0] expected_next; // PC kế tiếp kỳ vọng.

        @(negedge clk);                    // Đổi đầu vào tại cạnh xuống.
        reset = 0;                         // Nhả reset.
        instr = word;                      // Cấp lệnh.
        zero_flag = ((lhs - rhs) == 32'd0); // Giả lập cờ Z từ phép trừ.

        expected_taken = expected_beq && (lhs == rhs); // Tính điều kiện nhánh.
        expected_next = expected_taken ? target : reference_pc + 32'd4; // Chọn PC kỳ vọng.

        @(posedge clk); // Đọc kết quả trước khi PC được chốt.
        sb.check_word({name, ".pc"}, pc, reference_pc); // Kiểm tra PC hiện tại.
        sb.check_word({name, ".pc_plus4"}, pc_plus4, reference_pc + 32'd4); // Kiểm tra PC + 4.
        sb.check_word({name, ".pc_plus8"}, pc_plus8, reference_pc + 32'd8); // Kiểm tra PC + 8.
        sb.check_word({name, ".is_beq"}, {31'b0, is_beq}, {31'b0, expected_beq}); // Kiểm tra giải mã.
        sb.check_word({name, ".taken"}, {31'b0, branch_taken}, {31'b0, expected_taken}); // Kiểm tra nhánh.
        sb.check_word({name, ".pc_next"}, pc_next, expected_next); // Kiểm tra PC kế tiếp.

        // In kết quả của ca kiểm thử.
        $display("%s: PC=%08h Z=%b taken=%b next=%08h expected=%08h",
                 name, pc, zero_flag, branch_taken, pc_next, expected_next);

        if (is_beq === 1'b1) begin // Chỉ đếm lệnh BEQ.
            case (branch_taken)
                1'b1: taken_count++;     // Đếm lần lấy nhánh.
                1'b0: not_taken_count++; // Đếm lần đi tuần tự.
                default: ;              // X và Z đã được kiểm tra ở trên.
            endcase
        end

        #1; // Đợi PC cập nhật sau cạnh lên.
        reference_pc = expected_next; // Cập nhật PC tham chiếu.
        sb.check_word({name, ".committed_pc"}, pc, reference_pc); // Kiểm tra PC đã chốt.
    endtask

    // Chạy lần lượt các ca kiểm thử.
    initial begin
        reset_pc("startup_reset");                                   // Reset đầu bài.
        run_case("sequential", ADD_WORD, 5, 5, 0, 0);                  // 0x100 -> 0x104.
        run_case("beq_equal_forward", BEQ_FORWARD, 5, 5, 1, 'h110);    // 0x104 -> 0x110.
        run_case("beq_equal_backward", BEQ_BACKWARD, 7, 7, 1, 'h108); // 0x110 -> 0x108.

        reset_pc("restart_reset");                                    // Reset giữa bài.
        run_case("restart_sequential", ADD_WORD, 5, 5, 0, 0);          // 0x100 -> 0x104.
        run_case("beq_unequal", BEQ_FORWARD, 5, 6, 1, 'h110);          // 0x104 -> 0x108.
        run_case("beq_zero_offset", BEQ_ZERO_OFFSET, 0, 0, 1, 'h110);  // 0x108 -> 0x110.
        run_case("bne_not_beq", BNE_WORD, 5, 6, 0, 0);                 // 0x110 -> 0x114.

        $display("COVERAGE: BEQ taken=%0d not-taken=%0d", taken_count, not_taken_count);
        sb.check_word("coverage.taken", taken_count, 32'd3);          // Kỳ vọng 3 lần lấy nhánh.
        sb.check_word("coverage.not_taken", not_taken_count, 32'd1);  // Kỳ vọng 1 lần đi tuần tự.
        sb.report(); // Báo PASS hoặc FAIL.
        $finish;    // Kết thúc mô phỏng.
    end

    // Giới hạn thời gian mô phỏng.
    initial begin
        #1000;                     // Đợi 1000 ns.
        $fatal(1, "FAIL: timeout"); // Dừng nếu bài test chưa xong.
    end
endmodule
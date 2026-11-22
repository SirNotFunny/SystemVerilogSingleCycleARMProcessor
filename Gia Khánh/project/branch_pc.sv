// Mô phỏng dùng 1 ns/1 ps. Chỉ thị này là tùy chọn vì RTL không có #delay.
`timescale 1ns/1ps

// Tính PC kế tiếp cho lệnh BEQ A32.
module beq_next_pc (
    input  logic [31:0] pc,           // Địa chỉ lệnh hiện tại.
    input  logic [31:0] instr,        // Mã lệnh A32.
    input  logic        zero_flag,    // Cờ Z.
    output logic [31:0] pc_plus4,     // Địa chỉ lệnh tuần tự.
    output logic [31:0] pc_plus8,     // Mốc tính đích nhánh.
    output logic [31:0] pc_next,      // Địa chỉ kế tiếp.
    output logic        is_beq,       // Nhận diện lệnh BEQ.
    output logic        branch_taken  // Quyết định lấy nhánh.
);
    logic [31:0] branch_offset; // Độ lệch có dấu theo byte.

    assign pc_plus4 = pc + 32'd4; // Mỗi lệnh A32 dài 4 byte.
    assign pc_plus8 = pc + 32'd8; // Nhánh A32 dùng mốc PC + 8.

    assign is_beq = (instr[31:24] == 8'h0A); // 0 là EQ, A là mã B.
    assign branch_taken = is_beq && zero_flag; // Lấy nhánh khi BEQ và Z = 1.

    assign branch_offset = {{6{instr[23]}}, instr[23:0], 2'b00}; // Nhân offset với 4 và mở rộng dấu.
    assign pc_next = branch_taken ? pc_plus8 + branch_offset : pc_plus4; // Chọn đích nhánh hoặc PC + 4.
endmodule

// Nối mạch tính địa chỉ với thanh ghi PC.
module branch_pc #(
    parameter logic [31:0] RESET_PC = 32'h00000000 // Địa chỉ lúc reset.
) (
    input  logic        clk,          // Clock do bên ngoài cấp.
    input  logic        reset,        // Reset đồng bộ mức cao.
    input  logic [31:0] instr,        // Mã lệnh tại PC.
    input  logic        zero_flag,    // Cờ Z đã lưu.
    output logic [31:0] pc,           // PC đang được lưu.
    output logic [31:0] pc_plus4,     // Địa chỉ tuần tự.
    output logic [31:0] pc_plus8,     // Mốc tính đích nhánh.
    output logic [31:0] pc_next,      // Địa chỉ chờ chốt.
    output logic        is_beq,       // Cờ nhận diện BEQ.
    output logic        branch_taken  // Cờ lấy nhánh.
);
    // Nối từng cổng của mạch tính địa chỉ.
    beq_next_pc next_address (
        .pc(pc),                     // Hồi tiếp PC hiện tại.
        .instr(instr),               // Cấp mã lệnh.
        .zero_flag(zero_flag),       // Cấp cờ Z.
        .pc_plus4(pc_plus4),         // Xuất PC + 4.
        .pc_plus8(pc_plus8),         // Xuất PC + 8.
        .pc_next(pc_next),           // Xuất địa chỉ đã chọn.
        .is_beq(is_beq),             // Xuất kết quả giải mã.
        .branch_taken(branch_taken) // Xuất quyết định nhánh.
    );

    always_ff @(posedge clk) begin // Chốt PC tại cạnh lên.
        if (reset)                // Ưu tiên reset.
            pc <= RESET_PC;       // Nạp địa chỉ reset.
        else
            pc <= pc_next;        // Nạp địa chỉ kế tiếp.
    end
endmodule
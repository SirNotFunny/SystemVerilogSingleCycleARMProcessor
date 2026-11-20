# Phân công dự án ARM single-cycle

| Thành viên | Khối RTL phụ trách | Phần kiểm thử |
|---|---|---|
| Dũng | ALU (`alu.sv`), bộ thanh ghi, mở rộng immediate và module mux dùng chung (`mux.sv`). | `ADD`, `SUB`, `AND`, `OR` và Reference Model. |
| Đạt | Bộ nhớ lệnh (`imem.sv`), bộ nhớ dữ liệu (`dmem.sv`) và mux ghi về thanh ghi từ bộ nhớ. | `LD`, `ST`, Driver và Monitor. |
| Gia Khánh | PC và nhánh BEQ ([branch_pc.sv](Gia%20Kh%C3%A1nh/project/branch_pc.sv)), Control Unit và đường chọn PC. | `BEQ` taken/not-taken, kiểm tra PC, Scoreboard và tổng hợp coverage. |
| Cả nhóm | Ghép RTL giảng viên cấp thành CPU top-level. | Kiểm thử reset, chạy chương trình ASM dùng đủ 7 lệnh và chuẩn bị `run.do`. |

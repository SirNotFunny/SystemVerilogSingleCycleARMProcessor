# Phân công dự án ARM Single-Cycle

| Thành viên | Khối RTL phụ trách trong DUT | Công việc kiểm chứng |
|---|---|---|
| Dũng | Register File, Extend, mux `RegSrc` và `ALUSrc`, ALU và các cờ ALU. | Kiểm tra `ADD`/`SUB` với 0, toán hạng bằng nhau, số âm/dương và giá trị biên. Kiểm tra `AND`/`OR` với mẫu toàn 0, toàn 1, xen kẽ và toán hạng chỉ có một bit 1. Kiểm tra kết quả và thanh ghi đích. Viết Reference Model độc lập cho PC, thanh ghi và bộ nhớ theo đặc tả 7 lệnh. |
| Đạt | Instruction Memory (`imem`), Data Memory (`dmem`) và mux `MemtoReg`. | Kiểm tra `LD` ở ít nhất hai địa chỉ hợp lệ với dữ liệu 0 và các mẫu bit khác. Kiểm tra `ST` với nhiều địa chỉ và giá trị, có ghi đè và đọc lại. Viết Driver tạo clock/reset, nạp chương trình và dữ liệu. Viết Monitor quan sát PC, mã lệnh, kết quả ALU, ghi thanh ghi, truy cập bộ nhớ và kết quả nhánh. |
| Gia Khánh | Thanh ghi PC, bộ cộng `PC+4` và `PC+8`, mux `PCSrc` và Control Unit. | Kiểm tra `BEQ` với toán hạng bằng và khác nhau, xác nhận taken/not-taken và PC kế tiếp. Viết Scoreboard đối chiếu DUT với Reference Model và tự báo PASS/FAIL kèm sai lệch. Tổng hợp coverage 7 lệnh, nhánh, bộ nhớ, toán hạng và chương trình tích hợp. |

## Cả nhóm

- Đối chiếu và ghép RTL giảng viên cấp theo sơ đồ. Lập Test Plan trước khi viết testbench, ghi mục tiêu, đầu vào, chuỗi lệnh, kết quả kỳ vọng, tín hiệu quan sát và tiêu chí PASS/FAIL.
- Ghép testbench SystemVerilog và chạy các ca riêng, chạy tuần tự, reset lúc khởi động và reset rồi chạy lại. Chạy một chương trình tích hợp đủ 7 lệnh, có dữ liệu từ lệnh trước dùng cho lệnh sau, có `LD`, `ST` và `BEQ`. Đối chiếu trạng thái cuối với Reference Model.
- Nộp mã nguồn, test case, `run.do` và hướng dẫn chạy lại trên ModelSim Intel FPGA Starter Edition 10.5b, kèm log PASS/FAIL, waveform và coverage summary. Báo cáo tập lệnh, datapath, controller, luồng thực thi, kết quả, lỗi phát hiện, cách debug, giới hạn và hướng cải tiến. Chuẩn bị demo. [Đề cuối kỳ](Project_Cuoi_Ky_Thiet_Ke_So_Va_Vi_Xu_Ly_ARM.pdf)

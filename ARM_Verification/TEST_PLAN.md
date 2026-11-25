# Verification Plan

## Quy ước và tiêu chí chung

- PC bắt đầu từ byte 0. Mỗi lệnh A32 dài 4 byte. `program.hex` là ảnh lệnh, `data.hex` là ảnh Data Memory. Hai vùng có địa chỉ độc lập.
- Trước cạnh lên, Monitor chụp PC, Instr, NZCV, SrcA, SrcB, ALUResult, PCNext, PCSrc, RegWrite và tín hiệu truy cập bộ nhớ. Khi có ghi thanh ghi hoặc truy cập memory, so thêm Rd, Result, WriteData hoặc ReadData theo thao tác.
- Sau cạnh lên 1 ns, Scoreboard so PC, NZCV, 15 thanh ghi và 64 word Data Memory với Reference Model. Giá trị kỳ vọng do mô hình tự tính từ ảnh lệnh và trạng thái riêng.
- Khi reset, kiểm tra PC và NZCV về 0, RegWrite/MemWrite bằng 0, RF và Data Memory khớp hợp đồng giữ trạng thái.
- Một ca đạt khi từng bước khớp, đúng số lệnh đã thực thi và tới đúng PC dừng. Các ví dụ số dưới đây là kết quả kỳ vọng tính theo A32.

## Truy vết yêu cầu sang ca kiểm thử

| Ca | Mục tiêu và đầu vào | Chuỗi lệnh và kỳ vọng tiêu biểu | Quan sát |
|---|---|---|---|
| **ADD/SUB** · `test_add_sub` | 0, bằng/khác nhau, âm/dương, INT_MIN, INT_MAX, phép trừ có/không mượn, R15 làm nguồn | Data ở byte 0, 4, 8 là `7FFFFFFF`, `80000000`, `FFFFFFFF`. `ADDS` tại PC `0x18` ghi `R6=80000000`, NZCV `1001`. Tại `0x1C` ghi `R7=0`, NZCV `0111`. `SUBS` tại `0x24` ghi `R9=7FFFFFFF`, NZCV `0011`. `SUBS` bằng nhau tại `0x2C` ghi `R11=0`, NZCV `0110`. `ADD R14,R15,#0` tại `0x38` ghi `R14=0x40`. | SrcA, SrcB, ALUResult, RegWrite, Rd, RF và NZCV |
| **AND/OR** · `test_logic` | Toàn 0, toàn 1, xen kẽ, một bit 1, thanh ghi và imm8 | Data tại 0, 4, 8, 12 là `FFFFFFFF`, `AAAAAAAA`, `55555555`, `80000000`. Sau `ADDS`, cờ C và V cùng bằng 1. `ORRS` tại `0x24` ghi `R9=FFFFFFFF`, NZCV `1011`. `ANDS` tại `0x28` ghi `R8=0`, NZCV `0111`. Kết quả one-hot `R10=8` và `R13=8`. Cuối ca `R4=0x0F`. | ALUResult, RegWrite, Rd, RF, N/Z cập nhật và C/V được giữ theo Chương 7 |
| **LD/ST** · `test_memory` | Địa chỉ byte với base khác 0, đọc zero/nonzero, store nhiều địa chỉ, ghi đè và đọc lại | `R1=0x20`. Load tại `0x24` và `0x28` cho `R2=0` và `R3=DEADBEEF`. Store ghi `DEADBEEF` vào byte `0x2C` và `5A` vào `0x30`. Load lại cho `R5=DEADBEEF`, `R6=5A`. Store ghi đè byte `0x2C` bằng 0, load lại cho `R7=0`. | ALUResult là địa chỉ, WriteData, ReadData, MemWrite, RegWrite, RF và Data Memory |
| **BEQ** · `test_branch` | Toán hạng bằng/khác, nhánh tiến và nhánh lùi | `SUBS` tạo Z từ ALU. `BEQ` tại PC `0x10` nhảy tới `0x1C`. Tại `0x24` đi tới `0x28`. Tại `0x38` nhảy lùi về `0x30` một lần, sau đó đi tới `0x3C`. Cuối ca `R4=1`, `R5=2`, `R8=2`. | Instr, NZCV, SrcA = PC+8, SrcB = offset byte, PCSrc, PCNext và PC thật sau cạnh lên |
| **Tích hợp** · `test_integration` | Dữ liệu từ lệnh trước truyền sang lệnh sau, đủ bảy lệnh | `R2=9`, `R3=5`. `ADD → SUB → AND → ORR` cho `R1=14`, `R4=9`, `R5=8`, `R6=9`. Store/load qua byte `0x40` cho `R7=9`. `SUBS` đặt Z, `BEQ` từ `0x28` tới `0x34`. Cuối ca `R8=0`, `R9=10`, bộ nhớ tại byte `0x40` bằng 9. | Cả trạng thái kiến trúc, thứ tự PC và đủ 7 lớp lệnh trong cùng ca |
| **Reset và chạy lại** · `reset_replay` | Reset sau khi chương trình tích hợp đã cập nhật cờ, RF, memory | Dùng lại ảnh lệnh đã nạp. Ngay sau reset, PC và NZCV về 0 và dữ liệu đã store tại byte `0x40` vẫn bằng 9. Chạy lại cùng chương trình và đạt cùng PC dừng/kết quả. | Reset, PC, NZCV, RegWrite, MemWrite, RF, Data Memory |

## Điểm dừng kỳ vọng

| Ca | Word trong file lệnh | Lệnh thực thi | PC dừng |
|---|---:|---:|---:|
| ADD/SUB | 15 | 15 | `0x3C` |
| AND/OR | 17 | 17 | `0x44` |
| LD/ST | 11 | 11 | `0x2C` |
| BEQ | 16 | 17 | `0x40` |
| Tích hợp | 14 | 12 | `0x38` |
| Reset và chạy lại | Dùng lại 14 word | 12 | `0x38` |

Ca branch đọc 17 lệnh vì bỏ qua hai word khi nhảy tiến và thực thi lại ba lệnh trong vòng lặp lùi. Với lệnh ở `0x38` nhảy về `0x30`, `imm24 = (0x30 - (0x38 + 8))/4 = -4`, mã máy `0AFFFFFC`.

## Coverage cần có cho lượt chạy all

- 7/7 lớp lệnh được kiểm tra. Riêng ca tích hợp cũng phải bao phủ đủ 7 lớp.
- BEQ có taken, not-taken và backward-taken.
- LD và ST có ít nhất hai địa chỉ riêng mỗi loại. Load có zero và nonzero. Store có ghi đè trong cùng ca rồi đọc lại.
- ADD/SUB có toán hạng zero, bằng và khác nhau, dấu âm/dương và hai biên 32 bit. AND/OR có toàn 0, toàn 1, xen kẽ và one-hot.
- Có ca tích hợp, reset khởi động và lượt chạy lại sau reset. Scoreboard chỉ tăng bộ đếm cho bước đã so khớp.

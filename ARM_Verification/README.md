# ARM Single-Cycle Verification

Bộ mã nguồn cho project Thiết kế số và Vi xử lý. Dùng thư mục này làm thư mục làm việc khi chạy **ModelSim Intel FPGA Starter Edition 10.5b**.

## Chạy mô phỏng

Giải nén ZIP. Trong cửa sổ **Transcript**, chuyển đến thư mục có `rtl/`, `tb/` và `sim/`, rồi chạy hai lệnh dưới đây. Đổi đường dẫn ví dụ thành đường dẫn trên máy bạn.

```tcl
cd {D:/ARM_Verification}
do sim/run.do
```

Để chạy riêng một nhóm, truyền tên sau tên file `.do`.

```tcl
do sim/run.do branch
```

| Đối số | Chương trình được chạy |
|---|---|
| `all` hoặc bỏ trống | Năm nhóm test và một lượt chạy lại chương trình tích hợp sau reset |
| `add_sub`, `logic`, `memory`, `branch`, `integration` | Nhóm được chọn |
| `reset` | Chạy chương trình tích hợp, reset CPU và chạy lại trên cùng ảnh bộ nhớ |

`run.do` biên dịch danh sách `sim/files.f`, tải `tb_top` và chạy đến khi testbench kết thúc. Các ca đi qua Scoreboard trước khi được tính vào coverage. Khi có sai lệch, xem dòng `[FAIL]` đầu tiên với tên test, PC, mã lệnh, giá trị kỳ vọng và thực tế.

Mỗi lượt chạy dùng các đường dẫn dưới đây. Khi cần giữ lịch sử, lưu bản sao của lượt chạy trước.

| Đường dẫn | Nội dung |
|---|---|
| `results/simulation.log` | Transcript, các bước đã kiểm tra và PASS/FAIL |
| `results/coverage_summary.txt` | Số lần kiểm tra từng lệnh, hai hướng nhánh, địa chỉ và mẫu toán hạng |
| `results/waveforms/arm_verification.wlf` | Dữ liệu dạng sóng do ModelSim ghi. Đóng phiên bằng `quit -sim` trước khi mở file WLF độc lập. |
| `report/` | Thư mục để bổ sung `final_report.pdf` sau demo và kiểm thử |

## Đối chiếu với giáo trình

DUT trong `rtl/` là bản triển khai tham chiếu theo **Hình 7.13 và 7.14** và các ví dụ HDL ở §7.6 của *Digital Design and Computer Architecture, ARM Edition*. Mỗi lệnh hoàn thành trong một chu kỳ. PC, thanh ghi đích, cờ hoặc Data Memory nhận cập nhật ở cạnh lên theo tín hiệu điều khiển.

| Khối | Tín hiệu và đường đi cần dò |
|---|---|
| `top`, `arm` | `PC → imem → Instr`. CPU đưa `ALUResult` ra `DataAdr`, cùng `WriteData` và `MemWrite` tới `dmem`. |
| `datapath`, `regfile` | Hai bộ cộng tạo `PCPlus4` và `PCPlus8`. Cổng `R15` của Register File lấy `PCPlus8`. Cổng ghi `WD3` lấy `Result`. `RegSrc` chọn `RA1/RA2`, còn `ALUSrc` chọn toán hạng thứ hai. |
| `extend`, `alu` | `ImmSrc=00` mở rộng imm8, `01` mở rộng imm12, `10` mở rộng dấu và dịch imm24 trái 2 bit. `ALUControl=00/01/10/11` lần lượt là cộng, trừ, AND, OR. |
| `controller` | Decoder đọc `Op`, `Funct`, `Rd`. Conditional Logic đọc `Cond` và cờ `NZCV` đã lưu để bật `RegWrite`, `MemWrite`, `PCSrc` và quyền cập nhật cờ. |
| Ghi về và PC | `MemtoReg=1` chọn `ReadData` cho `LDR`. `MemtoReg=0` chọn `ALUResult`. `PCSrc=0` chọn `PCPlus4`, `PCSrc=1` chọn `Result`. |

Tên trong đề **OR, LD, ST** dùng mã A32 của **ORR, LDR, STR**. DP nhận trực tiếp toán hạng thanh ghi hoặc imm8 mở rộng bằng 0 (`rotate_imm = 0`). Load/store dùng word, địa chỉ dạng `[Rn, #imm12]` với offset dương hoặc bằng 0. Instruction Memory và Data Memory có 64 word mỗi khối. Một word ở địa chỉ byte `0x40` tương ứng phần tử 16 trong mảng.

Trong ca `BEQ`, `SUBS` đặt `Z` bằng phép trừ và `BEQ label` đọc cờ đã lưu. Chẳng hạn tại `PC = 0x10`, word `0A000001` có `Cond=EQ` và `imm24=1`. ALU tạo địa chỉ đích `0x10 + 8 + 4 = 0x1C`. `Z=1` chọn đích nhánh và `Z=0` chọn `0x14`. `SUBS` là dạng `S=1` của SUB.

Reset đưa PC và NZCV về 0. R0 đến R14 và Data Memory giữ trạng thái trong lúc reset. Driver nạp ảnh bộ nhớ mới khi chuyển nhóm test. Mỗi chương trình tự chuẩn bị thanh ghi nguồn, bắt đầu bằng `SUB R0, R15, R15` để tạo 0. Lượt `reset_replay` dùng cùng ảnh lệnh và Data Memory sau lượt tích hợp.

## Đọc và sửa testbench

- `tb/driver.sv` phát clock 10 ns, điều khiển reset, đọc `program.hex` và `data.hex`.
- `tb/monitor.sv` lấy mẫu PC, Instr, đường ALU, writeback và quyền ghi ở cạnh lên trước khi trạng thái đổi.
- `tb/reference_model.sv` tự giữ PC, cờ, thanh ghi, Instruction Memory và Data Memory. Nó tự đọc mã lệnh từ ảnh do Driver cung cấp và tính trạng thái kỳ vọng.
- `tb/scoreboard.sv` đối chiếu mẫu vừa thu cùng trạng thái sau cạnh lên, ghi PASS/FAIL và thống kê coverage.
- `tb/tb_top.sv` kết nối DUT với các khối kiểm chứng. Truy cập phân cấp để nạp bộ nhớ và quan sát RF/PC được đặt ở đây. Khi dùng RTL giảng viên cấp, đối chiếu bảng mã lệnh, reset và ánh xạ cổng/đường dẫn tại file này.

Mỗi thư mục test có `program.s` và `program.hex` tương ứng, kèm `data.hex` chứa 64 word ban đầu của Data Memory. Các file hex là từng word 32 bit, một word 8 chữ số mỗi dòng. Nếu sửa chương trình, cập nhật hex và số word/số bước kỳ vọng ở lời gọi `run_case` tương ứng. Nhãn `done` ở cuối chương trình là địa chỉ dừng mà testbench quan sát.

Xem [TEST_PLAN.md](TEST_PLAN.md) để biết PC, lệnh, kết quả kỳ vọng và tín hiệu cần dùng cho từng nhóm.

## Tài liệu đã đối chiếu

- Đề `Project_Cuoi_Ky_Thiet_Ke_So_Va_Vi_Xu_Ly_ARM(1).pdf`. Phần II và III cho tập lệnh và ca tối thiểu. Phần IV và V cho môi trường kiểm chứng, cách chạy và sản phẩm bàn giao.
- Sarah L. Harris và David Money Harris, *Digital Design and Computer Architecture: ARM Edition*. Chương 5 cho ALU, thanh ghi và bộ nhớ. Chương 6 cho A32 và điều kiện. §7.3, Hình 7.13–7.14, Bảng 7.1–7.3 và HDL Example 7.1–7.15 cho datapath, control và cấu trúc mô phỏng.
- `DDCAarm_Ch5.pptx` cho `ALUControl` và `NZCV`. `DDCAarm_Ch6.pptx` và các slide *instruction set*, *data processing and conditional and branch executions*, *instruction encoding*, *address modes* cho mã A32. `DDCAarm_Ch7.pptx`, phần *Single-Cycle Processor*, cho `PCPlus8`, `RegSrc`, `ImmSrc`, `MemtoReg` và Conditional Logic.
- *ModelSim Command Reference Manual*, v10.5b, mục `do`, `vsim` và ghi waveform. [Tài liệu lệnh ModelSim](https://faculty-web.msoe.edu/johnsontimoj/Common/FILES/modelsim_ref.pdf)

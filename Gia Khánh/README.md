# Gia Khánh — Kiểm chứng BEQ và PC

| File | Vai trò |
|---|---|
| `project/branch_pc.sv` | Giải mã BEQ A32, tính địa chỉ nhảy và cập nhật PC. |
| `testbench/tb_branch_pc.sv` | Tạo clock/reset, cấp mã lệnh và cờ Z, tính PC kỳ vọng độc lập, kiểm tra và đếm hai kết quả nhánh. |
| `testbench/scoreboard.sv` | So sánh giá trị 32 bit, báo sai lệch và tổng kết PASS/FAIL. Có thể dùng chung để kiểm tra thanh ghi và bộ nhớ khi tích hợp. |
| `run.do` | Biên dịch, chạy mô phỏng và lưu waveform. |

## Chạy trên ModelSim 10.5b

Mở ModelSim ở thư mục `Gia Khánh` rồi nhập `do run.do` trong Transcript. Để lưu log khi chạy từ terminal tại cùng thư mục:

```text
vsim -c -l branch_results.log -do "do run.do; quit -f"
```

Transcript in PC, cờ Z, quyết định nhảy, PC kỳ vọng và tổng số lần BEQ taken/not-taken. File `branch_wave.wlf` lưu waveform.

Mô phỏng khối trên Icarus Verilog 13.0 cho kết quả `PASS: 53 checks` với 3 lần taken và 1 lần not-taken.

| Ca | Kết quả kỳ vọng |
|---|---|
| Reset lúc đầu và giữa bài test | `PC = 0x100`, sau đó chạy tiếp được. |
| PC tuần tự | `0x100 → 0x104`. |
| BEQ với hai toán hạng bằng nhau | `0x104 → 0x110`. |
| Cùng BEQ với hai toán hạng khác nhau | `0x104 → 0x108`. |
| BEQ lùi và BEQ với offset bằng 0 | `0x110 → 0x108` và `0x108 → 0x110`. |
| Mã BNE đưa vào khối BEQ | `is_beq = 0` và PC đi tiếp. |

## Nối vào CPU của nhóm

Khối này giả định mã lệnh **ARM A32** và reset đồng bộ mức cao. DUT nhận `instr` từ instruction memory và `zero_flag` từ cờ Z đã lưu của CPU. Trong testbench, phép trừ giả lập nguồn cờ Z, còn kết quả kỳ vọng được tính từ phép so sánh hai toán hạng và địa chỉ nhãn đã định trước.

Khi có RTL giảng viên giao, đối chiếu mã hóa nhánh, nguồn điều kiện và reset. Nếu CPU đã có thanh ghi PC, dùng riêng module tổ hợp `beq_next_pc`: nối `pc` từ thanh ghi hiện có và đưa `pc_next` vào đường chọn PC của CPU. Coverage ở đây dành cho khối BEQ; tích hợp Monitor và Reference Model của nhóm để tổng hợp coverage đủ 7 lệnh.

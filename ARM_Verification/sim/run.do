# ModelSim Intel FPGA Starter Edition 10.5b
# do sim/run.do
# do sim/run.do branch

if {![file isfile sim/files.f] && [file isfile ../sim/files.f]} {
    cd ..
}
if {![file isfile sim/files.f]} {
    error "Change to the ARM_Verification directory and run: do sim/run.do"
}

set arm_test all
if {[info exists 1] && [set 1] ne ""} {
    set arm_test [set 1]
}
if {[lsearch -exact {all add_sub logic memory branch integration reset} $arm_test] < 0} {
    error "Unknown test '$arm_test'. Use all, add_sub, logic, memory, branch, integration, or reset."
}

catch {quit -sim}
file mkdir results/waveforms
transcript file results/simulation.log
transcript on

if {![file isdirectory work]} {
    vlib work
}
vlog -sv -work work -f sim/files.f
vsim -t 1ps -voptargs=+acc -onfinish stop -wlf results/waveforms/arm_verification.wlf work.tb_top +TEST=$arm_test
log -r sim:/tb_top/*

# Wave setup is optional when ModelSim runs in console mode.
if {![catch {view wave}]} {
    add wave sim:/tb_top/clk sim:/tb_top/reset
    add wave -radix hexadecimal sim:/tb_top/dut/PC sim:/tb_top/dut/Instr
    add wave -radix hexadecimal sim:/tb_top/dut/arm_proc/dp/PCPlus4
    add wave -radix hexadecimal sim:/tb_top/dut/arm_proc/dp/PCPlus8
    add wave -radix hexadecimal sim:/tb_top/dut/arm_proc/dp/PCNext
    add wave sim:/tb_top/dut/arm_proc/PCSrc sim:/tb_top/dut/arm_proc/Flags
    add wave sim:/tb_top/dut/arm_proc/RegWrite sim:/tb_top/dut/arm_proc/MemtoReg
    add wave -radix hexadecimal sim:/tb_top/dut/arm_proc/dp/SrcA
    add wave -radix hexadecimal sim:/tb_top/dut/arm_proc/dp/SrcB
    add wave -radix hexadecimal sim:/tb_top/dut/arm_proc/dp/Result
    add wave sim:/tb_top/MemWrite
    add wave -radix hexadecimal sim:/tb_top/DataAdr sim:/tb_top/WriteData
    add wave -radix hexadecimal sim:/tb_top/dut/ReadData
    add wave sim:/tb_top/test_done sim:/tb_top/test_passed
}

run -all

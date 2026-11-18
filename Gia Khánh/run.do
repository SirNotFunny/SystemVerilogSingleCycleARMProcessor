if {![file isdirectory work]} {
    vlib work
}

vlog -sv project/branch_pc.sv testbench/scoreboard.sv testbench/tb_branch_pc.sv
vsim -voptargs=+acc -onfinish stop -wlf branch_wave.wlf work.tb_branch_pc
log -r /*
run -all

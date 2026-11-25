`timescale 1ns/1ps

module tb_top;
    import verification_pkg::*;

    logic clk, reset, MemWrite;
    logic [31:0] WriteData, DataAdr;
    bit test_done = 0, test_passed = 0;
    string selection;

    top dut (
        .clk(clk), .reset(reset), .WriteData(WriteData),
        .DataAdr(DataAdr), .MemWrite(MemWrite)
    );
    driver stim (.clk(clk), .reset(reset));
    reference_model refm ();
    scoreboard sb ();
    monitor mon (
        .clk(clk), .reset(reset), .pc(dut.PC), .instr(dut.Instr),
        .pc_next(dut.arm_proc.dp.PCNext), .flags(dut.arm_proc.Flags),
        .src_a(dut.arm_proc.dp.SrcA), .src_b(dut.arm_proc.dp.SrcB),
        .alu_result(DataAdr), .result(dut.arm_proc.dp.Result),
        .read_data(dut.ReadData), .write_data(WriteData),
        .pc_src(dut.arm_proc.PCSrc), .reg_write(dut.arm_proc.RegWrite),
        .mem_to_reg(dut.arm_proc.MemtoReg), .mem_write(MemWrite)
    );

    task automatic compare_state;
        integer i;

        sb.check_word("PC after edge", refm.pc, dut.PC);
        sb.check_word("NZCV after edge", {28'd0, refm.flags}, {28'd0, dut.arm_proc.Flags});
        for (i = 0; i < GPR_COUNT; i = i + 1)
            sb.check_word($sformatf("R%0d", i), refm.registers[i], dut.arm_proc.dp.rf.RF[i]);
        for (i = 0; i < MEMORY_WORDS; i = i + 1)
            sb.check_word($sformatf("DMEM[byte %02h]", i * 4),
                          refm.data_memory[i], dut.dmem_i.RAM[i]);
    endtask

    task automatic run_case (
        input string name, directory,
        input integer word_count, expected_steps,
        input logic [6:0] required_ops,
        input bit load_image
    );
        integer i, steps, errors_before_step, word_index;
        logic [31:0] stop_pc;
        logic [63:0] writes_in_case;
        cycle_sample_t actual;
        cycle_sample_t wanted;

        if (sb.errors != 0)
            disable run_case;  // Dung sau sai lech dau tien de giu ngu canh debug.

        sb.begin_case(name);
        stim.assert_reset();
        refm.reset_cpu();
        if (load_image) begin
            stim.load_images(directory, word_count);
            // Hai bo nho nhan cung stimulus. Model tu theo doi PC va cac lan ghi.
            for (i = 0; i < MEMORY_WORDS; i = i + 1) begin
                dut.imem_i.RAM[i] = stim.program_words[i];
                dut.dmem_i.RAM[i] = stim.data_words[i];
                refm.seed_word(i, stim.program_words[i], stim.data_words[i]);
            end
        end

        stim.hold_reset();
        compare_state();
        sb.check_word("RegWrite during reset", 32'd0, {31'd0, dut.arm_proc.RegWrite});
        sb.check_word("MemWrite during reset", 32'd0, {31'd0, MemWrite});
        if (sb.errors == 0)
            sb.checked_resets = sb.checked_resets + 1;

        steps = 0;
        writes_in_case = '0;
        stop_pc = $unsigned(word_count) << 2;
        if (sb.errors == 0) begin
            stim.release_reset();
            while (refm.pc != stop_pc && steps < expected_steps && sb.errors == 0) begin
                @(posedge clk);
                refm.step();
                #1;
                actual = mon.sampled;
                wanted = refm.prediction;
                errors_before_step = sb.errors;
                sb.compare_cycle(wanted, actual);
                compare_state();
                if (sb.errors == errors_before_step) begin
                    sb.record_checked_step(actual, refm.kind);
                    if (actual.mem_write) begin
                        word_index = int'(actual.alu_result >> 2);
                        if (writes_in_case[word_index])
                            sb.overwrote_word = 1'b1;
                        writes_in_case[word_index] = 1'b1;
                    end
                end
                steps = steps + 1;
            end
        end
        if (sb.errors == 0) begin
            sb.check_word("Stop PC", stop_pc, refm.pc);
            sb.check_word("Instruction count", $unsigned(expected_steps), $unsigned(steps));
        end
        sb.finish_case(required_ops);
    endtask

    initial begin
        if (!$value$plusargs("TEST=%s", selection))
            selection = "all";

        if (selection != "all" && selection != "add_sub" && selection != "logic" &&
            selection != "memory" && selection != "branch" &&
            selection != "integration" && selection != "reset")
            $fatal(1, "Unknown TEST=%s", selection);

        if (selection == "all" || selection == "add_sub")
            run_case("add_sub", "tests/test_add_sub", 15, 15, 7'h03, 1'b1);
        if (selection == "all" || selection == "logic")
            run_case("logic", "tests/test_logic", 17, 17, 7'h0c, 1'b1);
        if (selection == "all" || selection == "memory")
            run_case("memory", "tests/test_memory", 11, 11, 7'h30, 1'b1);
        if (selection == "all" || selection == "branch")
            run_case("branch", "tests/test_branch", 16, 17, 7'h40, 1'b1);
        if (selection == "all" || selection == "integration" || selection == "reset")
            run_case("integration", "tests/test_integration", 14, 12, 7'h7f, 1'b1);
        if (selection == "all" || selection == "reset")
            run_case("reset_replay", "tests/test_integration", 14, 12, 7'h7f, 1'b0);

        if (selection == "all" && sb.errors == 0)
            sb.validate_all_coverage();
        sb.report(selection);
        test_passed = (sb.errors == 0);
        test_done = 1'b1;
        if (test_passed)
            $display("\nOVERALL PASS, checked=%0d cases=%0d", sb.checked_steps, sb.passed_cases);
        else
            $display("\nOVERALL FAIL, mismatches=%0d", sb.errors);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Testbench watchdog: simulation did not finish");
    end
endmodule

`timescale 1ns/1ps

module scoreboard;
    import verification_pkg::*;

    integer errors = 0;
    integer checked_steps = 0;
    integer passed_cases = 0;
    integer checked_resets = 0;
    integer reset_replays = 0;
    integer integrations = 0;
    integer hits [0:6];
    integer beq_taken = 0, beq_not_taken = 0, beq_backward_taken = 0;
    integer load_addresses = 0, store_addresses = 0;
    logic [63:0] load_words = '0, store_words = '0;
    bit read_zero = 0, read_nonzero = 0, overwrote_word = 0;
    bit arith_zero = 0, arith_equal = 0, arith_unequal = 0;
    bit arith_positive = 0, arith_negative = 0, arith_min = 0, arith_max = 0;
    bit logic_zero = 0, logic_ones = 0, logic_alternating = 0, logic_single_bit = 0;

    string case_name = "setup";
    logic [31:0] context_pc = 32'd0, context_instr = 32'd0;
    integer case_step = 0, errors_at_case_start = 0;
    logic [6:0] case_mask = '0;

    initial begin
        foreach (hits[i])
            hits[i] = 0;
    end

    task automatic begin_case(input string name);
        case_name = name;
        case_step = 0;
        context_pc = 32'd0;
        context_instr = 32'd0;
        case_mask = '0;
        errors_at_case_start = errors;
        $display("\n[CASE] %s", case_name);
    endtask

    task automatic check_word (
        input string field_name,
        input logic [31:0] wanted, actual
    );
        if (actual !== wanted) begin
            errors = errors + 1;
            $display("[FAIL] %s step=%0d PC=%08h Instr=%08h %s expected=%08h actual=%08h",
                     case_name, case_step, context_pc, context_instr, field_name, wanted, actual);
        end
    endtask

    task automatic check_requirement(input logic met, input string description);
        if (met !== 1'b1) begin
            errors = errors + 1;
            $display("[FAIL] %s: %s", case_name, description);
        end
    endtask

    task automatic compare_cycle(input cycle_sample_t wanted, actual);
        case_step = case_step + 1;
        context_pc = wanted.pc;
        context_instr = wanted.instr;
        $display("[STEP] %s/%0d PC=%08h Instr=%08h NZCV=%04b ALU=%08h PCNext=%08h PCSrc=%b RegW=%b MemR=%b MemW=%b",
                 case_name, case_step, actual.pc, actual.instr, actual.flags,
                 actual.alu_result, actual.pc_next, actual.pc_src,
                 actual.reg_write, actual.mem_read, actual.mem_write);

        check_word("PC before edge", wanted.pc, actual.pc);
        check_word("Instr", wanted.instr, actual.instr);
        check_word("PCNext before edge", wanted.pc_next, actual.pc_next);
        check_word("NZCV before edge", {28'd0, wanted.flags}, {28'd0, actual.flags});
        check_word("SrcA", wanted.src_a, actual.src_a);
        check_word("SrcB", wanted.src_b, actual.src_b);
        check_word("ALUResult", wanted.alu_result, actual.alu_result);
        check_word("PCSrc", {31'd0, wanted.pc_src}, {31'd0, actual.pc_src});
        check_word("RegWrite", {31'd0, wanted.reg_write}, {31'd0, actual.reg_write});
        check_word("MemWrite", {31'd0, wanted.mem_write}, {31'd0, actual.mem_write});
        check_word("LDR enable", {31'd0, wanted.mem_read}, {31'd0, actual.mem_read});
        if (wanted.reg_write) begin
            check_word("Rd", {28'd0, wanted.rd}, {28'd0, actual.rd});
            check_word("Result/WD3", wanted.result, actual.result);
        end
        if (wanted.mem_read)
            check_word("ReadData", wanted.read_data, actual.read_data);
        if (wanted.mem_write)
            check_word("WriteData", wanted.write_data, actual.write_data);
    endtask

    function automatic bit single_bit(input logic [31:0] value);
        return (value != 32'd0) && ((value & (value - 32'd1)) == 32'd0);
    endfunction

    task automatic record_checked_step (
        input cycle_sample_t actual,
        input instruction_kind_t kind
    );
        integer word_index, op_index;
        logic [31:0] a, b;

        checked_steps = checked_steps + 1;
        // BEQ duoc tinh cho ca taken va not-taken. Lenh khac can commit that.
        if (kind == K_BEQ || actual.reg_write || actual.mem_write) begin
            op_index = int'(kind);
            hits[op_index] = hits[op_index] + 1;
            case_mask[op_index] = 1'b1;
        end
        if (kind == K_BEQ) begin
            if (actual.pc_src) begin
                beq_taken = beq_taken + 1;
                if (actual.pc_next < actual.pc)
                    beq_backward_taken = beq_backward_taken + 1;
            end else begin
                beq_not_taken = beq_not_taken + 1;
            end
        end

        word_index = int'(actual.alu_result >> 2);
        if (actual.mem_read) begin
            if (!load_words[word_index])
                load_addresses = load_addresses + 1;
            load_words[word_index] = 1'b1;
            read_zero = read_zero | (actual.read_data == 32'd0);
            read_nonzero = read_nonzero | (actual.read_data != 32'd0);
        end
        if (actual.mem_write) begin
            if (!store_words[word_index])
                store_addresses = store_addresses + 1;
            store_words[word_index] = 1'b1;
        end

        a = actual.src_a;
        b = actual.src_b;
        if (actual.reg_write && (kind == K_ADD || kind == K_SUB)) begin
            arith_zero     = arith_zero     | (a == 32'd0) | (b == 32'd0);
            arith_equal    = arith_equal    | (a == b);
            arith_unequal  = arith_unequal  | (a != b);
            arith_positive = arith_positive | ($signed(a) > 0) | ($signed(b) > 0);
            arith_negative = arith_negative | a[31] | b[31];
            arith_min = arith_min | (a == 32'h80000000) | (b == 32'h80000000);
            arith_max = arith_max | (a == 32'h7fffffff) | (b == 32'h7fffffff);
        end
        if (actual.reg_write && (kind == K_AND || kind == K_ORR)) begin
            logic_zero = logic_zero | (a == 32'd0) | (b == 32'd0);
            logic_ones = logic_ones | (a == 32'hffffffff) | (b == 32'hffffffff);
            logic_alternating = logic_alternating |
                ((a == 32'haaaaaaaa) && (b == 32'h55555555)) |
                ((a == 32'h55555555) && (b == 32'haaaaaaaa));
            logic_single_bit = logic_single_bit | single_bit(a) | single_bit(b);
        end
    endtask

    task automatic finish_case(input logic [6:0] required_ops);
        if (errors == errors_at_case_start)
            check_requirement((case_mask & required_ops) == required_ops,
                              "The case did not exercise all its required operations");
        if (errors == errors_at_case_start) begin
            passed_cases = passed_cases + 1;
            if (case_name == "integration")
                integrations = integrations + 1;
            if (case_name == "reset_replay")
                reset_replays = reset_replays + 1;
            $display("[PASS] %s, %0d checked instructions", case_name, case_step);
        end else begin
            $display("[FAIL] %s", case_name);
        end
    endtask

    task automatic validate_all_coverage;
        case_name = "coverage";
        check_requirement(passed_cases == 6, "All six planned case runs must pass");
        check_requirement(beq_taken > 0 && beq_not_taken > 0 && beq_backward_taken > 0,
                          "BEQ needs taken, not-taken and backward-taken cases");
        check_requirement(load_addresses >= 2 && store_addresses >= 2 &&
                          read_zero && read_nonzero && overwrote_word,
                          "LD/ST address, data and overwrite coverage is incomplete");
        check_requirement(arith_zero && arith_equal && arith_unequal && arith_positive &&
                          arith_negative && arith_min && arith_max,
                          "ADD/SUB operand coverage is incomplete");
        check_requirement(logic_zero && logic_ones && logic_alternating && logic_single_bit,
                          "AND/ORR data-pattern coverage is incomplete");
        check_requirement(integrations == 1 && reset_replays == 1 && checked_resets == 6,
                          "Integration and reset replay coverage is incomplete");
    endtask

    task automatic report(input string selection);
        integer file_handle, i, covered_ops;

        file_handle = $fopen("results/coverage_summary.txt", "w");
        if (file_handle == 0) begin
            check_requirement(1'b0, "Cannot create results/coverage_summary.txt");
        end else begin
            covered_ops = 0;
            for (i = 0; i < 7; i = i + 1)
                if (hits[i] > 0)
                    covered_ops = covered_ops + 1;
            $fdisplay(file_handle, "Selection: %s", selection);
            $fdisplay(file_handle, "Checked instruction classes: %0d/7", covered_ops);
            $fdisplay(file_handle, "ADD=%0d SUB=%0d AND=%0d ORR=%0d LDR=%0d STR=%0d BEQ=%0d",
                      hits[0], hits[1], hits[2], hits[3], hits[4], hits[5], hits[6]);
            $fdisplay(file_handle, "BEQ taken=%0d not_taken=%0d backward_taken=%0d",
                      beq_taken, beq_not_taken, beq_backward_taken);
            $fdisplay(file_handle, "LDR unique=%0d word_mask=%016h zero=%0b nonzero=%0b",
                      load_addresses, load_words, read_zero, read_nonzero);
            $fdisplay(file_handle, "STR unique=%0d word_mask=%016h overwrite=%0b",
                      store_addresses, store_words, overwrote_word);
            $fdisplay(file_handle, "Arithmetic zero=%0b equal=%0b unequal=%0b positive=%0b negative=%0b min=%0b max=%0b",
                      arith_zero, arith_equal, arith_unequal, arith_positive,
                      arith_negative, arith_min, arith_max);
            $fdisplay(file_handle, "Logic zero=%0b ones=%0b alternating=%0b one_hot=%0b",
                      logic_zero, logic_ones, logic_alternating, logic_single_bit);
            $fdisplay(file_handle, "Checked steps=%0d passed cases=%0d resets=%0d integration=%0d replay=%0d errors=%0d",
                      checked_steps, passed_cases, checked_resets, integrations, reset_replays, errors);
            $fdisplay(file_handle, "%s", (errors == 0) ? "OVERALL PASS" : "OVERALL FAIL");
            $fclose(file_handle);
        end
    endtask
endmodule

`timescale 1ns/1ps

// Interpreter ISA. Chi nhan anh bo nho ban dau tu driver, tu fetch theo PC rieng.
module reference_model;
    import verification_pkg::*;

    localparam logic [31:0] MEMORY_BYTES = MEMORY_WORDS * 4;

    logic [31:0] pc;
    logic [3:0]  flags;
    logic [31:0] registers   [0:GPR_COUNT-1];
    logic [31:0] instruction_memory [0:MEMORY_WORDS-1];
    logic [31:0] data_memory        [0:MEMORY_WORDS-1];
    cycle_sample_t prediction;
    instruction_kind_t kind;

    task automatic reset_cpu;
        // Theo hop dong RTL: reset PC/NZCV, giu R0..R14 va Data Memory.
        pc = 32'd0;
        flags = 4'b0000;
    endtask

    task automatic seed_word (
        input integer index,
        input logic [31:0] program_word, data_word
    );
        instruction_memory[index] = program_word;
        data_memory[index] = data_word;
    endtask

    function automatic logic [31:0] read_register(input logic [3:0] number);
        if (number == 4'd15)
            return pc + 32'd8;
        return registers[number];
    endfunction

    function automatic logic condition_holds(input logic [3:0] cond);
        logic n, z, c, v;
        {n, z, c, v} = flags;
        case (cond)
            4'd0:  return z;                // EQ
            4'd1:  return !z;               // NE
            4'd2:  return c;
            4'd3:  return !c;
            4'd4:  return n;
            4'd5:  return !n;
            4'd6:  return v;
            4'd7:  return !v;
            4'd8:  return c && !z;
            4'd9:  return !c || z;
            4'd10: return n == v;
            4'd11: return n != v;
            4'd12: return !z && (n == v);
            4'd13: return z || (n != v);
            4'd14: return 1'b1;             // AL
            default: return 1'b0;
        endcase
    endfunction

    function automatic logic [1:0] carry_overflow (
        input instruction_kind_t operation,
        input logic [31:0] lhs, rhs
    );
        logic signed [63:0] signed_lhs, signed_rhs, signed_total;
        logic [32:0] unsigned_total;
        logic carry, overflow;

        // Dung mien gia tri so hoc de suy ra V, doc lap voi cong thuc bit cua DUT.
        signed_lhs = $signed({{32{lhs[31]}}, lhs});
        signed_rhs = $signed({{32{rhs[31]}}, rhs});
        if (operation == K_ADD) begin
            signed_total = signed_lhs + signed_rhs;
            unsigned_total = {1'b0, lhs} + {1'b0, rhs};
            carry = unsigned_total > 33'h0ffffffff;
        end else begin
            signed_total = signed_lhs - signed_rhs;
            carry = (lhs >= rhs);
        end
        overflow = (signed_total < -64'sd2147483648) ||
                   (signed_total > 64'sd2147483647);
        return {carry, overflow};
    endfunction

    task automatic step;
        logic [31:0] instruction, lhs, rhs, value;
        logic [3:0] dest;
        logic execute_instruction;
        logic signed [31:0] displacement_words;
        integer index;

        if ((^pc) === 1'bx || pc[1:0] != 2'b00 || pc >= MEMORY_BYTES)
            $fatal(1, "Reference model: invalid PC=%08h", pc);
        instruction = instruction_memory[pc[7:2]];
        if ((^instruction) === 1'bx)
            $fatal(1, "Reference model: no instruction at PC=%08h", pc);

        prediction = '0;
        prediction.pc = pc;
        prediction.instr = instruction;
        prediction.pc_next = pc + 32'd4;
        prediction.flags = flags;
        dest = instruction[15:12];
        prediction.rd = dest;
        execute_instruction = condition_holds(instruction[31:28]);
        kind = K_INVALID;
        index = 0;

        case (instruction[27:26])
            2'b00: begin
                lhs = read_register(instruction[19:16]);
                if (instruction[25]) begin
                    if (instruction[11:8] != 4'd0)
                        $fatal(1, "DP immediate rotation outside textbook subset at PC=%08h", pc);
                    rhs = {24'd0, instruction[7:0]};
                end else begin
                    if (instruction[11:4] != 8'd0)
                        $fatal(1, "DP register shift outside textbook subset at PC=%08h", pc);
                    rhs = read_register(instruction[3:0]);
                end

                case (instruction[24:21])
                    4'h4: begin kind = K_ADD; value = lhs + rhs; end
                    4'h2: begin kind = K_SUB; value = lhs - rhs; end
                    4'h0: begin kind = K_AND; value = lhs & rhs; end
                    4'hc: begin kind = K_ORR; value = lhs | rhs; end
                    default: $fatal(1, "Unsupported DP instruction %08h at PC=%08h", instruction, pc);
                endcase
                prediction.result = value;
                prediction.reg_write = execute_instruction;
                if (execute_instruction && instruction[20]) begin
                    flags[3] = value[31];
                    flags[2] = (value == 32'd0);
                    if (kind == K_ADD || kind == K_SUB)
                        flags[1:0] = carry_overflow(kind, lhs, rhs);
                end
            end
            2'b01: begin
                if (instruction[25:21] != 5'b01100)
                    $fatal(1, "Unsupported LDR/STR addressing at PC=%08h", pc);
                lhs = read_register(instruction[19:16]);
                rhs = {20'd0, instruction[11:0]};
                value = lhs + rhs;
                if ((^value) === 1'bx || value[1:0] != 2'b00 || value >= MEMORY_BYTES)
                    $fatal(1, "Reference model: invalid data address %08h at PC=%08h", value, pc);
                index = int'(value >> 2);

                if (instruction[20]) begin
                    kind = K_LDR;
                    prediction.read_data = data_memory[index];
                    prediction.result = prediction.read_data;
                    prediction.mem_read = execute_instruction;
                    prediction.reg_write = execute_instruction;
                end else begin
                    kind = K_STR;
                    prediction.write_data = read_register(dest);
                    prediction.mem_write = execute_instruction;
                end
            end
            2'b10: begin
                if (instruction[27:24] != 4'b1010 || instruction[31:28] != 4'b0000)
                    $fatal(1, "Branch outside BEQ test scope at PC=%08h", pc);
                kind = K_BEQ;
                displacement_words = $signed({{8{instruction[23]}}, instruction[23:0]});
                lhs = pc + 32'd8;
                rhs = $unsigned(displacement_words * 32'sd4);
                value = lhs + rhs;
                prediction.pc_src = execute_instruction;
                if (execute_instruction)
                    prediction.pc_next = value;
            end
            default: $fatal(1, "Unsupported instruction %08h at PC=%08h", instruction, pc);
        endcase

        if ((^{lhs, rhs}) === 1'bx ||
            (prediction.mem_write && ((^prediction.write_data) === 1'bx)) ||
            (prediction.reg_write && ((^prediction.result) === 1'bx)))
            $fatal(1, "Test used uninitialized operand at PC=%08h, Instr=%08h", pc, instruction);

        prediction.src_a = lhs;
        prediction.src_b = rhs;
        prediction.alu_result = value;

        if (prediction.reg_write) begin
            if (dest == 4'd15) begin
                prediction.pc_src = 1'b1;
                prediction.pc_next = prediction.result;
            end else begin
                registers[dest] = prediction.result;
            end
        end
        if (prediction.mem_write)
            data_memory[index] = prediction.write_data;
        pc = prediction.pc_next;
    endtask
endmodule

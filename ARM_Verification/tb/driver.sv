`timescale 1ns/1ps

module driver (
    output logic clk, reset
);
    import verification_pkg::*;

    logic [31:0] program_words [0:MEMORY_WORDS-1];
    logic [31:0] data_words    [0:MEMORY_WORDS-1];

    initial begin
        clk = 1'b0;
        reset = 1'b1;
    end
    always #5 clk = ~clk;

    task automatic assert_reset;
        @(negedge clk);
        reset = 1'b1;
    endtask

    task automatic hold_reset;
        repeat (2) @(posedge clk);
        #1;
    endtask

    task automatic release_reset;
        @(negedge clk);
        reset = 1'b0;
    endtask

    task automatic load_images(input string directory, input integer word_count);
        string program_path, data_path;
        integer program_file, data_file, i;

        if (word_count < 1 || word_count >= MEMORY_WORDS)
            $fatal(1, "Invalid program length in %s: %0d", directory, word_count);

        program_path = {directory, "/program.hex"};
        data_path = {directory, "/data.hex"};
        program_file = $fopen(program_path, "r");
        data_file = $fopen(data_path, "r");
        if (program_file == 0 || data_file == 0)
            $fatal(1, "Cannot open %s or %s. Run from the project root.", program_path, data_path);

        // Moi token hex dai dien mot word 32 bit. Doc dung so word cua fixture.
        foreach (program_words[i])
            program_words[i] = 32'hxxxxxxxx;
        for (i = 0; i < word_count; i = i + 1) begin
            if ($fscanf(program_file, "%h", program_words[i]) != 1 ||
                (^program_words[i]) === 1'bx)
                $fatal(1, "Invalid instruction word %0d in %s", i, program_path);
        end
        for (i = 0; i < MEMORY_WORDS; i = i + 1) begin
            if ($fscanf(data_file, "%h", data_words[i]) != 1 ||
                (^data_words[i]) === 1'bx)
                $fatal(1, "Invalid data word %0d in %s", i, data_path);
        end
        $fclose(program_file);
        $fclose(data_file);
    endtask
endmodule

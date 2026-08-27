// riscv_tb.sv: Тестбенч
// Лог, dump регистров, маркер конца программы

`timescale 1ns/1ps

import riscv_pkg::*;

module riscv_tb;

    // Log
    // 0: только старт/конец, 1: файл, 2: файл и консоль
`ifdef LOG_LEVEL
    localparam int LOG_LEVEL = `LOG_LEVEL;
`else
    localparam int LOG_LEVEL = 1;
`endif

`ifdef LOG_FILENAME
    localparam LOG_FILENAME_VAL = `LOG_FILENAME;
`else
    localparam LOG_FILENAME_VAL = "sim_log.log";
`endif

`ifdef LOG_TIME
    localparam LOG_TIME_VAL = `LOG_TIME;
`else
    localparam LOG_TIME_VAL = "unknown";
`endif

`ifdef TEST_TYPE
    localparam TEST_TYPE_VAL = `TEST_TYPE;
`else
    localparam TEST_TYPE_VAL = "unknown";
`endif

`ifdef TEST_FILE
    localparam TEST_FILE_VAL = `TEST_FILE;
`else
    localparam TEST_FILE_VAL = "unknown";
`endif

    string core_mode_str;
    int    log_file;

    logic clk;
    logic rst_n;

    // Циклы
    int cycle_count;
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
        end
        else begin
            cycle_count <= 0;
        end
    end

    // Маркер конца
    always @(posedge clk) begin
        if (rst_n && uut.data_mem.RAM[3] == 32'h600DC0DE) begin
            $display("\n=============================================");
            $display("--- PROGRAM DONE MARKER DETECTED ---");
            $display("Execution finished successfully at t = %0t", $time);
            $display("Total Cycles: %0d", cycle_count);
            $display("Result CRC List:  %h", uut.data_mem.RAM[0]);
            $display("Result CRC Mat:   %h", uut.data_mem.RAM[1]);
            $display("Result CRC State: %h", uut.data_mem.RAM[2]);
            $display("=============================================");

            if (LOG_LEVEL >= 1 && log_file != 0) begin
                $fdisplay(log_file, "\n=============================================");
                $fdisplay(log_file, "--- PROGRAM DONE MARKER DETECTED ---");
                $fdisplay(log_file, "Execution finished successfully at t = %0t", $time);
                $fdisplay(log_file, "Total Cycles: %0d", cycle_count);
                $fdisplay(log_file, "Result CRC List:  %h", uut.data_mem.RAM[0]);
                $fdisplay(log_file, "Result CRC Mat:   %h", uut.data_mem.RAM[1]);
                $fdisplay(log_file, "Result CRC State: %h", uut.data_mem.RAM[2]);
                $fdisplay(log_file, "=============================================");

                print_final_states_to_file();
                $fclose(log_file);
            end

            if (LOG_LEVEL == 2) begin
                print_final_states_to_console();
            end

            $finish;
        end
    end

    // Top
    riscv_top uut (
        .clk  (clk),
        .rst_n(rst_n)
    );

    // Clock
    always begin
        #10 clk = ~clk;
    end

    // Симуляция
    initial begin
        core_mode_str = "In-Order (5-stage)";

        if (LOG_LEVEL >= 1) begin
            log_file = $fopen(LOG_FILENAME_VAL, "w");
            if (log_file == 0) begin
                $display("Error: Could not open log file %s for writing.", LOG_FILENAME_VAL);
            end
            else begin
                $fdisplay(log_file, "==================================================");
                $fdisplay(log_file, "RISC-V PROCESSOR SIMULATION LOG");
                $fdisplay(log_file, "==================================================");
                $fdisplay(log_file, "Timestamp: %s", LOG_TIME_VAL);
                $fdisplay(log_file, "Test Type: %s", TEST_TYPE_VAL);
                $fdisplay(log_file, "Test File: %s", TEST_FILE_VAL);
                $fdisplay(log_file, "Core Mode: %s", core_mode_str);
                $fdisplay(log_file, "==================================================\n");
                $fdisplay(log_file, "--- Starting RISC-V Simulation ---");
            end
        end

        if (LOG_LEVEL >= 1) begin
            $dumpfile("riscv_sim.vcd");
            $dumpvars(0, riscv_tb);
        end

        clk   = 0;
        rst_n = 0;

        $display("--- Starting RISC-V Simulation ---");
        $display("Using instruction memory file: %s", IMEM_FILE);

        #25;
        rst_n = 1;
        $display("Reset released at t = %0t", $time);
        if (LOG_LEVEL >= 1 && log_file != 0) begin
            $fdisplay(log_file, "Reset released at t = %0t", $time);
        end

        #1000000000;

        if (LOG_LEVEL >= 1 && log_file != 0) begin
            $fdisplay(log_file, "\nSimulation Timeout occurred!");
            print_final_states_to_file();
            $fclose(log_file);
        end

        if (LOG_LEVEL == 2) begin
            print_final_states_to_console();
        end

        $finish;
    end

    // Trace
    always @(posedge clk) begin
        if (rst_n && LOG_LEVEL >= 1) begin
            if (log_file != 0) begin
                $fdisplay(log_file, "[Trace] Time=%0t | PC=%h | Instr=%h", $time, uut.pc, uut.instr);
            end
            if (LOG_LEVEL == 2) begin
                $display("[Trace] Time=%0t | PC=%h | Instr=%h", $time, uut.pc, uut.instr);
            end
        end
    end

    // Dump
    task print_final_states_to_file;
        if (log_file != 0) begin
            $fdisplay(log_file, "\n--- Final Register States (Register File) ---");
            $fdisplay(log_file, "x0  (zero) = %0d", WIDTH'(0));
            $fdisplay(log_file, "x1  (ra)   = %0d | x2  (sp)   = %0d | x3  (gp)   = %0d", uut.core.debug_rf[1], uut.core.debug_rf[2], uut.core.debug_rf[3]);
            $fdisplay(log_file, "x4  (tp)   = %0d | x5  (t0)   = %0d | x6  (t1)   = %0d", uut.core.debug_rf[4], uut.core.debug_rf[5], uut.core.debug_rf[6]);
            $fdisplay(log_file, "x7  (t2)   = %0d | x8  (s0/fp)= %0d | x9  (s1)   = %0d", uut.core.debug_rf[7], uut.core.debug_rf[8], uut.core.debug_rf[9]);
            $fdisplay(log_file, "x10 (a0)   = %0d | x11 (a1)   = %0d | x12 (a2)   = %0d", uut.core.debug_rf[10], uut.core.debug_rf[11], uut.core.debug_rf[12]);
            $fdisplay(log_file, "x13 (a3)   = %0d | x14 (a4)   = %0d | x15 (a5)   = %0d", uut.core.debug_rf[13], uut.core.debug_rf[14], uut.core.debug_rf[15]);
            $fdisplay(log_file, "x16 (a6)   = %0d | x17 (a7)   = %0d | x18 (s2)   = %0d", uut.core.debug_rf[16], uut.core.debug_rf[17], uut.core.debug_rf[18]);
            $fdisplay(log_file, "x19 (s3)   = %0d | x20 (s4)   = %0d | x21 (s5)   = %0d", uut.core.debug_rf[19], uut.core.debug_rf[20], uut.core.debug_rf[21]);
            $fdisplay(log_file, "x22 (s6)   = %0d | x23 (s7)   = %0d | x24 (s8)   = %0d", uut.core.debug_rf[22], uut.core.debug_rf[23], uut.core.debug_rf[24]);
            $fdisplay(log_file, "x25 (s9)   = %0d | x26 (s10)  = %0d | x27 (s11)  = %0d", uut.core.debug_rf[25], uut.core.debug_rf[26], uut.core.debug_rf[27]);
            $fdisplay(log_file, "x28 (t3)   = %0d | x29 (t4)   = %0d | x30 (t5)   = %0d", uut.core.debug_rf[28], uut.core.debug_rf[29], uut.core.debug_rf[30]);
            $fdisplay(log_file, "x31 (t6)   = %0d", uut.core.debug_rf[31]);

            $fdisplay(log_file, "\n--- Data Memory (First 13 words) ---");
            for (int i = 0; i < 13; i++) begin
                $fdisplay(log_file, "RAM[%0d] = %0d", i * 4, uut.data_mem.RAM[i]);
            end
            $fdisplay(log_file, "\n--- Simulation Finished ---");
        end
    endtask

    task print_final_states_to_console;
        $display("\n--- Final Register States (Register File) ---");
        $display("x0  (zero) = %0d", WIDTH'(0));
        $display("x1  (ra)   = %0d | x2  (sp)   = %0d | x3  (gp)   = %0d", uut.core.debug_rf[1], uut.core.debug_rf[2], uut.core.debug_rf[3]);
        $display("x4  (tp)   = %0d | x5  (t0)   = %0d | x6  (t1)   = %0d", uut.core.debug_rf[4], uut.core.debug_rf[5], uut.core.debug_rf[6]);
        $display("x7  (t2)   = %0d | x8  (s0/fp)= %0d | x9  (s1)   = %0d", uut.core.debug_rf[7], uut.core.debug_rf[8], uut.core.debug_rf[9]);
        $display("x10 (a0)   = %0d | x11 (a1)   = %0d | x12 (a2)   = %0d", uut.core.debug_rf[10], uut.core.debug_rf[11], uut.core.debug_rf[12]);
        $display("x13 (a3)   = %0d | x14 (a4)   = %0d | x15 (a5)   = %0d", uut.core.debug_rf[13], uut.core.debug_rf[14], uut.core.debug_rf[15]);
        $display("x16 (a6)   = %0d | x17 (a7)   = %0d | x18 (s2)   = %0d", uut.core.debug_rf[16], uut.core.debug_rf[17], uut.core.debug_rf[18]);
        $display("x19 (s3)   = %0d | x20 (s4)   = %0d | x21 (s5)   = %0d", uut.core.debug_rf[19], uut.core.debug_rf[20], uut.core.debug_rf[21]);
        $display("x22 (s6)   = %0d | x23 (s7)   = %0d | x24 (s8)   = %0d", uut.core.debug_rf[22], uut.core.debug_rf[23], uut.core.debug_rf[24]);
        $display("x25 (s9)   = %0d | x26 (s10)  = %0d | x27 (s11)  = %0d", uut.core.debug_rf[25], uut.core.debug_rf[26], uut.core.debug_rf[27]);
        $display("x28 (t3)   = %0d | x29 (t4)   = %0d | x30 (t5)   = %0d", uut.core.debug_rf[28], uut.core.debug_rf[29], uut.core.debug_rf[30]);
        $display("x31 (t6)   = %0d", uut.core.debug_rf[31]);

        $display("\n--- Data Memory (First 13 words) ---");
        for (int i = 0; i < 13; i++) begin
            $display("RAM[%0d] = %0d", i * 4, uut.data_mem.RAM[i]);
        end
        $display("\n--- Simulation Finished ---");
    endtask

endmodule

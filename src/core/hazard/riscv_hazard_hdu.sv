// riscv_hazard_hdu.sv: Блок обнаружения конфликтов
// Stall / flush конвейера: load-use, branch/jalr, mul/div, taken branch
// Может обнулить IFU/IDU, IDU/EXU

import riscv_pkg::*;

module riscv_hazard_hdu (
    input  logic [4:0] rs1_idu_i,
    input  logic [4:0] rs2_idu_i,
    input  logic [4:0] rd_exu_i,           // rd инструкции в EXU
    input  logic [4:0] rd_mem_i,           // rd инструкции в MEM
    input  logic       reg_write_exu_i,    // EXU пишет в Reg File
    input  logic       reg_write_mem_i,    // MEM пишет в Reg File
    input  logic [1:0] result_src_exu_i,   // 01 = load в EXU (прочие не нужны для этого модуля)
    input  logic       branch_idu_i,       // в IDU условный branch
    input  logic       jalr_idu_i,         // в IDU JALR
    input  logic       branch_taken_idu_i, // прыжок из IDU (branch/jump taken)
    input  logic       busy_exu_i,         // EXU занят mul/div

    output logic       stall_pc_o,         // остановить PC (IFU)
    output logic       stall_idu_o,        // остановить стену IFU/IDU
    output logic       en_exu_o,           // разрешить стену IDU/EXU
    output logic       flush_idu_o,        // сбросить стену IFU/IDU
    output logic       flush_exu_o         // сбросить стену IDU/EXU
);

    logic lw_stall;
    logic branch_stall;
    logic jalr_stall;

    always_comb begin
        // Stall
        // Load-use: load в EXU, его rd нужен в IDU
        lw_stall = (result_src_exu_i == 2'b01) && (rd_exu_i != 5'b0) && ((rd_exu_i == rs1_idu_i) || (rd_exu_i == rs2_idu_i));

        // Условный branch в IDU ждёт операнды из EXU/MEM
        branch_stall = branch_idu_i && ((reg_write_exu_i && (rd_exu_i != 5'b0) && ((rd_exu_i == rs1_idu_i) || (rd_exu_i == rs2_idu_i))) ||
                                        (reg_write_mem_i && (rd_mem_i != 5'b0) && ((rd_mem_i == rs1_idu_i) || (rd_mem_i == rs2_idu_i))));

        // JALR в IDU ждёт rs1 из EXU/MEM
        jalr_stall   = jalr_idu_i && ((reg_write_exu_i && (rd_exu_i != 5'b0) && (rd_exu_i == rs1_idu_i)) ||
                                      (reg_write_mem_i && (rd_mem_i != 5'b0) && (rd_mem_i == rs1_idu_i)));


        // Стены
        // Stall/en/flush
        stall_pc_o  = lw_stall || branch_stall || jalr_stall || busy_exu_i;      // Остановить PC при любом из конфликов
        stall_idu_o = lw_stall || branch_stall || jalr_stall || busy_exu_i;      // Остановить IDU при любом из конфликов
        en_exu_o    = ~busy_exu_i;                                               // Дать новые данные для EXU, если он не занят
        flush_exu_o = (lw_stall || branch_stall || jalr_stall) && ~busy_exu_i;   // Очистить EXU, при любом из конфликтов (если он не занят)


        // Taken branch/jump
        // Taken branch/jump: сбросить ошибочно выбранную инструкцию в IFU/IDU
        if (branch_taken_idu_i && !(lw_stall || branch_stall || jalr_stall || busy_exu_i)) begin
            flush_idu_o = 1'b1;
        end
        else begin
            flush_idu_o = 1'b0;
        end
    end

endmodule

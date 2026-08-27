// riscv_wb.sv: Стадия writeback
// Отвечает за то, какое значение вернуть файлу регистров

import riscv_pkg::*;

module riscv_wb (
    input  logic [1:0]       result_src_wb,   // 00: ALU, 01: mem, 10: PC+4
    input  logic [WIDTH-1:0] read_data_wb,
    input  logic [WIDTH-1:0] alu_result_wb,
    input  logic [WIDTH-1:0] pc_plus4_wb,

    output logic [WIDTH-1:0] result_wb
);

    // Mux результата в Reg File
    always_comb begin
        if (result_src_wb == 2'b00) begin
            result_wb = alu_result_wb;   // Нужно для инструкций R/I-типов (пасисать результат вычисления АЛУ в регистр)
        end
        else if (result_src_wb == 2'b01) begin
            result_wb = read_data_wb;    // Нужно для инструкций I-типа: LB LH LW LBU LHU  (записать в регистр значение из памяти данных)
        end
        else if (result_src_wb == 2'b10) begin
            result_wb = pc_plus4_wb;     // Нужно для JAL JALR (в регистр возвращают адрес следующей инструкции)
        end
        else begin
            result_wb = WIDTH'(0);
        end
    end


endmodule

// riscv_mem_reg_mem2wb.sv: Стена регистров MEM/WB
// Стена регистров между MEM и WB

import riscv_pkg::*;

module riscv_mem_reg_mem2wb (
    input  logic             clk,
    input  logic             rst_n,

    input  logic             mem2wb_reg_write_i,   // Писать ли результат в Reg File на стадии WB (write enable для Reg File)
    input  logic [1:0]       mem2wb_result_src_i,  // Что писать в Reg File на стадии WB (00: ALU, 01: mem, 10: PC+4)

    input  logic [WIDTH-1:0] mem2wb_read_data_i,   // Данные load (уже отформатированные в MEM)
    input  logic [WIDTH-1:0] mem2wb_alu_result_i,  // Результат ALU (или адрес; путь в WB при result_src=00)
    input  logic [WIDTH-1:0] mem2wb_pc_plus4_i,    // PC+4 (для JAL/JALR на WB)
    input  logic [4:0]       mem2wb_rd_addr_i,     // В какой регистр писать на WB

    output logic             mem2wb_reg_write_o,
    output logic [1:0]       mem2wb_result_src_o,

    output logic [WIDTH-1:0] mem2wb_read_data_o,
    output logic [WIDTH-1:0] mem2wb_alu_result_o,
    output logic [WIDTH-1:0] mem2wb_pc_plus4_o,
    output logic [4:0]       mem2wb_rd_addr_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem2wb_reg_write_o  <= 1'b0;
            mem2wb_result_src_o <= 2'b00;
            mem2wb_read_data_o  <= WIDTH'(0);
            mem2wb_alu_result_o <= WIDTH'(0);
            mem2wb_pc_plus4_o   <= WIDTH'(0);
            mem2wb_rd_addr_o    <= 5'b0;
        end
        else begin
            mem2wb_reg_write_o  <= mem2wb_reg_write_i;
            mem2wb_result_src_o <= mem2wb_result_src_i;
            mem2wb_read_data_o  <= mem2wb_read_data_i;
            mem2wb_alu_result_o <= mem2wb_alu_result_i;
            mem2wb_pc_plus4_o   <= mem2wb_pc_plus4_i;
            mem2wb_rd_addr_o    <= mem2wb_rd_addr_i;
        end
    end

endmodule

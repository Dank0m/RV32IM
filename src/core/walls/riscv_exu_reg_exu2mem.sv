// riscv_exu_reg_exu2mem.sv: Стена регистров EXU/MEM
// Стена регистров между EXU и MEM

import riscv_pkg::*;

module riscv_exu_reg_exu2mem (
    input  logic             clk,
    input  logic             rst_n,

    input  logic             exu2mem_reg_write_i,   // Писать ли результат в Reg File на стадии WB (write enable для Reg File)
    input  logic [1:0]       exu2mem_result_src_i,  // Что писать в Reg File на стадии WB (00: ALU, 01: mem, 10: PC+4)
    input  logic             exu2mem_mem_write_i,   // Писать ли в DMEM на стадии MEM

    input  logic [WIDTH-1:0] exu2mem_alu_result_i,  // Результат ALU / адрес для load-store
    input  logic [WIDTH-1:0] exu2mem_write_data_i,  // Данные для store (rs2 после forwarding)
    input  logic [WIDTH-1:0] exu2mem_pc_plus4_i,    // PC+4 (для JAL/JALR на WB)
    input  logic [4:0]       exu2mem_rd_addr_i,     // В какой регистр писать на WB
    input  logic [2:0]       exu2mem_funct3_i,

    output logic             exu2mem_reg_write_o,
    output logic [1:0]       exu2mem_result_src_o,
    output logic             exu2mem_mem_write_o,

    output logic [WIDTH-1:0] exu2mem_alu_result_o,
    output logic [WIDTH-1:0] exu2mem_write_data_o,
    output logic [WIDTH-1:0] exu2mem_pc_plus4_o,
    output logic [4:0]       exu2mem_rd_addr_o,
    output logic [2:0]       exu2mem_funct3_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exu2mem_reg_write_o  <= 1'b0;
            exu2mem_result_src_o <= 2'b00;
            exu2mem_mem_write_o  <= 1'b0;
            exu2mem_alu_result_o <= WIDTH'(0);
            exu2mem_write_data_o <= WIDTH'(0);
            exu2mem_pc_plus4_o   <= WIDTH'(0);
            exu2mem_rd_addr_o    <= 5'b0;
            exu2mem_funct3_o     <= 3'b0;
        end 
        else begin
            exu2mem_reg_write_o  <= exu2mem_reg_write_i;
            exu2mem_result_src_o <= exu2mem_result_src_i;
            exu2mem_mem_write_o  <= exu2mem_mem_write_i;
            exu2mem_alu_result_o <= exu2mem_alu_result_i;
            exu2mem_write_data_o <= exu2mem_write_data_i;
            exu2mem_pc_plus4_o   <= exu2mem_pc_plus4_i;
            exu2mem_rd_addr_o    <= exu2mem_rd_addr_i;
            exu2mem_funct3_o     <= exu2mem_funct3_i;
        end
    end

endmodule

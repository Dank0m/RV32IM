// riscv_idu_reg_idu2exu.sv: Стена регистров IDU/EXU
// Стена регистров между IDU и EXU

import riscv_pkg::*;

module riscv_idu_reg_idu2exu (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             flush_i,               // FLUSH
    input  logic             en_i,                  // ENABLE

    input  logic             idu2exu_reg_write_i,   // Писать ли результат в Reg File на стадии WB (write enable для Reg File)
    input  logic [1:0]       idu2exu_result_src_i,  // Что писать в Reg File на стадии WB (00: ALU, 01: mem, 10: PC+4)
    input  logic             idu2exu_mem_write_i,   // Писать ли результат в DMEM на стадии MEM
    input  logic             idu2exu_alu_src_i,     // Второй операнд для оперций ALU (0: register rs2, 1: immediate)
    input  exu_ctrl_e        idu2exu_ctrl_i,    // Какая оперция в EXU (см typedef)

    input  logic [WIDTH-1:0] idu2exu_pc_i,
    input  logic [WIDTH-1:0] idu2exu_read_data1_i,
    input  logic [WIDTH-1:0] idu2exu_read_data2_i,
    input  logic [WIDTH-1:0] idu2exu_imm_i,
    input  logic [4:0]       idu2exu_rs1_addr_i,
    input  logic [4:0]       idu2exu_rs2_addr_i,
    input  logic [4:0]       idu2exu_rd_addr_i,     // В какой регистр писать на WB
    input  logic [6:0]       idu2exu_op_i,
    input  logic [2:0]       idu2exu_funct3_i,

    output logic             idu2exu_reg_write_o,
    output logic [1:0]       idu2exu_result_src_o,
    output logic             idu2exu_mem_write_o,
    output logic             idu2exu_alu_src_o,
    output exu_ctrl_e        idu2exu_ctrl_o,

    output logic [WIDTH-1:0] idu2exu_pc_o,
    output logic [WIDTH-1:0] idu2exu_read_data1_o,
    output logic [WIDTH-1:0] idu2exu_read_data2_o,
    output logic [WIDTH-1:0] idu2exu_imm_o,
    output logic [4:0]       idu2exu_rs1_addr_o,
    output logic [4:0]       idu2exu_rs2_addr_o,
    output logic [4:0]       idu2exu_rd_addr_o,
    output logic [6:0]       idu2exu_op_o,
    output logic [2:0]       idu2exu_funct3_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idu2exu_reg_write_o  <= 1'b0;
            idu2exu_result_src_o <= 2'b00;
            idu2exu_mem_write_o  <= 1'b0;
            idu2exu_alu_src_o    <= 1'b0;
            idu2exu_ctrl_o   <= ALU_NOP;

            idu2exu_pc_o         <= WIDTH'(0);
            idu2exu_read_data1_o   <= WIDTH'(0);
            idu2exu_read_data2_o   <= WIDTH'(0);
            idu2exu_imm_o        <= WIDTH'(0);
            idu2exu_rs1_addr_o   <= 5'b0;
            idu2exu_rs2_addr_o   <= 5'b0;
            idu2exu_rd_addr_o    <= 5'b0;
            idu2exu_op_o         <= 7'b0;
            idu2exu_funct3_o     <= 3'b0;
        end 
        else if (en_i) begin
            if (flush_i) begin              // bubble
                idu2exu_reg_write_o  <= 1'b0;
                idu2exu_result_src_o <= 2'b00;
                idu2exu_mem_write_o  <= 1'b0;
                idu2exu_alu_src_o    <= 1'b0;
                idu2exu_ctrl_o   <= ALU_NOP;

                idu2exu_pc_o         <= WIDTH'(0);
                idu2exu_read_data1_o   <= WIDTH'(0);
                idu2exu_read_data2_o   <= WIDTH'(0);
                idu2exu_imm_o        <= WIDTH'(0);
                idu2exu_rs1_addr_o   <= 5'b0;
                idu2exu_rs2_addr_o   <= 5'b0;
                idu2exu_rd_addr_o    <= 5'b0;
                idu2exu_op_o         <= 7'b0;
                idu2exu_funct3_o     <= 3'b0;
            end 
            else begin
                idu2exu_reg_write_o  <= idu2exu_reg_write_i;
                idu2exu_result_src_o <= idu2exu_result_src_i;
                idu2exu_mem_write_o  <= idu2exu_mem_write_i;
                idu2exu_alu_src_o    <= idu2exu_alu_src_i;
                idu2exu_ctrl_o   <= idu2exu_ctrl_i;

                idu2exu_pc_o         <= idu2exu_pc_i;
                idu2exu_read_data1_o   <= idu2exu_read_data1_i;
                idu2exu_read_data2_o   <= idu2exu_read_data2_i;
                idu2exu_imm_o        <= idu2exu_imm_i;
                idu2exu_rs1_addr_o   <= idu2exu_rs1_addr_i;
                idu2exu_rs2_addr_o   <= idu2exu_rs2_addr_i;
                idu2exu_rd_addr_o    <= idu2exu_rd_addr_i;
                idu2exu_op_o         <= idu2exu_op_i;
                idu2exu_funct3_o     <= idu2exu_funct3_i;
            end
        end
    end

endmodule

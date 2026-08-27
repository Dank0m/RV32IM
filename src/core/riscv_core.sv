// riscv_core.sv: Ядро
// Стадии IFU/IDU/EXU/MEM/WB, стены регистров, HDU

import riscv_pkg::*;

module riscv_core (
    input  logic             clk,
    input  logic             rst_n,

    input  logic [WIDTH-1:0] imem2core_rd_data_i,  // инструкция из IMEM
    input  logic [WIDTH-1:0] dmem2core_rd_data_i,  // данные load из DMEM

    output logic [3:0]       core2dmem_we_o,       // маска записи в DMEM
    output logic [WIDTH-1:0] core2dmem_addr_o,     // адрес DMEM
    output logic [WIDTH-1:0] core2dmem_wr_data_o,  // данные store
    output logic [WIDTH-1:0] core2imem_addr_o      // адрес IMEM (PC)
);

    logic [31:0] debug_rf [31:0];

    // Hazard
    logic             stall_ifu;
    logic             stall_idu;
    logic             en_exu;
    logic             flush_idu;
    logic             flush_exu;
    logic             stall_m_exu;

    // IFU
    logic [WIDTH-1:0] pc_ifu;

    // стена IFU->IDU
    logic [WIDTH-1:0] pc_idu;
    logic [31:0]      instr_idu;

    // IDU
    logic [6:0]       opcode_idu;
    logic [4:0]       rs1_idu;
    logic [4:0]       rs2_idu;
    logic [4:0]       rd_idu;
    logic [2:0]       funct3_idu;
    logic             branch_idu;
    logic             branch_taken_idu;
    logic [WIDTH-1:0] pc_target_idu;
    logic [WIDTH-1:0] pc_target_jalr;
    logic             reg_write_idu;
    logic [1:0]       result_src_idu;
    logic             mem_write_idu;
    logic             alu_src_idu;
    exu_ctrl_e        exu_ctrl_idu;
    logic [WIDTH-1:0] read_data1_idu;
    logic [WIDTH-1:0] read_data2_idu;
    logic [WIDTH-1:0] imm_idu;

    // стена IDU->EXU
    logic             reg_write_exu;
    logic [1:0]       result_src_exu;
    logic             mem_write_exu;
    logic             alu_src_exu;
    exu_ctrl_e        exu_ctrl_exu;
    logic [WIDTH-1:0] pc_exu;
    logic [WIDTH-1:0] read_data1_exu;
    logic [WIDTH-1:0] read_data2_exu;
    logic [WIDTH-1:0] imm_exu;
    logic [4:0]       rs1_exu;
    logic [4:0]       rs2_exu;
    logic [4:0]       rd_exu;
    logic [6:0]       opcode_exu;
    logic [2:0]       funct3_exu;

    // EXU
    logic             reg_write_exu_o;
    logic             mem_write_exu_o;
    logic [WIDTH-1:0] alu_result_exu_o;
    logic [WIDTH-1:0] write_data_exu_o;
    logic [WIDTH-1:0] pc_plus4_exu_o;

    // стена EXU->MEM
    logic             reg_write_mem;
    logic [1:0]       result_src_mem;
    logic             mem_write_mem_ctrl;
    logic [WIDTH-1:0] alu_result_mem;
    logic [WIDTH-1:0] write_data_mem;
    logic [WIDTH-1:0] pc_plus4_mem;
    logic [4:0]       rd_mem;
    logic [2:0]       funct3_mem;

    // MEM
    logic [WIDTH-1:0] read_data_mem;

    // стена MEM->WB
    logic             reg_write_wb;
    logic [1:0]       result_src_wb;
    logic [WIDTH-1:0] read_data_wb;
    logic [WIDTH-1:0] alu_result_wb;
    logic [WIDTH-1:0] pc_plus4_wb;
    logic [4:0]       rd_wb;

    // WB
    logic [WIDTH-1:0] result_wb;

    assign core2imem_addr_o = pc_ifu;

    // IFU
    riscv_ifu ifu (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_ifu       (stall_ifu),
        .branch_taken_idu(branch_taken_idu),
        .opcode_idu      (opcode_idu),
        .pc_target_idu   (pc_target_idu),
        .pc_target_jalr (pc_target_jalr),
        
        .pc_o           (pc_ifu)
    );

    // стена IFU->IDU
    riscv_ifu_reg_ifu2idu reg_ifu2idu (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush_i         (flush_idu),
        .en_i            (~stall_idu),
        .ifu2idu_pc_i    (pc_ifu),
        .ifu2idu_instr_i (imem2core_rd_data_i),
        
        .ifu2idu_pc_o    (pc_idu),
        .ifu2idu_instr_o (instr_idu)
    );

    // IDU
    riscv_idu idu (
        .clk            (clk),
        .rst_n          (rst_n),
        .pc_idu          (pc_idu),
        .instr_idu       (instr_idu),
        .reg_write_wb   (reg_write_wb),
        .rd_wb          (rd_wb),
        .result_wb      (result_wb),
        
        .opcode_idu      (opcode_idu),
        .rs1_idu         (rs1_idu),
        .rs2_idu         (rs2_idu),
        .rd_idu          (rd_idu),
        .funct3_idu      (funct3_idu),
        .branch_idu      (branch_idu),
        .branch_taken_idu(branch_taken_idu),
        .pc_target_idu   (pc_target_idu),
        .pc_target_jalr (pc_target_jalr),
        .reg_write_idu   (reg_write_idu),
        .result_src_idu  (result_src_idu),
        .mem_write_idu   (mem_write_idu),
        .alu_src_idu     (alu_src_idu),
        .exu_ctrl_idu (exu_ctrl_idu),
        .read_data1_idu  (read_data1_idu),
        .read_data2_idu  (read_data2_idu),
        .imm_idu         (imm_idu)
    );

    // стена IDU->EXU
    riscv_idu_reg_idu2exu reg_idu2exu (
        .clk                 (clk),
        .rst_n               (rst_n),
        .flush_i             (flush_exu),
        .en_i                (en_exu),
        .idu2exu_reg_write_i (reg_write_idu),
        .idu2exu_result_src_i(result_src_idu),
        .idu2exu_mem_write_i (mem_write_idu),
        .idu2exu_alu_src_i   (alu_src_idu),
        .idu2exu_ctrl_i  (exu_ctrl_idu),
        .idu2exu_pc_i        (pc_idu),
        .idu2exu_read_data1_i(read_data1_idu),
        .idu2exu_read_data2_i(read_data2_idu),
        .idu2exu_imm_i       (imm_idu),
        .idu2exu_rs1_addr_i  (rs1_idu),
        .idu2exu_rs2_addr_i  (rs2_idu),
        .idu2exu_rd_addr_i   (rd_idu),
        .idu2exu_op_i        (opcode_idu),
        .idu2exu_funct3_i    (funct3_idu),
        
        .idu2exu_reg_write_o (reg_write_exu),
        .idu2exu_result_src_o(result_src_exu),
        .idu2exu_mem_write_o (mem_write_exu),
        .idu2exu_alu_src_o   (alu_src_exu),
        .idu2exu_ctrl_o  (exu_ctrl_exu),
        .idu2exu_pc_o        (pc_exu),
        .idu2exu_read_data1_o(read_data1_exu),
        .idu2exu_read_data2_o(read_data2_exu),
        .idu2exu_imm_o       (imm_exu),
        .idu2exu_rs1_addr_o  (rs1_exu),
        .idu2exu_rs2_addr_o  (rs2_exu),
        .idu2exu_rd_addr_o   (rd_exu),
        .idu2exu_op_o        (opcode_exu),
        .idu2exu_funct3_o    (funct3_exu)
    );

    // EXU
    riscv_exu exu (
        .clk            (clk),
        .rst_n          (rst_n),
        .alu_src_exu     (alu_src_exu),
        .exu_ctrl_exu (exu_ctrl_exu),
        .opcode_exu      (opcode_exu),
        .pc_exu          (pc_exu),
        .read_data1_exu  (read_data1_exu),
        .read_data2_exu  (read_data2_exu),
        .imm_exu         (imm_exu),
        .rs1_exu         (rs1_exu),
        .rs2_exu         (rs2_exu),
        .reg_write_exu   (reg_write_exu),
        .mem_write_exu   (mem_write_exu),
        .result_wb      (result_wb),
        .rd_wb          (rd_wb),
        .reg_write_wb   (reg_write_wb),
        .rd_mem         (rd_mem),
        .reg_write_mem  (reg_write_mem),
        .alu_result_mem (alu_result_mem),
        
        .stall_m_exu     (stall_m_exu),
        .reg_write_exu_o(reg_write_exu_o),
        .mem_write_exu_o(mem_write_exu_o),
        .alu_result_exu_o(alu_result_exu_o),
        .write_data_exu_o(write_data_exu_o),
        .pc_plus4_exu_o (pc_plus4_exu_o)
    );

    // стена EXU->MEM
    riscv_exu_reg_exu2mem reg_exu2mem (
        .clk                 (clk),
        .rst_n               (rst_n),
        .exu2mem_reg_write_i (reg_write_exu_o),
        .exu2mem_result_src_i(result_src_exu),
        .exu2mem_mem_write_i (mem_write_exu_o),
        .exu2mem_alu_result_i(alu_result_exu_o),
        .exu2mem_write_data_i(write_data_exu_o),
        .exu2mem_pc_plus4_i  (pc_plus4_exu_o),
        .exu2mem_rd_addr_i   (rd_exu),
        .exu2mem_funct3_i    (funct3_exu),
        
        .exu2mem_reg_write_o (reg_write_mem),
        .exu2mem_result_src_o(result_src_mem),
        .exu2mem_mem_write_o (mem_write_mem_ctrl),
        .exu2mem_alu_result_o(alu_result_mem),
        .exu2mem_write_data_o(write_data_mem),
        .exu2mem_pc_plus4_o  (pc_plus4_mem),
        .exu2mem_rd_addr_o   (rd_mem),
        .exu2mem_funct3_o    (funct3_mem)
    );

    // MEM
    riscv_mem mem (
        .mem_write_mem_ctrl(mem_write_mem_ctrl),
        .alu_result_mem    (alu_result_mem),
        .write_data_mem    (write_data_mem),
        .funct3_mem        (funct3_mem),
        .dmem_rdata_i      (dmem2core_rd_data_i),
        
        .dmem_addr_o       (core2dmem_addr_o),
        .dmem_we_o         (core2dmem_we_o),
        .dmem_wdata_o      (core2dmem_wr_data_o),
        .read_data_mem_o   (read_data_mem)
    );

    // стена MEM->WB
    riscv_mem_reg_mem2wb reg_mem2wb (
        .clk                (clk),
        .rst_n              (rst_n),
        .mem2wb_reg_write_i (reg_write_mem),
        .mem2wb_result_src_i(result_src_mem),
        .mem2wb_read_data_i (read_data_mem),
        .mem2wb_alu_result_i(alu_result_mem),
        .mem2wb_pc_plus4_i  (pc_plus4_mem),
        .mem2wb_rd_addr_i   (rd_mem),
        
        .mem2wb_reg_write_o (reg_write_wb),
        .mem2wb_result_src_o(result_src_wb),
        .mem2wb_read_data_o (read_data_wb),
        .mem2wb_alu_result_o(alu_result_wb),
        .mem2wb_pc_plus4_o  (pc_plus4_wb),
        .mem2wb_rd_addr_o   (rd_wb)
    );

    // WB
    riscv_wb wb (
        .result_src_wb(result_src_wb),
        .read_data_wb (read_data_wb),
        .alu_result_wb(alu_result_wb),
        .pc_plus4_wb  (pc_plus4_wb),
        
        .result_wb    (result_wb)
    );

    // HDU
    // Сравнение с литералом: iverilog иногда неверно считает opcode == enum в порту
    logic jalr_idu;
    assign jalr_idu = (opcode_idu == 7'b1100111);

    riscv_hazard_hdu hazard (
        .rs1_idu_i         (rs1_idu),
        .rs2_idu_i         (rs2_idu),
        .rd_exu_i          (rd_exu),
        .rd_mem_i          (rd_mem),
        .reg_write_exu_i   (reg_write_exu),
        .reg_write_mem_i   (reg_write_mem),
        .result_src_exu_i  (result_src_exu),
        .branch_idu_i      (branch_idu),
        .jalr_idu_i        (jalr_idu),
        .branch_taken_idu_i(branch_taken_idu),
        .busy_exu_i        (stall_m_exu),
        
        .stall_pc_o        (stall_ifu),
        .stall_idu_o       (stall_idu),
        .en_exu_o          (en_exu),
        .flush_idu_o       (flush_idu),
        .flush_exu_o       (flush_exu)
    );

    // debug Reg File
    // debug_rf используется для написания логов через тестбенч
    assign debug_rf[0] = WIDTH'(0);
    for (genvar i = 1; i < 32; i++) begin : gen_debug_rf
        assign debug_rf[i] = idu.register_file.reg_file_ff[i];
    end

endmodule

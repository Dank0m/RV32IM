// riscv_idu.sv: Стадия Decode
// Decode, ctrl, Reg File, imm, branch cmp

import riscv_pkg::*;

module riscv_idu (
    input  logic             clk,
    input  logic             rst_n,

    input  logic [WIDTH-1:0] pc_idu,
    input  logic [WIDTH-1:0] instr_idu,

    // С WB (запись в регистровый файл)
    input  logic             reg_write_wb,
    input  logic [4:0]       rd_wb,
    input  logic [WIDTH-1:0] result_wb,

    // К IFU/HDU/стене IDU->EXU
    output logic [6:0]       opcode_idu,
    output logic [4:0]       rs1_idu,
    output logic [4:0]       rs2_idu,
    output logic [4:0]       rd_idu,
    output logic [2:0]       funct3_idu,
    output logic             branch_idu,
    output logic             branch_taken_idu,
    output logic [WIDTH-1:0] pc_target_idu,
    output logic [WIDTH-1:0] pc_target_jalr,
    
    output logic             reg_write_idu,
    output logic [1:0]       result_src_idu,
    output logic             mem_write_idu,
    output logic             alu_src_idu,
    output exu_ctrl_e        exu_ctrl_idu,
    output logic [WIDTH-1:0] read_data1_idu,
    output logic [WIDTH-1:0] read_data2_idu,
    output logic [WIDTH-1:0] imm_idu
);

    // Поля инструкции
    logic        op5_idu;
    logic        funct7_0_idu;
    logic        jump_idu;
    exu_op_e     exu_op_idu;

    assign opcode_idu   = instr_idu[6:0];
    assign rs1_idu      = instr_idu[19:15];
    assign rs2_idu      = instr_idu[24:20];
    assign rd_idu       = instr_idu[11:7];
    assign funct3_idu   = instr_idu[14:12];
    assign op5_idu      = instr_idu[30];
    assign funct7_0_idu = instr_idu[25];


    // Управляющий блок
    riscv_idu_ctrl ctrl (
        .opcode_i    (opcode_idu),
        .reg_write_o (reg_write_idu),
        .result_src_o(result_src_idu),
        .mem_write_o (mem_write_idu),
        .alu_src_o   (alu_src_idu),
        .branch_o    (branch_idu),
        .jump_o      (jump_idu),
        .exu_op_o    (exu_op_idu)
    );

    // Decode
    riscv_idu_dec exu_dec (
        .exu_op_i   (exu_op_idu),
        .funct3_i   (funct3_idu),
        .op5_i      (op5_idu),
        .funct7_0_i (funct7_0_idu),
        .exu_ctrl_o (exu_ctrl_idu)
    );


    // Reg File
    riscv_idu_reg_file register_file (
        .clk       (clk),
        .rst_n     (rst_n),
        .we_i      (reg_write_wb),
        .rs1_addr_i(rs1_idu),
        .rs2_addr_i(rs2_idu),
        .rd_addr_i (rd_wb),
        .rd_data_i (result_wb),
        .rs1_data_o(read_data1_idu),
        .rs2_data_o(read_data2_idu)
    );

    // Immediate
    riscv_idu_imm immediate_generator (
        .instr_i(instr_idu),
        .imm_o  (imm_idu)
    );


    // Branch / jump target
    assign pc_target_idu  = pc_idu + imm_idu;
    assign pc_target_jalr = (read_data1_idu + imm_idu) & ~WIDTH'(1);


    // Branch compare, taken
    logic eq_idu, neq_idu, lt_idu, ge_idu, ltu_idu, geu_idu;

    riscv_idu_cmp branch_comparator (
        .op1_i(read_data1_idu),
        .op2_i(read_data2_idu),
        .eq_o (eq_idu),
        .neq_o(neq_idu),
        .lt_o (lt_idu),
        .ge_o (ge_idu),
        .ltu_o(ltu_idu),
        .geu_o(geu_idu)
    );

    logic branch_match_idu;

    always_comb begin
        case (funct3_idu)
            3'b000:  branch_match_idu = eq_idu;
            3'b001:  branch_match_idu = neq_idu;
            3'b100:  branch_match_idu = lt_idu;
            3'b101:  branch_match_idu = ge_idu;
            3'b110:  branch_match_idu = ltu_idu;
            3'b111:  branch_match_idu = geu_idu;
            default: branch_match_idu = 1'b0;
        endcase
    end

    assign branch_taken_idu = (branch_idu && branch_match_idu) || jump_idu;


endmodule

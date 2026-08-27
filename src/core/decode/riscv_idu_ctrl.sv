// riscv_idu_ctrl.sv: Блок управления IDU
// По opcode выставляет флаги для EXU/MEM/WB и branch/jump

import riscv_pkg::*;

module riscv_idu_ctrl (
    input  logic [6:0] opcode_i,

    output logic       reg_write_o,  // Писать ли в Reg File
    output logic [1:0] result_src_o, // Какой источник данных писать в регистровый файл на WB (00: ALU, 01: Mem, 10: PC + 4)
    output logic       mem_write_o,  // Писать ли в память данных
    output logic       alu_src_o,    // Второй операнд для оперций ALU (0: register rs2, 1: immediate)
    output logic       branch_o,     // Есть ли ветвление
    output logic       jump_o,       // Есть ли безусловный прыжок (1: JAL/JALR)
    output exu_op_e    exu_op_o      // Тип операции (R/I/load-store/branch)
);

    // typedef enum logic [6:0] {
    //     OP_R      = 7'b0110011,
    //     OP_I_ALU  = 7'b0010011,
    //     OP_LOAD   = 7'b0000011,
    //     OP_STORE  = 7'b0100011,
    //     OP_BRANCH = 7'b1100011,
    //     OP_LUI    = 7'b0110111,
    //     OP_AUIPC  = 7'b0010111,
    //     OP_JAL    = 7'b1101111,
    //     OP_JALR   = 7'b1100111
    // } opcode_e;

    always_comb begin
        case (opcode_i)
            OP_R: begin
                reg_write_o  = 1'b1;
                result_src_o = 2'b00;
                mem_write_o  = 1'b0;
                alu_src_o    = 1'b0;
                branch_o     = 1'b0;
                jump_o       = 1'b0;
                exu_op_o     = EXU_OP_R;
            end
            OP_I_ALU: begin
                reg_write_o  = 1'b1;
                result_src_o = 2'b00;
                mem_write_o  = 1'b0;
                alu_src_o    = 1'b1;
                branch_o     = 1'b0;
                jump_o       = 1'b0;
                exu_op_o     = EXU_OP_I;
            end
            OP_LOAD: begin
                reg_write_o  = 1'b1;
                result_src_o = 2'b01;
                mem_write_o  = 1'b0;
                alu_src_o    = 1'b1;
                branch_o     = 1'b0;
                jump_o       = 1'b0;
                exu_op_o     = EXU_OP_LOAD_STORE;
            end
            OP_STORE: begin
                reg_write_o  = 1'b0;
                result_src_o = 2'b00;
                mem_write_o  = 1'b1;
                alu_src_o    = 1'b1;
                branch_o     = 1'b0;
                jump_o       = 1'b0;
                exu_op_o     = EXU_OP_LOAD_STORE;
            end
            OP_BRANCH: begin
                reg_write_o  = 1'b0;
                result_src_o = 2'b00;
                mem_write_o  = 1'b0;
                alu_src_o    = 1'b0;
                branch_o     = 1'b1;
                jump_o       = 1'b0;
                exu_op_o     = EXU_OP_BRANCH;
            end
            OP_LUI: begin
                reg_write_o  = 1'b1;
                result_src_o = 2'b00;
                mem_write_o  = 1'b0;
                alu_src_o    = 1'b1;
                branch_o     = 1'b0;
                jump_o       = 1'b0;
                exu_op_o     = EXU_OP_LOAD_STORE;
            end
            OP_AUIPC: begin
                reg_write_o  = 1'b1;
                result_src_o = 2'b00;
                mem_write_o  = 1'b0;
                alu_src_o    = 1'b1;
                branch_o     = 1'b0;
                jump_o       = 1'b0;
                exu_op_o     = EXU_OP_LOAD_STORE;
            end
            OP_JAL: begin
                reg_write_o  = 1'b1;
                result_src_o = 2'b10;
                mem_write_o  = 1'b0;
                alu_src_o    = 1'b0;
                branch_o     = 1'b0;
                jump_o       = 1'b1;
                exu_op_o     = EXU_OP_LOAD_STORE;
            end
            OP_JALR: begin
                reg_write_o  = 1'b1;
                result_src_o = 2'b10;
                mem_write_o  = 1'b0;
                alu_src_o    = 1'b1;
                branch_o     = 1'b0;
                jump_o       = 1'b1;
                exu_op_o     = EXU_OP_LOAD_STORE;
            end
            default: begin
                reg_write_o  = 1'b0;
                result_src_o = 2'b00;
                mem_write_o  = 1'b0;
                alu_src_o    = 1'b0;
                branch_o     = 1'b0;
                jump_o       = 1'b0;
                exu_op_o     = EXU_OP_LOAD_STORE;
            end
        endcase
    end

endmodule

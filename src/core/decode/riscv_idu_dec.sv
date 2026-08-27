// riscv_idu_dec.sv: Декодер операций
// По exu_op, funct3, битам инструкции выбирает операцию IALU или M (exu_ctrl) для EXU

import riscv_pkg::*;

module riscv_idu_dec (
    input  exu_op_e    exu_op_i,     // Класс операции из ctrl (R / I / load-store / branch)
    input  logic [2:0] funct3_i,
    input  logic       op5_i,        // instr[30], SUB/ADD, SRA/SRL
    input  logic       funct7_0_i,   // instr[25], 1: M-расширение (MUL/DIV)

    output exu_ctrl_e  exu_ctrl_o
);

    always_comb begin
        case (exu_op_i)
            EXU_OP_LOAD_STORE: exu_ctrl_o = ALU_ADD;
            EXU_OP_BRANCH:     exu_ctrl_o = ALU_SUB;
            EXU_OP_R: begin
                if (funct7_0_i) begin
                    case (funct3_i)
                        3'b000:  exu_ctrl_o = ALU_MUL;
                        3'b001:  exu_ctrl_o = ALU_MULH;
                        3'b010:  exu_ctrl_o = ALU_MULHSU;
                        3'b011:  exu_ctrl_o = ALU_MULHU;
                        3'b100:  exu_ctrl_o = ALU_DIV;
                        3'b101:  exu_ctrl_o = ALU_DIVU;
                        3'b110:  exu_ctrl_o = ALU_REM;
                        3'b111:  exu_ctrl_o = ALU_REMU;
                        default: exu_ctrl_o = ALU_NOP;
                    endcase
                end
                else begin
                    case (funct3_i)
                        3'b000: begin
                            if (op5_i) begin
                                exu_ctrl_o = ALU_SUB;
                            end
                            else begin
                                exu_ctrl_o = ALU_ADD;
                            end
                        end
                        3'b001:  exu_ctrl_o = ALU_SLL;
                        3'b010:  exu_ctrl_o = ALU_SLT;
                        3'b011:  exu_ctrl_o = ALU_SLTU;
                        3'b100:  exu_ctrl_o = ALU_XOR;
                        3'b101: begin
                            if (op5_i) begin
                                exu_ctrl_o = ALU_SRA;
                            end
                            else begin
                                exu_ctrl_o = ALU_SRL;
                            end
                        end
                        3'b110:  exu_ctrl_o = ALU_OR;
                        3'b111:  exu_ctrl_o = ALU_AND;
                        default: exu_ctrl_o = ALU_NOP;
                    endcase
                end
            end
            EXU_OP_I: begin
                case (funct3_i)
                    3'b000:  exu_ctrl_o = ALU_ADD;
                    3'b001:  exu_ctrl_o = ALU_SLL;
                    3'b010:  exu_ctrl_o = ALU_SLT;
                    3'b011:  exu_ctrl_o = ALU_SLTU;
                    3'b100:  exu_ctrl_o = ALU_XOR;
                    3'b101: begin
                        if (op5_i) begin
                            exu_ctrl_o = ALU_SRA;
                        end
                        else begin
                            exu_ctrl_o = ALU_SRL;
                        end
                    end
                    3'b110:  exu_ctrl_o = ALU_OR;
                    3'b111:  exu_ctrl_o = ALU_AND;
                    default: exu_ctrl_o = ALU_NOP;
                endcase
            end
            default: exu_ctrl_o = ALU_NOP;
        endcase
    end

endmodule

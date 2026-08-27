// riscv_idu_imm.sv: Генератор immediate
// По opcode вычленяет immediate из инструкции

import riscv_pkg::*;

module riscv_idu_imm (
    input  logic [WIDTH-1:0] instr_i,
    
    output logic [WIDTH-1:0] imm_o
);

    logic [6:0] opcode;
    assign opcode = instr_i[6:0];

    always_comb begin
        case (opcode)
            OP_I_ALU, OP_LOAD, OP_JALR: imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
            OP_STORE:                   imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
            OP_BRANCH:                  imm_o = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
            OP_LUI, OP_AUIPC:           imm_o = {instr_i[31:12], 12'b0};
            OP_JAL:                     imm_o = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
            default:                    imm_o = 'hBADC;
        endcase
    end

endmodule

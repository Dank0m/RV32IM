// riscv_exu_ialu.sv: Целочисленное АЛУ (IALU)
// Комбинационные операции: ADD/SUB, логика, сдвиги, SLT/SLTU

import riscv_pkg::*;

module riscv_exu_ialu (
    input  logic [WIDTH-1:0] op1_i,   // Первый операнд
    input  logic [WIDTH-1:0] op2_i,   // Второй операнд (для сдвигов: shamt = op2[4:0])
    input  exu_ctrl_e        cmd_i,   // Код операции из IDU

    output logic [WIDTH-1:0] res_o
);

    logic [4:0] shamt;                // Shift amount
    assign shamt = op2_i[4:0];

    always_comb begin
        case (cmd_i)
            ALU_ADD:  res_o = op1_i + op2_i;
            ALU_SUB:  res_o = op1_i - op2_i;
            ALU_AND:  res_o = op1_i & op2_i;
            ALU_OR:   res_o = op1_i | op2_i;
            ALU_XOR:  res_o = op1_i ^ op2_i;
            ALU_SLL:  res_o = $unsigned(op1_i) << shamt;
            ALU_SRL:  res_o = $unsigned(op1_i) >> shamt;
            ALU_SRA:  res_o = $signed(op1_i) >>> shamt;
            ALU_SLT: begin
                if ($signed(op1_i) < $signed(op2_i)) begin
                    res_o = WIDTH'(1);
                end
                else begin
                    res_o = WIDTH'(0);
                end
            end
            ALU_SLTU: begin
                if ($unsigned(op1_i) < $unsigned(op2_i)) begin
                    res_o = WIDTH'(1);
                end
                else begin
                    res_o = WIDTH'(0);
                end
            end
            
            default:  res_o = WIDTH'(0);
        endcase
    end

endmodule

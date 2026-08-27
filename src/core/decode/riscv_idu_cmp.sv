// riscv_idu_cmp.sv: Компаратор для IDU
// Принимает два операнда, возвращает флаги, по которым в IDU определяется, будет ли совершен прыжок или нет

import riscv_pkg::*;

module riscv_idu_cmp (
    input  logic [WIDTH-1:0] op1_i,
    input  logic [WIDTH-1:0] op2_i,

    output logic             eq_o,  // op1 Equal to op2
    output logic             neq_o, // op1 Not Equal to op2
    output logic             lt_o,  // op1 Less Than op2
    output logic             ge_o,  // op1 Greater or Equal op2
    output logic             ltu_o, // op1 Less Than (Unsigned) op2
    output logic             geu_o  // op1 Greater or Equal (Unsigned) op2
);

    assign eq_o  = (op1_i == op2_i);
    assign neq_o = (op1_i != op2_i);
    assign lt_o  = ($signed(op1_i) < $signed(op2_i));
    assign ge_o  = ($signed(op1_i) >= $signed(op2_i));
    assign ltu_o = (op1_i < op2_i);
    assign geu_o = (op1_i >= op2_i);

endmodule

// adder.sv: Модуль сложения

import riscv_pkg::*;

module adder #(
    parameter WIDTH = 32
) (
    input  logic [WIDTH-1:0] a_i,
    input  logic [WIDTH-1:0] b_i,

    output logic [WIDTH-1:0] sum_o
);

    assign sum_o = a_i + b_i;

endmodule

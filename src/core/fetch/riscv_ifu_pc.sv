// riscv_ifu_pc.sv: Program Counter
// Регистр, в котором хранится значемние PC

import riscv_pkg::*;

module riscv_ifu_pc (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             pc_en_i,   // ENABLE здесь используется как !STALL
    input  logic [WIDTH-1:0] pc_next_i, // Следующее значеие PC меняется в posedge clk если ENABLE

    output logic [WIDTH-1:0] pc_curr_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_curr_o <= WIDTH'(0);
        end
        else if (pc_en_i) begin
            pc_curr_o <= pc_next_i;
        end
    end

endmodule

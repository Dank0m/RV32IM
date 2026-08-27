// riscv_ifu_reg_ifu2idu.sv: Стена регистров IFU/IDU
// Стена регистров между IFU и IDU

import riscv_pkg::*;

module riscv_ifu_reg_ifu2idu (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             flush_i,               // FLUSH
    input  logic             en_i,                  // ENABLE

    input  logic [WIDTH-1:0] ifu2idu_pc_i,
    input  logic [31:0]      ifu2idu_instr_i,

    output logic [WIDTH-1:0] ifu2idu_pc_o,
    output logic [31:0]      ifu2idu_instr_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ifu2idu_pc_o    <= WIDTH'(0);
            ifu2idu_instr_o <= 32'h00000013; // NOP (addi x0, x0, 0)
        end
        else if (en_i) begin
            if (flush_i) begin
                ifu2idu_pc_o    <= WIDTH'(0);
                ifu2idu_instr_o <= 32'h00000013; // NOP
            end
            else begin
                ifu2idu_pc_o    <= ifu2idu_pc_i;
                ifu2idu_instr_o <= ifu2idu_instr_i;
            end
        end
    end

endmodule

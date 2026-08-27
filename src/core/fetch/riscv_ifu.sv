// riscv_ifu.sv: Стадия Fetch
// PC и next-PC

import riscv_pkg::*;

module riscv_ifu (
    input  logic             clk,
    input  logic             rst_n,

    input  logic             stall_ifu,            // остановить PC

    input  logic             branch_taken_idu,     // прыжок из IDU
    input  logic [6:0]       opcode_idu,           // нужен для JALR vs branch/JAL
    input  logic [WIDTH-1:0] pc_target_idu,        // pc + imm (branch / JAL)
    input  logic [WIDTH-1:0] pc_target_jalr,      // (rs1 + imm) & ~1

    output logic [WIDTH-1:0] pc_o
);

    // Регистр PC
    logic [WIDTH-1:0] pc_next;
    logic [WIDTH-1:0] pc_plus4;

    riscv_ifu_pc pc_register (
        .clk      (clk),
        .rst_n    (rst_n),
        .pc_en_i  (~stall_ifu),
        .pc_next_i(pc_next),
        .pc_curr_o(pc_o)
    );


    // next PC: +4 / branch / JALR 
    assign pc_plus4 = pc_o + WIDTH'(4);

    always_comb begin
        if (!branch_taken_idu) begin
            pc_next = pc_plus4;
        end
        else if (opcode_idu == OP_JALR) begin
            pc_next = pc_target_jalr;
        end
        else begin
            pc_next = pc_target_idu;
        end
    end

endmodule

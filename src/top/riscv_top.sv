// riscv_top.sv: Top: CORE, IMEM, DMEM

import riscv_pkg::*;

module riscv_top (
    input  logic clk,
    input  logic rst_n
);

    logic [WIDTH-1:0] pc;
    logic [31:0]      instr;

    logic [3:0]       mem_write;
    logic [WIDTH-1:0] mem_addr;
    logic [WIDTH-1:0] mem_write_data;
    logic [WIDTH-1:0] mem_read_data;

    // CORE
    riscv_core core (
        .clk                (clk),
        .rst_n              (rst_n),
        .imem2core_rd_data_i(instr),
        .dmem2core_rd_data_i(mem_read_data),

        .core2imem_addr_o   (pc),
        .core2dmem_we_o     (mem_write),
        .core2dmem_addr_o   (mem_addr),
        .core2dmem_wr_data_o(mem_write_data)
    );

    // IMEM
    riscv_imem instruction_mem (
        .imem_addr_i   (pc),

        .imem_rd_data_o(instr)
    );

    // DMEM
    riscv_dmem data_mem (
        .clk           (clk),
        .dmem_we_i     (mem_write),
        .dmem_addr_i   (mem_addr),
        .dmem_wr_data_i(mem_write_data),

        .dmem_rd_data_o(mem_read_data)
    );

endmodule

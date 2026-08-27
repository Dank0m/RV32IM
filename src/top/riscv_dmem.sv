// riscv_dmem.sv: Память данных (RAM)
// Load/store с маской по байтам

import riscv_pkg::*;

module riscv_dmem (
    input  logic             clk,
    input  logic [3:0]       dmem_we_i,       // маска записи (byte enable)
    input  logic [WIDTH-1:0] dmem_addr_i,     // адрес (байтовый)
    input  logic [WIDTH-1:0] dmem_wr_data_i,  // данные store

    output logic [WIDTH-1:0] dmem_rd_data_o
);

    logic [WIDTH-1:0] RAM [DMEM_SIZE-1:0];

    initial begin
        if (DMEM_FILE != "") begin
            $readmemh(DMEM_FILE, RAM);
        end
    end

    always_ff @(posedge clk) begin
        if (dmem_we_i[0]) begin
            RAM[(dmem_addr_i >> 2) % DMEM_SIZE][7:0]   <= dmem_wr_data_i[7:0];
        end
        if (dmem_we_i[1]) begin
            RAM[(dmem_addr_i >> 2) % DMEM_SIZE][15:8]  <= dmem_wr_data_i[15:8];
        end
        if (dmem_we_i[2]) begin
            RAM[(dmem_addr_i >> 2) % DMEM_SIZE][23:16] <= dmem_wr_data_i[23:16];
        end
        if (dmem_we_i[3]) begin
            RAM[(dmem_addr_i >> 2) % DMEM_SIZE][31:24] <= dmem_wr_data_i[31:24];
        end
    end

    always_comb begin
        dmem_rd_data_o = RAM[(dmem_addr_i >> 2) % DMEM_SIZE];
    end

endmodule

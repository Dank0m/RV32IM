// riscv_imem.sv: Память инструкций (ROM)
// Читает слово по адресу PC

import riscv_pkg::*;

module riscv_imem (
    input  logic [WIDTH-1:0] imem_addr_i,    // адрес (байтовый, как PC)

    output logic [WIDTH-1:0] imem_rd_data_o
);

    logic [WIDTH-1:0] ROM [IMEM_SIZE-1:0];

    initial begin
        if (IMEM_FILE != "") begin
            $readmemh(IMEM_FILE, ROM);
        end
    end

    always_comb begin
        imem_rd_data_o = ROM[(imem_addr_i >> 2) % IMEM_SIZE];
    end

endmodule

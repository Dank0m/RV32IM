// riscv_exu_fwd.sv: Блок обратной связи
// Выбирает источник операндов для EXU: Reg File, MEM или WB

import riscv_pkg::*;

module riscv_exu_fwd (
    input  logic [4:0] rs1_addr_i,
    input  logic [4:0] rs2_addr_i,
    input  logic [4:0] rd_mem_i,         // rd инструкции в MEM
    input  logic [4:0] rd_wb_i,          // rd инструкции в WB
    input  logic       reg_write_mem_i,  // MEM пишет в Reg File
    input  logic       reg_write_wb_i,   // WB пишет в Reg File

    output logic [1:0] forward_a_o,      // 00: Reg File, 01: WB, 10: MEM
    output logic [1:0] forward_b_o       // 00: Reg File, 01: WB, 10: MEM
);

    always_comb begin
        // Операнд A (rs1): MEM приоритетнее WB
        if (reg_write_mem_i && (rd_mem_i != 5'b0) && (rd_mem_i == rs1_addr_i)) begin
            forward_a_o = 2'b10; //MEM
        end
        else if (reg_write_wb_i && (rd_wb_i != 5'b0) && (rd_wb_i == rs1_addr_i)) begin
            forward_a_o = 2'b01; //WB
        end
        else begin
            forward_a_o = 2'b00; //нету
        end

        // Операнд B (rs2): MEM приоритетнее WB
        if (reg_write_mem_i && (rd_mem_i != 5'b0) && (rd_mem_i == rs2_addr_i)) begin
            forward_b_o = 2'b10; //MEM
        end
        else if (reg_write_wb_i && (rd_wb_i != 5'b0) && (rd_wb_i == rs2_addr_i)) begin
            forward_b_o = 2'b01; //WB
        end
        else begin
            forward_b_o = 2'b00; //нету
        end
    end

endmodule

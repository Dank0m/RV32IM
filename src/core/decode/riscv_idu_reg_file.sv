// riscv_idu_reg_file.sv: Reg File
// Регистровый файл x1-x31: запись с WB, чтение rs1/rs2, bypass при совпадении с записью
// x0 всегда читается как 0 и не пишется

import riscv_pkg::*;

module riscv_idu_reg_file (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             we_i,         // Разрешение записи (из WB)
    input  logic [4:0]       rs1_addr_i,
    input  logic [4:0]       rs2_addr_i,
    input  logic [4:0]       rd_addr_i,    // Куда писать
    input  logic [WIDTH-1:0] rd_data_i,    // Что писать

    output logic [WIDTH-1:0] rs1_data_o,
    output logic [WIDTH-1:0] rs2_data_o
);

    logic [WIDTH-1:0] reg_file_ff [31:1];

    // Запись
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 1; i < 32; i++) begin
                reg_file_ff[i] <= WIDTH'(0);
            end
        end
        else if (we_i && (rd_addr_i != 5'b0)) begin
            reg_file_ff[rd_addr_i] <= rd_data_i;
        end
    end


    // Чтение, bypass с WB
    always_comb begin
        if (rs1_addr_i == 5'b0) begin
            rs1_data_o = WIDTH'(0);
        end
        else if (we_i && (rd_addr_i == rs1_addr_i)) begin // Если адреса совпадают, от сразу вернуть rd_data_i
            rs1_data_o = rd_data_i;
        end
        else begin
            rs1_data_o = reg_file_ff[rs1_addr_i];
        end

        if (rs2_addr_i == 5'b0) begin
            rs2_data_o = WIDTH'(0);
        end
        else if (we_i && (rd_addr_i == rs2_addr_i)) begin // Если адреса совпадают, от сразу вернуть rd_data_i
            rs2_data_o = rd_data_i;
        end
        else begin
            rs2_data_o = reg_file_ff[rs2_addr_i];
        end
    end


endmodule

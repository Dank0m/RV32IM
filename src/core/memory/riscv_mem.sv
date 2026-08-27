// riscv_mem.sv: Стадия Memory
// Store/load format для DMEM

import riscv_pkg::*;

module riscv_mem (
    input  logic             mem_write_mem_ctrl,  // store в DMEM
    input  logic [WIDTH-1:0] alu_result_mem,      // адрес load/store
    input  logic [WIDTH-1:0] write_data_mem,      // rs2 после forward (данные store)
    input  logic [2:0]       funct3_mem,          // width/sign load/store

    input  logic [WIDTH-1:0] dmem_rdata_i,

    output logic [WIDTH-1:0] dmem_addr_o,
    output logic [3:0]       dmem_we_o,
    output logic [WIDTH-1:0] dmem_wdata_o,

    output logic [WIDTH-1:0] read_data_mem_o      // load после format -> стена
);

    // Адрес DMEM
    assign dmem_addr_o = alu_result_mem;

    logic [1:0] addr_byte_off;
    logic       addr_half_off;
    assign addr_byte_off = alu_result_mem[1:0];
    assign addr_half_off = alu_result_mem[1];


    // Store: маска byte / half / word
    logic [3:0] mem_write_mask;

    always_comb begin
        if (mem_write_mem_ctrl) begin
            case (funct3_mem)
                3'b000: begin
                    case (addr_byte_off)
                        2'b00: mem_write_mask = 4'b0001;
                        2'b01: mem_write_mask = 4'b0010;
                        2'b10: mem_write_mask = 4'b0100;
                        2'b11: mem_write_mask = 4'b1000;
                    endcase
                end
                3'b001: begin
                    case (addr_half_off)
                        1'b0:  mem_write_mask = 4'b0011;
                        1'b1:  mem_write_mask = 4'b1100;
                    endcase
                end
                3'b010:  mem_write_mask = 4'b1111;
                default: mem_write_mask = 4'b0000;
            endcase
        end
        else begin
            mem_write_mask = 4'b0000;
        end
    end

    assign dmem_we_o = mem_write_mask;


    // Store: данные wdata
    logic [7:0]  wdata_b0;
    logic [15:0] wdata_h0;
    assign wdata_b0 = write_data_mem[7:0];
    assign wdata_h0 = write_data_mem[15:0];

    always_comb begin
        case (funct3_mem)
            3'b000:  dmem_wdata_o = {wdata_b0, wdata_b0, wdata_b0, wdata_b0};
            3'b001:  dmem_wdata_o = {wdata_h0, wdata_h0};
            default: dmem_wdata_o = write_data_mem;
        endcase
    end


    // Load: разбор rdata на byte / half
    logic [7:0]  rdata_b0, rdata_b1, rdata_b2, rdata_b3;
    logic [15:0] rdata_h0, rdata_h1;
    assign rdata_b0 = dmem_rdata_i[7:0];
    assign rdata_b1 = dmem_rdata_i[15:8];
    assign rdata_b2 = dmem_rdata_i[23:16];
    assign rdata_b3 = dmem_rdata_i[31:24];
    assign rdata_h0 = dmem_rdata_i[15:0];
    assign rdata_h1 = dmem_rdata_i[31:16];

    logic sign_b0, sign_b1, sign_b2, sign_b3;
    logic sign_h0, sign_h1;
    assign sign_b0 = rdata_b0[7];
    assign sign_b1 = rdata_b1[7];
    assign sign_b2 = rdata_b2[7];
    assign sign_b3 = rdata_b3[7];
    assign sign_h0 = rdata_h0[15];
    assign sign_h1 = rdata_h1[15];


    // Load: sign/zero extend -> read_data_mem_o
    logic [WIDTH-1:0] read_data_mem_formatted;

    always_comb begin
        case (funct3_mem)
            3'b000: begin
                case (addr_byte_off)
                    2'b00: read_data_mem_formatted = {{24{sign_b0}}, rdata_b0};
                    2'b01: read_data_mem_formatted = {{24{sign_b1}}, rdata_b1};
                    2'b10: read_data_mem_formatted = {{24{sign_b2}}, rdata_b2};
                    2'b11: read_data_mem_formatted = {{24{sign_b3}}, rdata_b3};
                endcase
            end
            3'b001: begin
                case (addr_half_off)
                    1'b0:  read_data_mem_formatted = {{16{sign_h0}}, rdata_h0};
                    1'b1:  read_data_mem_formatted = {{16{sign_h1}}, rdata_h1};
                endcase
            end
            3'b010: read_data_mem_formatted = dmem_rdata_i;
            3'b100: begin
                case (addr_byte_off)
                    2'b00: read_data_mem_formatted = {24'b0, rdata_b0};
                    2'b01: read_data_mem_formatted = {24'b0, rdata_b1};
                    2'b10: read_data_mem_formatted = {24'b0, rdata_b2};
                    2'b11: read_data_mem_formatted = {24'b0, rdata_b3};
                endcase
            end
            3'b101: begin
                case (addr_half_off)
                    1'b0:  read_data_mem_formatted = {16'b0, rdata_h0};
                    1'b1:  read_data_mem_formatted = {16'b0, rdata_h1};
                endcase
            end
            default: read_data_mem_formatted = dmem_rdata_i;
        endcase
    end

    assign read_data_mem_o = read_data_mem_formatted;


endmodule

// riscv_exu.sv: Стадия Execute
// Forwarding, IALU / IMUL / IDIV

import riscv_pkg::*;

module riscv_exu (
    input  logic             clk,
    input  logic             rst_n,

    // Входы со стены IDU/EXU
    input  logic             alu_src_exu,          // 0: op2 = rs2, 1: op2 = imm
    input  exu_ctrl_e        exu_ctrl_exu,         // код операции IALU/M
    input  logic [6:0]       opcode_exu,           // нужен только для LUI/AUIPC/прочее
    input  logic [WIDTH-1:0] pc_exu,
    input  logic [WIDTH-1:0] read_data1_exu,       // данные rs1 из Reg File
    input  logic [WIDTH-1:0] read_data2_exu,       // данные rs2 из Reg File
    input  logic [WIDTH-1:0] imm_exu,
    input  logic [4:0]       rs1_exu,              // source 1
    input  logic [4:0]       rs2_exu,              // source 2
    input  logic             reg_write_exu,        // писать в Reg File на WB
    input  logic             mem_write_exu,        // писать в DMEM на MEM

    // Входы для forwarding
    input  logic [WIDTH-1:0] result_wb,           // результат стадии WB (forward)
    input  logic [4:0]       rd_wb,
    input  logic             reg_write_wb,
    input  logic [4:0]       rd_mem,
    input  logic             reg_write_mem,
    input  logic [WIDTH-1:0] alu_result_mem,     // MEM->EX forward data

    output logic             stall_m_exu,          // stall: mul/div ещё не готов

    // К стене EXU->MEM
    output logic             reg_write_exu_o,     // we с учётом stall
    output logic             mem_write_exu_o,     // mem we с учётом stall
    output logic [WIDTH-1:0] alu_result_exu_o,    // результат ALU/M или адрес
    output logic [WIDTH-1:0] write_data_exu_o,    // данные для store
    output logic [WIDTH-1:0] pc_plus4_exu_o       // PC+4 (для JAL/JALR)
);

    // Forwarding: Reg File / MEM / WB -> src_a, src_b
    logic [1:0]       forward_a;                  // 00: Reg File, 01: WB, 10: MEM
    logic [1:0]       forward_b;                  // 00: Reg File, 01: WB, 10: MEM
    logic [WIDTH-1:0] forwarded_a_exu;             // rs1 после forwarding
    logic [WIDTH-1:0] forwarded_b_exu;             // rs2 после forwarding
    logic [WIDTH-1:0] src_a_exu;                   // вход A в IALU / M
    logic [WIDTH-1:0] src_b_exu;                   // вход B в IALU / M

    riscv_exu_fwd forward (
        .rs1_addr_i     (rs1_exu),
        .rs2_addr_i     (rs2_exu),
        .rd_mem_i       (rd_mem),
        .rd_wb_i        (rd_wb),
        .reg_write_mem_i(reg_write_mem),
        .reg_write_wb_i (reg_write_wb),
        .forward_a_o    (forward_a),
        .forward_b_o    (forward_b)
    );

    always_comb begin
        // Операнд A
        if (forward_a == 2'b10) begin
            forwarded_a_exu = alu_result_mem;
        end
        else if (forward_a == 2'b01) begin
            forwarded_a_exu = result_wb;
        end
        else begin
            forwarded_a_exu = read_data1_exu;
        end

        // LUI: 0 + imm; AUIPC: pc + imm; иначе rs1
        if (opcode_exu == OP_LUI) begin
            src_a_exu = WIDTH'(0);
        end
        else if (opcode_exu == OP_AUIPC) begin
            src_a_exu = pc_exu;
        end
        else begin
            src_a_exu = forwarded_a_exu;
        end

        // Операнд B
        if (forward_b == 2'b10) begin
            forwarded_b_exu = alu_result_mem;
        end
        else if (forward_b == 2'b01) begin
            forwarded_b_exu = result_wb;
        end
        else begin
            forwarded_b_exu = read_data2_exu;
        end

        if (alu_src_exu) begin
            src_b_exu = imm_exu;
        end
        else begin
            src_b_exu = forwarded_b_exu;
        end
    end


    // IALU
    logic [WIDTH-1:0] alu_result_raw_exu;          // выход IALU

    riscv_exu_ialu arithmetic_logic_unit (
        .op1_i(src_a_exu),
        .op2_i(src_b_exu),
        .cmd_i(exu_ctrl_exu),
        .res_o(alu_result_raw_exu)
    );


    // M-extension: IMUL / IDIV, stall
    logic             m_extension_opcode_exu;      // M-extension: mul или div/rem
    logic             mul_op_exu;                  // MUL*
    logic             div_op_exu;                  // DIV*/REM*
    logic             m_started;                  // уже стартовали mul/div, ждём done
    logic             mul_done;
    logic             div_done;
    logic             done_exu;                    // mul_done || div_done
    logic             mul_start;                  // valid для IMUL
    logic             div_start;                  // valid для IDIV
    logic [31:0]      mul_res;
    logic [31:0]      div_res;
    logic [31:0]      result_m_exu;                // результат M (mul или div)
    logic [WIDTH-1:0] alu_result_exu;              // IALU или mul/div

    // exu_ctrl_exu[4]=1, exu_ctrl_exu[3]=0 - M-extension; mul = 100xx, div = 101xx
    assign m_extension_opcode_exu = exu_ctrl_exu[4] && ~exu_ctrl_exu[3];
    assign mul_op_exu = (exu_ctrl_exu[4:2] == 3'b100);
    assign div_op_exu = (exu_ctrl_exu[4:2] == 3'b101);
    assign done_exu   = mul_done || div_done;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_started <= 1'b0;
        end
        else begin
            if (m_extension_opcode_exu && ~m_started) begin
                m_started <= 1'b1;
            end
            else if (done_exu) begin
                m_started <= 1'b0;
            end
        end
    end

    assign mul_start  = mul_op_exu && ~m_started;
    assign div_start  = div_op_exu && ~m_started;
    assign stall_m_exu = m_extension_opcode_exu && ~done_exu;

    riscv_exu_imul multiplier (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_i (mul_start),
        .cmd_i   (exu_ctrl_exu[1:0]),
        .op1_i   (src_a_exu),
        .op2_i   (src_b_exu),
        .result_o(mul_res),
        .done_o  (mul_done)
    );

    riscv_exu_idiv divider (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_i (div_start),
        .cmd_i   (exu_ctrl_exu[1:0]),
        .op1_i   (src_a_exu),
        .op2_i   (src_b_exu),
        .result_o(div_res),
        .done_o  (div_done)
    );

    always_comb begin
        if (mul_op_exu) begin
            result_m_exu = mul_res;
        end
        else begin
            result_m_exu = div_res;
        end

        if (m_extension_opcode_exu) begin
            alu_result_exu = result_m_exu;
        end
        else begin
            alu_result_exu = alu_result_raw_exu;
        end
    end


    logic [WIDTH-1:0] pc_plus4_exu;                // pc + 4 (для JAL/JALR)

    // Пока mul/div занят - в стену не пускаем WRITE ENABLE
    assign reg_write_exu_o  = reg_write_exu && ~stall_m_exu;
    assign mem_write_exu_o  = mem_write_exu && ~stall_m_exu;
    assign alu_result_exu_o = alu_result_exu;
    assign write_data_exu_o = forwarded_b_exu;
    assign pc_plus4_exu      = pc_exu + WIDTH'(4);
    assign pc_plus4_exu_o   = pc_plus4_exu;


endmodule

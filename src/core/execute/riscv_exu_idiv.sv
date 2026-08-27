// riscv_exu_idiv.sv: Целочисленный делитель
// DIV/DIVU/REM/REMU: restoring division, коенчный автомат IDLE -> CALC -> DONE

import riscv_pkg::*;

module riscv_exu_idiv (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_i,
    input  logic [1:0]  cmd_i,                 // 00: DIV, 01: DIVU, 10: REM, 11: REMU
    input  logic [31:0] op1_i,
    input  logic [31:0] op2_i,

    output logic [31:0] result_o,
    output logic        done_o                 // Результат готов: state == DONE (1 такт)
);

    state_e      state_ff;
    logic [1:0]  cmd_ff;
    logic [31:0] op1_ff;
    logic [31:0] op2_ff;
    logic [5:0]  count_ff;                     // 0 ... 32

    logic        sign_quot_ff;                 // знак частного (1 = отрицательное)
    logic        sign_rem_ff;                  // знак остатка (1 = отрицательное)
    logic [31:0] abs_a;
    logic [31:0] abs_b;
    logic [31:0] quot;                         // частное (quotient)
    logic [31:0] rem;                          // остаток (remainder)

    logic [31:0] part_rem_ff;                  // частичный остаток (partial remainder)
    logic [31:0] accum_ff;                     // делимое, затем частное (accumulator)
    logic [31:0] divisor_ff;                   // делитель (divisor)

    logic [31:0] result_ff;

    // записать модуль операндов
    always_comb begin
        if ((cmd_i[0] == 1'b0) && op1_i[31]) begin
            abs_a = -op1_i;
        end
        else begin
            abs_a = op1_i;
        end
        if ((cmd_i[0] == 1'b0) && op2_i[31]) begin
            abs_b = -op2_i;
        end
        else begin
            abs_b = op2_i;
        end
    end

    logic [63:0] shifted;
    logic [31:0] sub_result;

    assign shifted    = {part_rem_ff[30:0], accum_ff, 1'b0};   // {part_rem, accum} << 1
    assign sub_result = shifted[63:32] - divisor_ff;      // проба: новый part_rem минус divisor

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_ff     <= IDLE;
            cmd_ff       <= 2'b0;
            op1_ff       <= WIDTH'(0);
            op2_ff       <= WIDTH'(0);
            count_ff     <= 6'b0;
            sign_quot_ff <= 1'b0;
            sign_rem_ff  <= 1'b0;
            part_rem_ff  <= WIDTH'(0);
            accum_ff     <= WIDTH'(0);
            divisor_ff   <= WIDTH'(0);
            result_ff    <= WIDTH'(0);
        end
        else begin
            case (state_ff)
                IDLE: begin
                    if (valid_i) begin
                        op1_ff   <= op1_i;
                        op2_ff   <= op2_i;
                        cmd_ff   <= cmd_i;
                        count_ff <= 6'b0;

                        // Проверка деления на 0
                        if (op2_i == WIDTH'(0)) begin
                            state_ff <= DONE;
                            if (cmd_i == 2'b00) begin // div
                                result_ff <= -1;
                            end
                            else if (cmd_i == 2'b01) begin // divu
                                result_ff <= {WIDTH{1'b1}};
                            end
                            else begin // rem, remu
                                result_ff <= op1_i;
                            end
                        end
                        // Переполнение: INT_MIN / -1
                        else if (cmd_i == 2'b00 && op1_i == {1'b1, {(WIDTH-1){1'b0}}} && op2_i == {WIDTH{1'b1}}) 
                        begin
                            state_ff  <= DONE;
                            result_ff <= {1'b1, {(WIDTH-1){1'b0}}}; // DIV
                        end
                        else if (cmd_i == 2'b10 && op1_i == {1'b1, {(WIDTH-1){1'b0}}} && op2_i == {WIDTH{1'b1}}) 
                        begin
                            state_ff  <= DONE;
                            result_ff <= WIDTH'(0);                 // REM
                        end
                        // Обычное деление: |op|, знаки отдельно, 32 шага в CALC
                        else begin
                            if (cmd_i[0] == 1'b0) begin
                                sign_quot_ff <= op1_i[31] ^ op2_i[31];
                                sign_rem_ff  <= op1_i[31];
                            end
                            else begin
                                sign_quot_ff <= 1'b0;
                                sign_rem_ff  <= 1'b0;
                            end
                            accum_ff     <= abs_a;
                            divisor_ff   <= abs_b;
                            part_rem_ff  <= WIDTH'(0);
                            state_ff <= CALC;
                        end
                    end
                end

                // 32 шага: один бит частного за такт
                CALC: begin
                    if (count_ff == 6'd32) begin
                        state_ff <= DONE;

                        // Вернуть знаки: accum = |частное|, part_rem = |остаток|
                        if (sign_quot_ff) begin
                            quot = -accum_ff;
                        end
                        else begin
                            quot = accum_ff;
                        end

                        if (sign_rem_ff) begin
                            rem = -part_rem_ff;
                        end
                        else begin
                            rem = part_rem_ff;
                        end

                        if (cmd_ff[1] == 1'b0) begin // DIV / DIVU
                            result_ff <= quot;
                        end
                        else begin // REM / REMU
                            result_ff <= rem;
                        end
                    end
                    else begin
                        count_ff <= count_ff + 1'b1;
                        // Разность < 0: делитель не влез, вернуть part_rem, бит частного 0
                        if (sub_result[31] == 1'b1) begin
                            part_rem_ff <= shifted[63:32];
                            accum_ff <= {shifted[31:1], 1'b0};
                        end
                        // Разность >= 0: принять part_rem - divisor, бит частного 1
                        else begin
                            part_rem_ff <= sub_result;
                            accum_ff <= {shifted[31:1], 1'b1};
                        end
                    end
                end

                DONE: begin
                    state_ff <= IDLE;
                end

                default: state_ff <= IDLE;
            endcase
        end
    end

    assign done_o   = (state_ff == DONE);
    assign result_o = result_ff;

endmodule

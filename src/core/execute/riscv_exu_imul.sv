// riscv_exu_imul.sv: Целочисленный умножитель
// MUL/MULH/MULHSU/MULHU: умножение разложением на частичные суммы и сложение log4 N, конвейер valid

import riscv_pkg::*;

module riscv_exu_imul (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_i,
    input  logic [1:0]  cmd_i,                 // 00: MUL, 01: MULH, 10: MULHSU, 11: MULHU
    input  logic [31:0] op1_i,
    input  logic [31:0] op2_i,

    output logic [31:0] result_o,
    output logic        done_o                // Результат готов (valid на выходе, 1 такт)
);

    // Конвейер valid: valid_i -> valid_stage0  -> valid_stage1  -> valid_stage2 -> done_o
    // Конвейер cmd:   cmd_i   -> cmd_stage0_ff -> cmd_stage1_ff -> cmd_stage2_ff
    // Стадия 0: (partial_product) кол-во частичных сумм 33 -> 9 (sum0_raw)
    // Стадия 1: (stage1_r) кол-во частичных сумм 9 -> 3 (sum1_raw)
    // Стадия 2: (stage2_r) кол-во частичных сумм 3 -> 1 (sum2_raw)
    // Стадия 3: sum2_raw -> result_ff

    logic        valid_stage0_ff;
    logic        valid_stage1_ff;
    logic        valid_stage2_ff;

    logic [1:0]  cmd_stage0_ff;
    logic [1:0]  cmd_stage1_ff;
    logic [1:0]  cmd_stage2_ff;

    logic [31:0] op1_stage0_ff;     // Операнды держатся до следующего valid_i
    logic [31:0] op2_stage0_ff;

    logic [31:0] result_ff;

    // Расширение опреандов
    logic signed [32:0] a_val;
    logic signed [32:0] b_val;

    always_comb begin
        // Операнд a: unsigned только для MULHU (cmd == 11)
        if (cmd_stage0_ff == 2'b11) begin
            a_val = $signed({1'b0, op1_stage0_ff});
        end
        else begin
            a_val = $signed({op1_stage0_ff[31], op1_stage0_ff});
        end

        // Операнд b: unsigned для MULHSU/MULHU (cmd == 10 || cmd == 11)
        if (cmd_stage0_ff[1] == 1) begin
            b_val = $signed({1'b0, op2_stage0_ff});
        end
        else begin
            b_val = $signed({op2_stage0_ff[31], op2_stage0_ff});
        end
    end

    // Частичные произведения
    logic signed [65:0] a_ext66;
    logic signed [65:0] b_ext66;
    assign a_ext66 = {{33{a_val[32]}}, a_val};
    assign b_ext66 = {{33{b_val[32]}}, b_val};

    logic signed [65:0] partial_product[32:0];
    always_comb begin
        for (int i = 0; i < 32; i++) begin
            if (b_ext66[i]) begin
                partial_product[i] = a_ext66 << i;
            end
            else begin
                partial_product[i] = 66'sb0;
            end
        end
        if (b_ext66[32]) begin
            partial_product[32] = (-a_ext66) << 32;
        end
        else begin
            partial_product[32] = 66'sb0;
        end
    end


    // Стадия 0: кол-во частичных сумм 33 -> 9
    logic [65:0] sum0_int[15:0];    // partial_product + partial_product = int
    logic [65:0] sum0_raw[8:0];     // int + int = raw (типо intermediate, то есть промежуточный)

    // Группа 0 (partial_product[0], ... , partial_product[3])
    adder #(.WIDTH(66)) add0_0 (.a_i(partial_product[0]), .b_i(partial_product[1]), .sum_o(sum0_int[0]));
    adder #(.WIDTH(66)) add0_1 (.a_i(partial_product[2]), .b_i(partial_product[3]), .sum_o(sum0_int[1]));
    adder #(.WIDTH(66)) add0_2 (.a_i(sum0_int[0]),        .b_i(sum0_int[1]),        .sum_o(sum0_raw[0]));

    // Группа 1 (partial_product[4], ... , partial_product[7])
    adder #(.WIDTH(66)) add1_0 (.a_i(partial_product[4]), .b_i(partial_product[5]), .sum_o(sum0_int[2]));
    adder #(.WIDTH(66)) add1_1 (.a_i(partial_product[6]), .b_i(partial_product[7]), .sum_o(sum0_int[3]));
    adder #(.WIDTH(66)) add1_2 (.a_i(sum0_int[2]),        .b_i(sum0_int[3]),        .sum_o(sum0_raw[1]));

    // Группа 2 (partial_product[8], ... , partial_product[11])
    adder #(.WIDTH(66)) add2_0 (.a_i(partial_product[8]),  .b_i(partial_product[9]),  .sum_o(sum0_int[4]));
    adder #(.WIDTH(66)) add2_1 (.a_i(partial_product[10]), .b_i(partial_product[11]), .sum_o(sum0_int[5]));
    adder #(.WIDTH(66)) add2_2 (.a_i(sum0_int[4]),         .b_i(sum0_int[5]),         .sum_o(sum0_raw[2]));

    // Группа 3 (partial_product[12], ... , partial_product[15])
    adder #(.WIDTH(66)) add3_0 (.a_i(partial_product[12]), .b_i(partial_product[13]), .sum_o(sum0_int[6]));
    adder #(.WIDTH(66)) add3_1 (.a_i(partial_product[14]), .b_i(partial_product[15]), .sum_o(sum0_int[7]));
    adder #(.WIDTH(66)) add3_2 (.a_i(sum0_int[6]),         .b_i(sum0_int[7]),         .sum_o(sum0_raw[3]));

    // Группа 4 (partial_product[16], ... , partial_product[19])
    adder #(.WIDTH(66)) add4_0 (.a_i(partial_product[16]), .b_i(partial_product[17]), .sum_o(sum0_int[8]));
    adder #(.WIDTH(66)) add4_1 (.a_i(partial_product[18]), .b_i(partial_product[19]), .sum_o(sum0_int[9]));
    adder #(.WIDTH(66)) add4_2 (.a_i(sum0_int[8]),         .b_i(sum0_int[9]),         .sum_o(sum0_raw[4]));

    // Группа 5 (partial_product[20], ... , partial_product[23])
    adder #(.WIDTH(66)) add5_0 (.a_i(partial_product[20]), .b_i(partial_product[21]), .sum_o(sum0_int[10]));
    adder #(.WIDTH(66)) add5_1 (.a_i(partial_product[22]), .b_i(partial_product[23]), .sum_o(sum0_int[11]));
    adder #(.WIDTH(66)) add5_2 (.a_i(sum0_int[10]),        .b_i(sum0_int[11]),        .sum_o(sum0_raw[5]));

    // Группа 6 (partial_product[24], ... , partial_product[27])
    adder #(.WIDTH(66)) add6_0 (.a_i(partial_product[24]), .b_i(partial_product[25]), .sum_o(sum0_int[12]));
    adder #(.WIDTH(66)) add6_1 (.a_i(partial_product[26]), .b_i(partial_product[27]), .sum_o(sum0_int[13]));
    adder #(.WIDTH(66)) add6_2 (.a_i(sum0_int[12]),        .b_i(sum0_int[13]),        .sum_o(sum0_raw[6]));

    // Группа 7 (partial_product[28], ... , partial_product[31])
    adder #(.WIDTH(66)) add7_0 (.a_i(partial_product[28]), .b_i(partial_product[29]), .sum_o(sum0_int[14]));
    adder #(.WIDTH(66)) add7_1 (.a_i(partial_product[30]), .b_i(partial_product[31]), .sum_o(sum0_int[15]));
    adder #(.WIDTH(66)) add7_2 (.a_i(sum0_int[14]),        .b_i(sum0_int[15]),        .sum_o(sum0_raw[7]));

    assign sum0_raw[8] = partial_product[32];

    logic [65:0] stage1_r[8:0];

    // Стадия 1: кол-во частичных сумм 9 -> 3
    logic [65:0] sum1_int[3:0];  // stage1_r + stage1_r = int
    logic [65:0] sum1_raw[2:0];  // int + int = raw

    adder #(.WIDTH(66)) add1_g0_0 (.a_i(stage1_r[0]), .b_i(stage1_r[1]), .sum_o(sum1_int[0]));
    adder #(.WIDTH(66)) add1_g0_1 (.a_i(stage1_r[2]), .b_i(stage1_r[3]), .sum_o(sum1_int[1]));
    adder #(.WIDTH(66)) add1_g0_2 (.a_i(sum1_int[0]), .b_i(sum1_int[1]), .sum_o(sum1_raw[0]));

    adder #(.WIDTH(66)) add1_g1_0 (.a_i(stage1_r[4]), .b_i(stage1_r[5]), .sum_o(sum1_int[2]));
    adder #(.WIDTH(66)) add1_g1_1 (.a_i(stage1_r[6]), .b_i(stage1_r[7]), .sum_o(sum1_int[3]));
    adder #(.WIDTH(66)) add1_g1_2 (.a_i(sum1_int[2]), .b_i(sum1_int[3]), .sum_o(sum1_raw[1]));

    assign sum1_raw[2] = stage1_r[8];

    logic [65:0] stage2_r[2:0];

    // Стадия 2: кол-во частичных сумм 3 -> 1
    logic [65:0] sum2_int;  // stage2_r + stage2_r = int
    logic [65:0] sum2_raw;  // int + int = raw

    adder #(.WIDTH(66)) add2_sum0 (.a_i(stage2_r[0]), .b_i(stage2_r[1]), .sum_o(sum2_int));
    adder #(.WIDTH(66)) add2_sum1 (.a_i(sum2_int), .b_i(stage2_r[2]), .sum_o(sum2_raw));


    // Сдвиг конвейера валидности
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage0_ff <= 1'b0;
            valid_stage1_ff <= 1'b0;
            valid_stage2_ff <= 1'b0;
            done_o          <= 1'b0;
        end
        else begin
            // Стадия 0: принять valid
            valid_stage0_ff <= valid_i;
            if (valid_i) begin
                cmd_stage0_ff  <= cmd_i;
                op1_stage0_ff <= op1_i;
                op2_stage0_ff <= op2_i;
            end

            // Стадия 1: sum0_raw -> stage1_r, valid и cmd дальше
            valid_stage1_ff <= valid_stage0_ff;
            cmd_stage1_ff    <= cmd_stage0_ff;
            for (int i = 0; i < 9; i++) begin
                stage1_r[i] <= sum0_raw[i];
            end

            // Стадия 2: sum1_raw -> stage2_r
            valid_stage2_ff <= valid_stage1_ff;
            cmd_stage2_ff    <= cmd_stage1_ff;
            for (int i = 0; i < 3; i++) begin
                stage2_r[i] <= sum1_raw[i];
            end

            // Стадия 3 (выход): valid_stage2 -> done, выбрать половину sum2_raw
            done_o <= valid_stage2_ff;
            if (valid_stage2_ff) begin
                case (cmd_stage2_ff)
                    2'b00:   result_ff <= sum2_raw[31:0];   // MUL
                    2'b01:   result_ff <= sum2_raw[63:32];  // MULH
                    2'b10:   result_ff <= sum2_raw[63:32];  // MULHSU
                    2'b11:   result_ff <= sum2_raw[63:32];  // MULHU
                    default: result_ff <= WIDTH'(0);
                endcase
            end
        end
    end

    assign result_o = result_ff;


endmodule

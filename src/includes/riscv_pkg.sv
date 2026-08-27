// riscv_pkg.sv: Конфиг, константы, типы

package riscv_pkg;

    // Параметры
    parameter int WIDTH     = 32;
    parameter int IMEM_SIZE = 16384; // words
    parameter int DMEM_SIZE = 16384; // words
    parameter     IMEM_FILE = "program.hex";
    parameter     DMEM_FILE = "data.hex";


    // Типы данных
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        CALC = 2'b01,
        DONE = 2'b10
    } state_e;

    typedef enum logic [6:0] {
        OP_R      = 7'b0110011,
        OP_I_ALU  = 7'b0010011,
        OP_LOAD   = 7'b0000011,
        OP_STORE  = 7'b0100011,
        OP_BRANCH = 7'b1100011,
        OP_LUI    = 7'b0110111,
        OP_AUIPC  = 7'b0010111,
        OP_JAL    = 7'b1101111,
        OP_JALR   = 7'b1100111
    } opcode_e;

    typedef enum logic [4:0] {
        ALU_ADD    = 5'b00000,
        ALU_SUB    = 5'b00001,
        ALU_AND    = 5'b00010,
        ALU_OR     = 5'b00011,
        ALU_XOR    = 5'b00100,
        ALU_SLL    = 5'b00101,
        ALU_SRL    = 5'b00110,
        ALU_SRA    = 5'b00111,
        ALU_SLT    = 5'b01000,
        ALU_SLTU   = 5'b01001,

        ALU_MUL    = 5'b10000,
        ALU_MULH   = 5'b10001,
        ALU_MULHSU = 5'b10010,
        ALU_MULHU  = 5'b10011,
        ALU_DIV    = 5'b10100,
        ALU_DIVU   = 5'b10101,
        ALU_REM    = 5'b10110,
        ALU_REMU   = 5'b10111,

        ALU_NOP    = 5'b11111
    } exu_ctrl_e;

    typedef enum logic [1:0] {
        EXU_OP_LOAD_STORE = 2'b00,
        EXU_OP_BRANCH     = 2'b01,
        EXU_OP_R          = 2'b10,
        EXU_OP_I          = 2'b11
    } exu_op_e;

endpackage

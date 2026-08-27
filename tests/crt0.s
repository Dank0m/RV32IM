    .text
    .globl  _start
    .option nopic
    .option norvc

_start:
    lui     sp, 0x20
    jal     ra, main
    lui     t0, 0x10
    sw      a0, 0(t0)
    lui     t1, 0x600dc
    addi    t1, t1, 0x0de
    sw      t1, 12(t0)
1:
    jal     zero, 1b

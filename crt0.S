    .section .text.init
    .globl _start
_start:
    la   sp, _stack_top
    call main
    li   t0, 0x10000008
    sw   a0, 0(t0)          # exit(a0)
1:  j    1b
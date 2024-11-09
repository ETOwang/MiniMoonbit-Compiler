.data:

.text:
.global minimbt_main
minimbt_main:
  addi sp, sp, -24
  li t0, 123
  sw t0, 0(sp)
  lw a0, 0(sp)
  call minimbt_print_int
  li t1, 456
  sw t1, 8(sp)
  lw t2, 8(sp)
  neg t2, t2
  sw t2, 4(sp)
  lw a0, 4(sp)
  call minimbt_print_int
  li t3, 789
  sw t3, 16(sp)
  li t4, 0
  sw t4, 20(sp)
  lw t5, 16(sp)
  lw t0, 20(sp)
  add t5, t5, t0
  sw t5, 12(sp)
  lw a0, 12(sp)
  call minimbt_print_int
  addi sp, sp, 24
  ret


.global minimbt_main
minimbt_main:
  addi sp, sp, -104
  li t0, 12.3
  sw t0, 0(sp)
  fld ft0, 0(sp)
  fneg.d ft0, ft0
  fmv.d.x ft0, t0
  sw t0, 0(sp)
  fld fa0, 0(sp)
  call minimbt_abs_float
  sw a0, 0(sp)
  fld fa0, 0(sp)
  call minimbt_sqrt
  sw a0, 0(sp)
  fld fa0, 0(sp)
  call minimbt_cos
  sw a0, 0(sp)
  fld fa0, 0(sp)
  call minimbt_sin
  sw a0, 0(sp)
  li t0, 4.5
  sw t0, 0(sp)
  fld ft0, 0(sp)
  fld ft1, 0(sp)
  fadd.d ft0, ft0, ft1
  fmv.d.x ft0, t0
  sw t0, 0(sp)
  li t0, 6.7
  sw t0, 0(sp)
  li t0, 8.9
  sw t0, 0(sp)
  fld ft0, 0(sp)
  fld ft1, 0(sp)
  fmul.d ft0, ft0, ft1
  fmv.d.x ft0, t0
  sw t0, 0(sp)
  li t0, 1.23456789
  sw t0, 0(sp)
  fld ft0, 0(sp)
  fld ft1, 0(sp)
  fdiv.d ft0, ft0, ft1
  fmv.d.x ft0, t0
  sw t0, 0(sp)
  fld ft0, 0(sp)
  fld ft1, 0(sp)
  fsub.d ft0, ft0, ft1
  fmv.d.x ft0, t0
  sw t0, 0(sp)
  li t0, 1000000
  sw t0, 0(sp)
  ld a0, 0(sp)
  call minimbt_float_of_int
  sw a0, 0(sp)
  fld ft0, 0(sp)
  fld ft1, 0(sp)
  fmul.d ft0, ft0, ft1
  fmv.d.x ft0, t0
  sw t0, 0(sp)
  fld fa0, 0(sp)
  call minimbt_int_of_float
  sw a0, 0(sp)
  ld a0, 0(sp)
  call minimbt_print_int
  addi sp, sp, 104


pub struct RegAllocator {
  available_regs : Array[Reg] // 可用寄存器
  available_fregs : Array[FReg]
  used_regs : @immut/hashmap.T[@typing.Name, Reg] // 已使用的寄存器
  stack : @hashmap.T[@typing.Name, Int] // 存储溢出时的寄存器和变量信息
  stack_offset : Int // 栈偏移量，表示当前栈的位置
}

let regAllocator : RegAllocator = {
  available_regs: reg_allocatable_list,
  available_fregs: freg_allocatable_list,
  used_regs: @immut/hashmap.new(),
  stack: @hashmap.new(),
  stack_offset: 0,
}

let riscvs : Array[RvAsm] = Array::new()

pub struct InputFunction {
  name : String
  export : Bool
  instructions : Array[RvAsm]
}

fn preProcess(body : @closure.Expr) -> Int {
  let mut res = 0
  match body {
    Let(lhs, rhs, rest) => {
      match lhs.1 {
        Unit => res += 0
        Int | Bool => {
          regAllocator.stack[lhs.0] = res
          res += 4
        }
        _ => {
          regAllocator.stack[lhs.0] = res
          res += 8
        }
      }
      res += preProcess(rhs)
      res += preProcess(rest)
    }
    LetTuple(lhs, _, rest) => {
      for variable in lhs {
        match variable.1 {
          Unit => res += 0
          Int | Bool => {
            regAllocator.stack[variable.0] = res
            res += 4
          }
          _ => {
            regAllocator.stack[variable.0] = res
            res += 8
          }
        }
      }
      res += preProcess(rest)
    }
    // TODO Array
    _ => ()
  }
  res
}

fn processInstruction(
  expr : @closure.Expr,
  reg_allocator : RegAllocator
) -> Reg {
  match expr {
    Add(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Add(T0, T0, T1))
      T0
    }
    Sub(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Sub(T0, T0, T1))
      T0
    }
    Mul(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Mul(T0, T0, T1))
      T0
    }
    Div(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Div(T0, T0, T1))
      T0
    }
    FAdd(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Fld(Ft0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Fld(Ft1, rhs_memAccess))
      riscvs.push(FaddD(Ft0, Ft0, Ft1))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    FSub(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Fld(Ft0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Fld(Ft1, rhs_memAccess))
      riscvs.push(FsubD(Ft0, Ft0, Ft1))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    FMul(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Fld(Ft0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Fld(Ft1, rhs_memAccess))
      riscvs.push(FmulD(Ft0, Ft0, Ft1))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    FDiv(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Fld(Ft0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Fld(Ft1, rhs_memAccess))
      riscvs.push(FdivD(Ft0, Ft0, Ft1))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    Neg(var) => {
      let var_location = reg_allocator.stack[var]
      let var_memAccess = { base: Sp, offset: var_location.unwrap() }
      riscvs.push(Lw(T0, var_memAccess))
      riscvs.push(Neg(T0, T0))
      T0
    }
    FNeg(var) => {
      let var_location = reg_allocator.stack[var]
      let var_memAccess = { base: Sp, offset: var_location.unwrap() }
      riscvs.push(Fld(Ft0, var_memAccess))
      riscvs.push(FnegD(Ft0, Ft0))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    Let((var, _), rhs, rest) => {
      let rhs_reg = processInstruction(rhs, reg_allocator)
      let var_memAccess = {
        base: Sp,
        offset: reg_allocator.stack[var].unwrap(),
      }
      riscvs.push(Sw(rhs_reg, var_memAccess))
      processInstruction(rest, reg_allocator)
    }
    IfEq(lhs, rhs, then, els) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Beq(T0, T1, "else"))
      let _ = processInstruction(then, reg_allocator)
      riscvs.push(J("end"))
      riscvs.push(Label("else"))
      let elseResult = processInstruction(els, reg_allocator)
      riscvs.push(Label("end"))
      elseResult
    }
    IfLe(lhs, rhs, then, els) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Blt(T0, T1, "else"))
      let _ = processInstruction(then, reg_allocator)
      riscvs.push(J("end"))
      riscvs.push(Label("else"))
      let elseResult = processInstruction(els, reg_allocator)
      riscvs.push(Label("end"))
      elseResult
    }
    Var(var) => {
      let var_location = reg_allocator.stack[var]
      if var_location.is_empty() {
        let var_reg = reg_allocator.used_regs[var].unwrap()
        var_reg
      } else {
        let var_memAccess = { base: Sp, offset: var_location.unwrap() }
        riscvs.push(Ld(T0, var_memAccess))
        T0
      }
    }
    // assume this is a double array
    ArrayGet(arr, idx) => {
      let arr_location = reg_allocator.stack[arr]
      let arr_memAccess = { base: Sp, offset: arr_location.unwrap() }
      riscvs.push(Ld(T0, arr_memAccess))
      let idx_location = reg_allocator.stack[idx]
      let idx_memAccess = { base: Sp, offset: idx_location.unwrap() }
      riscvs.push(Ld(T1, idx_memAccess))
      riscvs.push(Add(T0, T0, T1))
      let element_location = { base: T0, offset: 0 }
      riscvs.push(Ld(T0, element_location))
      T0
    }
    ArrayPut(arr, idx, value) => {
      let arr_location = reg_allocator.stack[arr]
      let arr_memAccess = { base: Sp, offset: arr_location.unwrap() }
      riscvs.push(Ld(T0, arr_memAccess))
      let idx_location = reg_allocator.stack[idx]
      let idx_memAccess = { base: Sp, offset: idx_location.unwrap() }
      riscvs.push(Ld(T1, idx_memAccess))
      riscvs.push(Add(T0, T0, T1))
      let value_location = reg_allocator.stack[value]
      let value_memAccess = { base: Sp, offset: value_location.unwrap() }
      riscvs.push(Ld(T1, value_memAccess))
      let element_location = { base: T0, offset: 0 }
      riscvs.push(Sd(T1, element_location))
      T1
    }
    CallDirect(label, args) => {
      //TODO:Double
      for index = 0; index < args.length(); index = index + 1 {
        let arg = args[index]
        let arg_location = reg_allocator.stack[arg]
        let arg_memAccess = { base: Sp, offset: arg_location.unwrap() }
        riscvs.push(Lw(reg_arg_list[index], arg_memAccess))
      }
      riscvs.push(Call(label.to_string()))
      reg_ret
    }
  }
}

fn processFunction(
  funtion : @closure.FuncDef,
  reg_allocator : RegAllocator
) -> AssemblyFunction {
  let res = if funtion.name.to_string() == "minimbt_main" {
    { name: funtion.name.to_string(), export: true, body: Array::new() }
  } else {
    { name: funtion.name.to_string(), export: false, body: Array::new() }
  }
  let stackSize : Int = preProcess(funtion.body)
  res.body.push(Addi(Sp, Sp, -stackSize))
  let _ = processInstruction(funtion.body, reg_allocator)
  for asm in riscvs {
    res.body.push(asm)
  }
  res.body.push(Addi(Sp, Sp, stackSize))
  riscvs.clear()
  res
}

pub struct AssemblyFunction {
  name : String
  export : Bool
  body : Array[RvAsm]
}

pub fn AssemblyFunction::output(
  self : AssemblyFunction,
  logger : Logger
) -> Unit {
  let name = self.name
  if self.export {
    logger.write_string(".global \{name}\n")
  }
  logger.write_string("\{name}:\n")
  for asm in self.body {
    Show::output(asm, logger)
    logger.write_string("\n")
  }
}

pub fn emit(input : @closure.Program) -> Array[AssemblyFunction] {
  let res = Array::new()
  res.push({ name: "minimbt_read_int", export: true, body: Array::new() })
  res.push({ name: "minimbt_print_int", export: true, body: Array::new() })
  res.push({ name: "minimbt_read_char", export: true, body: Array::new() })
  res.push({ name: "minimbt_print_char", export: true, body: Array::new() })
  res.push({ name: "minimbt_print_endline", export: true, body: Array::new() })
  res.push({ name: "minimbt_int_of_float", export: true, body: Array::new() })
  res.push({ name: "minimbt_float_of_int", export: true, body: Array::new() })
  res.push({ name: "minimbt_truncate", export: true, body: Array::new() })
  res.push({ name: "minimbt_floor", export: true, body: Array::new() })
  res.push({ name: "minimbt_abs_float", export: true, body: Array::new() })
  res.push({ name: "minimbt_sqrt", export: true, body: Array::new() })
  res.push({ name: "minimbt_sin", export: true, body: Array::new() })
  res.push({ name: "minimbt_cos", export: true, body: Array::new() })
  res.push({ name: "minimbt_atan", export: true, body: Array::new() })
  res.push({ name: "minimbt_malloc", export: true, body: Array::new() })
  res.push({ name: "minimbt_create_array", export: true, body: Array::new() })
  res.push(
    { name: "minimbt_create_float_array", export: true, body: Array::new() },
  )
  res.push(
    { name: "minimbt_create_ptr_array", export: true, body: Array::new() },
  )
  for fun in input.fundefs {
    res.push(processFunction(fun, regAllocator))
  }
  res
}

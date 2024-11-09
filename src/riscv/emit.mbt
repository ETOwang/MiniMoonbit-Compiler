pub struct RegAllocator {
  available_regs : Array[Reg] // 可用寄存器
  available_fregs : Array[FReg]
  used_regs : @hashmap.T[@types.Name, Reg] // 已使用的寄存器
  used_fregs : @hashmap.T[@types.Name, FReg] // 已使用的寄存器
  stack : @hashmap.T[@types.Name, Int] // 存储溢出时的寄存器和变量信息
  mut stack_offset : Int // 栈偏移量，表示当前栈的位置
  mut temp_index : Int
}

pub let extenv : Map[String, @types.Type] = {
  "minimbt_read_int": Int,
  "minimbt_print_int": Unit,
  "minimbt_read_char": Int,
  "minimbt_print_char": Unit,
  "minimbt_print_newline": Unit,
  "minimbt_create_array": @types.Type::Array(Int),
  "minimbt_create_float_array": @types.Type::Array(Double),
  "minimbt_create_ptr_array": @types.Type::Array(Ptr),
  "minimbt_truncate": Int,
  "minimbt_sin": Double,
  "minimbt_cos": Double,
  "minimbt_sqrt": Double,
  "minimbt_abs_float": Double,
  "minimbt_int_of_float": Int,
  "minimbt_float_of_int": Double,
  "minimbt_atan": Double,
  "minimbt_floor": Double,
}

let riscvs : Array[RvAsm] = Array::new()

let varTable : @hashmap.T[@types.Name, @closure.LowType] = @hashmap.new()

let closureTable : @hashmap.T[String, @closure.FuncDef] = @hashmap.new()

let asmData : Array[(String, Double)] = Array::new()

let counter : Array[Int] = Array::new()

let end_counter : Array[Int] = Array::new()

let if_counter : Array[Int] = Array::new()

let else_counter : Array[Int] = Array::new()

let registerTable : @hashmap.T[String, RegAllocator] = @hashmap.new()

fn create_label_else() -> String {
  let temp = "else_" + else_counter[0].to_string()
  else_counter[0] += 1
  temp
}

fn create_label_end() -> String {
  let temp = "end_" + end_counter[0].to_string()
  end_counter[0] += 1
  temp
}

fn create_label_if() -> String {
  let temp = "if_" + if_counter[0].to_string()
  if_counter[0] += 1
  temp
}

fn preProcess(body : @closure.Expr, regAllocator : RegAllocator) -> Int {
  let mut res = 0
  match body {
    Let(lhs, rhs, rest) => {
      match lhs.1 {
        Unit => res += 0
        Int | Bool => {
          regAllocator.stack[lhs.0] = regAllocator.stack_offset
          regAllocator.stack_offset += 4
          res += 4
        }
        _ => {
          regAllocator.stack[lhs.0] = regAllocator.stack_offset
          regAllocator.stack_offset += 8
          res += 8
        }
      }
      res += preProcess(rhs, regAllocator)
      res += preProcess(rest, regAllocator)
    }
    LetTuple(lhs, _, rest) => {
      for variable in lhs {
        match variable.1 {
          Unit => res += 0
          Int | Bool => {
            regAllocator.stack[variable.0] = regAllocator.stack_offset
            regAllocator.stack_offset += 4
            res += 4
          }
          _ => {
            regAllocator.stack[variable.0] = regAllocator.stack_offset
            regAllocator.stack_offset += 8
            res += 8
          }
        }
      }
      res += preProcess(rest, regAllocator)
    }
    // TODO Array
    _ => ()
  }
  res
}

fn prepareOperands(
  lhs : @types.Name,
  rhs : @types.Name,
  reg_allocator : RegAllocator
) -> (Reg, Reg) {
  let lhs_location = reg_allocator.stack[lhs]
  let rhs_location = reg_allocator.stack[rhs]
  let mut reg1 = prepareTempReg(reg_allocator)
  let mut reg2 = prepareTempReg(reg_allocator)
  if lhs_location.is_empty() {
    reg1 = reg_allocator.used_regs[lhs].unwrap()
  } else {
    let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
    riscvs.push(Lw(reg1, lhs_memAccess))
  }
  if rhs_location.is_empty() {
    reg2 = reg_allocator.used_regs[rhs].unwrap()
  } else {
    let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
    riscvs.push(Lw(reg2, rhs_memAccess))
  }
  (reg1, reg2)
}

fn prepareFOperands(
  lhs : @types.Name,
  rhs : @types.Name,
  reg_allocator : RegAllocator
) -> (FReg, FReg) {
  let mut reg1 = Ft0
  let mut reg2 = Ft1
  let lhs_location = reg_allocator.stack[lhs]
  let rhs_location = reg_allocator.stack[rhs]
  if lhs_location.is_empty() {
    reg1 = reg_allocator.used_fregs[lhs].unwrap()
  } else {
    let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
    riscvs.push(Fld(Ft0, lhs_memAccess))
  }
  if rhs_location.is_empty() {
    reg2 = reg_allocator.used_fregs[rhs].unwrap()
  } else {
    let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
    riscvs.push(Fld(Ft1, rhs_memAccess))
  }
  (reg1, reg2)
}

fn prepareArgs(args : Array[@types.Name], reg_allocator : RegAllocator) -> Unit {
  let mut regIndex = 0
  let mut fregIndex = 0
  for index = 0; index < args.length(); index = index + 1 {
    let arg = args[index]
    let arg_location = reg_allocator.stack[arg]
    let arg_memAccess = { base: Sp, offset: arg_location.unwrap() }
    let arg_type = varTable[arg]
    match arg_type.unwrap() {
      Int(_) => {
        reg_allocator.used_regs[arg] = reg_arg_list[regIndex]
        riscvs.push(Lw(reg_arg_list[regIndex], arg_memAccess))
        regIndex += 1
      }
      Double(_) => {
        reg_allocator.used_fregs[arg] = freg_arg_list[fregIndex]
        riscvs.push(Fld(freg_arg_list[fregIndex], arg_memAccess))
        fregIndex += 1
      }
      _ => {
        reg_allocator.used_regs[arg] = reg_arg_list[regIndex]
        riscvs.push(Ld(reg_arg_list[regIndex], arg_memAccess))
        regIndex += 1
      }
    }
  }
}

fn prepareTempReg(reg_allocator : RegAllocator) -> Reg {
  let temp_reg = reg_temp_list[reg_allocator.temp_index]
  reg_allocator.temp_index += 1
  reg_allocator.temp_index %= reg_temp_list.length()
  temp_reg
}

fn processInstruction(
  expr : @closure.Expr,
  reg_allocator : RegAllocator
) -> Reg {
  match expr {
    //TODO
    Unit => T0
    MakeTuple(vars) => {
      let mut res = 0
      for var in vars {
        let var_location = reg_allocator.stack[var]
        let var_memAccess = { base: Sp, offset: var_location.unwrap() }
        riscvs.push(Ld(T0, var_memAccess))
        let tuple_location = { base: Sp, offset: res }
        riscvs.push(Sd(T0, tuple_location))
        res += 4
      }
      T0
    }
    LetTuple(vars, _, rest) => {
      for var in vars {
        let var_location = reg_allocator.stack[var.0]
        let var_memAccess = { base: Sp, offset: var_location.unwrap() }
        riscvs.push(Ld(T0, var_memAccess))
        let tuple_location = { base: Sp, offset: 0 }
        riscvs.push(Sd(T0, tuple_location))
      }
      processInstruction(rest, reg_allocator)
    }
    MakeClosure((var, _), closure, rest) => {
      let funcdef = closureTable[closure.name._].unwrap()
      let free_vars = funcdef.formal_free_vars
      for fv in free_vars {
        let fv_location = reg_allocator.stack[fv.0]
        let fv_memAccess = { base: Sp, offset: fv_location.unwrap() }
        riscvs.push(Ld(T0, fv_memAccess))
        let fv_location = { base: Sp, offset: 0 }
        riscvs.push(Sd(T0, fv_location))
      }
      let closure_location = { base: Sp, offset: 0 }
      riscvs.push(Sd(T0, closure_location))
      processInstruction(rest, reg_allocator)
    }
    ExternalArray(label) => {
      let label_location = { base: Sp, offset: 0 }
      riscvs.push(La(T0, label._))
      riscvs.push(Sd(T0, label_location))
      T0
    }
    //TODO
    Int(value) => {
      let reg = prepareTempReg(reg_allocator)
      riscvs.push(Li(reg, value.to_string()))
      reg
    }
    Double(value) => {
      asmData.push(("double_" + counter[0].to_string(), value))
      let reg = prepareTempReg(reg_allocator)
      riscvs.push(La(reg, "double_" + counter[0].to_string()))
      riscvs.push(Fld(Ft0, { base: reg, offset: 0 }))
      riscvs.push(FmvDX(Ft0, reg))
      counter[0] += 1
      reg
    }
    Add(lhs, rhs) => {
      let (reg1, reg2) = prepareOperands(lhs, rhs, reg_allocator)
      riscvs.push(Add(reg1, reg1, reg2))
      reg1
    }
    Sub(lhs, rhs) => {
      let (reg1, reg2) = prepareOperands(lhs, rhs, reg_allocator)
      riscvs.push(Sub(reg1, reg1, reg2))
      reg1
    }
    Mul(lhs, rhs) => {
      let (reg1, reg2) = prepareOperands(lhs, rhs, reg_allocator)
      riscvs.push(Mul(reg1, reg1, reg2))
      reg1
    }
    Div(lhs, rhs) => {
      let (reg1, reg2) = prepareOperands(lhs, rhs, reg_allocator)
      riscvs.push(Div(reg1, reg1, reg2))
      T0
    }
    FAdd(lhs, rhs) => {
      let temp = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareFOperands(lhs, rhs, reg_allocator)
      riscvs.push(FaddD(reg1, reg1, reg2))
      riscvs.push(FmvDX(reg1, temp))
      temp
    }
    FSub(lhs, rhs) => {
      let temp = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareFOperands(lhs, rhs, reg_allocator)
      riscvs.push(FsubD(reg1, reg1, reg2))
      riscvs.push(FmvDX(reg1, temp))
      temp
    }
    FMul(lhs, rhs) => {
      let temp = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareFOperands(lhs, rhs, reg_allocator)
      riscvs.push(FmulD(reg1, reg1, reg2))
      riscvs.push(FmvDX(reg1, temp))
      temp
    }
    FDiv(lhs, rhs) => {
      let temp = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareFOperands(lhs, rhs, reg_allocator)
      riscvs.push(FdivD(reg1, reg1, reg2))
      riscvs.push(FmvDX(reg1, temp))
      temp
    }
    Neg(var) => {
      let reg1 = prepareTempReg(reg_allocator)
      let var_location = reg_allocator.stack[var]
      let var_memAccess = { base: Sp, offset: var_location.unwrap() }
      riscvs.push(Lw(reg1, var_memAccess))
      riscvs.push(Neg(reg1, reg1))
      reg1
    }
    FNeg(var) => {
      let reg1 = prepareTempReg(reg_allocator)
      let var_location = reg_allocator.stack[var]
      let var_memAccess = { base: Sp, offset: var_location.unwrap() }
      riscvs.push(Fld(Ft0, var_memAccess))
      riscvs.push(FnegD(Ft0, Ft0))
      riscvs.push(FmvDX(Ft0, reg1))
      reg1
    }
    Let((var, ty), rhs, rest) => {
      let rhs_reg = processInstruction(rhs, reg_allocator)
      match ty {
        Unit => processInstruction(rest, reg_allocator)
        Int => {
          varTable[var] = ty
          let var_memAccess = {
            base: Sp,
            offset: reg_allocator.stack[var].unwrap(),
          }
          riscvs.push(Sw(rhs_reg, var_memAccess))
          processInstruction(rest, reg_allocator)
        }
        _ => {
          varTable[var] = ty
          let var_memAccess = {
            base: Sp,
            offset: reg_allocator.stack[var].unwrap(),
          }
          riscvs.push(Sd(rhs_reg, var_memAccess))
          processInstruction(rest, reg_allocator)
        }
      }
    }
    IfEq(lhs, rhs, then, els) => {
      let else_label = create_label_else()
      let end_label = create_label_end()
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Beq(T0, T1, else_label))
      let _ = processInstruction(then, reg_allocator)
      riscvs.push(J(end_label))
      riscvs.push(Label(else_label))
      let elseResult = processInstruction(els, reg_allocator)
      riscvs.push(Label(end_label))
      elseResult
    }
    IfLe(lhs, rhs, then, els) => {
      let else_label = create_label_else()
      let end_label = create_label_end()
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = { base: Sp, offset: rhs_location.unwrap() }
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Blt(T0, T1, else_label))
      let _ = processInstruction(then, reg_allocator)
      riscvs.push(J(end_label))
      riscvs.push(Label(else_label))
      let elseResult = processInstruction(els, reg_allocator)
      riscvs.push(Label(end_label))
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
      prepareArgs(args, reg_allocator)
      riscvs.push(Addi(Sp, Sp, -8))
      riscvs.push(Sd(Ra, { base: Sp, offset: 0 }))
      riscvs.push(Call(label._))
      riscvs.push(Ld(Ra, { base: Sp, offset: 0 }))
      riscvs.push(Addi(Sp, Sp, 8))
      match extenv[label._].unwrap() {
        Int(_) => reg_ret
        Double(_) => {
          riscvs.push(FmvDX(freg_ret, reg_ret))
          reg_ret
        }
        _ => reg_ret
      }
    }
    CallClosure(closure, args) => {
      //TODO:FuncPtr
      let funcdef = closureTable[closure.to_string()].unwrap()
      for fv in funcdef.formal_free_vars {
        args.push(fv.0)
      }
      prepareArgs(args, registerTable[funcdef.name._].unwrap())
      riscvs.push(Addi(Sp, Sp, -8))
      riscvs.push(Sd(Ra, { base: Sp, offset: 0 }))
      riscvs.push(Call(closure.to_string()))
      riscvs.push(Ld(Ra, { base: Sp, offset: 0 }))
      riscvs.push(Addi(Sp, Sp, 8))
      reg_ret
    }
  }
}

fn processFunction(
  funtion : @closure.FuncDef,
  reg_allocator : RegAllocator
) -> AssemblyFunction {
  let res = if funtion.name._ == "minimbt_main" {
    {
      name: funtion.name._,
      export: true,
      body: Array::new(),
      data: Array::new(),
    }
  } else {
    {
      name: funtion.name._,
      export: false,
      body: Array::new(),
      data: Array::new(),
    }
  }
  let stackSize : Int = preProcess(funtion.body, reg_allocator)
  res.body.push(Addi(Sp, Sp, -stackSize))
  let _ = processInstruction(funtion.body, reg_allocator)
  for asm in riscvs {
    res.body.push(asm)
  }
  res.body.push(Addi(Sp, Sp, stackSize))
  res.body.push(Ret)
  riscvs.clear()
  res
}

pub struct AssemblyFunction {
  name : String
  export : Bool
  body : Array[RvAsm]
  mut data : Array[(String, Double)]
}

pub fn AssemblyFunction::output(
  self : AssemblyFunction,
  logger : Logger
) -> Unit {
  if self.name == "minimbt_main" {
    for label in self.data {
      logger.write_string("\{label.0}: .double \{label.1.to_string()}\n")
    }
    logger.write_string("\n")
  }
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
  counter.push(0)
  end_counter.push(0)
  if_counter.push(0)
  else_counter.push(0)
  let res = Array::new()
  for fun in input.fundefs {
    if fun.is_closure {
      closureTable[fun.name._] = fun
    }
  }
  for fun in input.fundefs {
    let regAllocator = {
      available_regs: reg_allocatable_list,
      available_fregs: freg_allocatable_list,
      used_regs: @hashmap.new(),
      used_fregs: @hashmap.new(),
      stack: @hashmap.new(),
      stack_offset: 0,
      temp_index: 0,
    }
    registerTable[fun.name._] = regAllocator
  }
  for fun in input.fundefs {
    res.push(processFunction(fun, registerTable[fun.name._].unwrap()))
  }
  for func in res {
    if func.name == "minimbt_main" {
      func.data = asmData
    }
  }
  res
}

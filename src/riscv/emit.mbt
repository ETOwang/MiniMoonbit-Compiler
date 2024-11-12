pub struct RegAllocator {
  available_regs : Array[Reg] // 可用寄存器
  available_fregs : Array[FReg]
  used_regs : @hashmap.T[@types.Name, Reg] // 已使用的寄存器
  used_fregs : @hashmap.T[@types.Name, FReg] // 已使用的寄存器
  stack : @hashmap.T[@types.Name, Int] // 存储溢出时的寄存器和变量信息
  fv_list : Array[(@types.Name, @closure.LowType)] // 自由变量列表
  mut stack_offset : Int // 栈偏移量，表示当前栈的位置
  mut temp_index : Int
  mut temp_findex : Int
}

pub let extenv : Map[String, @types.Type] = {
  "minimbt_read_int": Int,
  "minimbt_print_int": Unit,
  "minimbt_read_char": Int,
  "minimbt_print_char": Unit,
  "minimbt_print_endline": Unit,
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

let externalVar : @hashmap.T[String, Int] = @hashmap.new()

let externalFVar : @hashmap.T[String, Double] = @hashmap.new()

let isMakeClosure : @hashmap.T[String, Bool] = @hashmap.new()

let curFunction:Array[String]=Array::new()
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

fn processIntBody(body : @closure.Expr) -> Int {
  match body {
    Int(value) => value
    Double(value) => value.to_int()
    Let((name, name_ty), rhs, rest) => {
      let value = processIntBody(rhs)
      match name_ty {
        Int(_) => {
          varTable[name] = name_ty
          externalVar[name.to_string()] = value
        }
        _ => ()
      }
      processIntBody(rest)
    }
    MakeClosure((name, name_ty), closure, rest) => processIntBody(rest)
    _ => -1
  }
}

fn processDoubleBody(body : @closure.Expr) -> Double {
  match body {
    Int(value) => value.to_double()
    Double(value) => value
    Let((name, name_ty), rhs, rest) => {
      let value = processDoubleBody(rhs)
      match name_ty {
        Double => {
          varTable[name] = name_ty
          externalFVar[name.to_string()] = value
        }
        _ => ()
      }
      processDoubleBody(rest)
    }
    MakeClosure((name, name_ty), closure, rest) => processDoubleBody(rest)
    _ => -1
  }
}

fn save() -> Unit {
  //  let saving_regs=[T3,S11]
  //  riscvs.push(Addi(Sp, Sp, -saving_regs.length()*8))
  //   for index = 0; index < saving_regs.length(); index = index + 1 {
  //       riscvs.push(Sd(saving_regs[index], { base: Sp, offset: index*8 }))
  //   }
}

fn load() -> Unit {
  // let saving_regs=[T3,S11]
  // for index = 0; index < saving_regs.length(); index = index + 1 {
  //     riscvs.push(Ld(saving_regs[index], { base: Sp, offset: index*8 }))
  // }
  // riscvs.push(Addi(Sp, Sp, saving_regs.length()*8))
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
        ClosureFn(_, _) => {
          regAllocator.stack[lhs.0] = regAllocator.stack_offset
          regAllocator.stack_offset += 8
          res += 8
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
    IfLe(_, _, then, el) | IfEq(_, _, then, el) => {
      res += preProcess(then, regAllocator)
      res += preProcess(el, regAllocator)
    }
    MakeClosure((name, _), _, expr) => {
      regAllocator.stack[name] = regAllocator.stack_offset
      regAllocator.stack_offset += 8
      res += 8
      res += preProcess(expr, regAllocator)
    }
    _ => ()
  }
  res
}

fn prepareOperand(expr : @types.Name, reg_allocator : RegAllocator) -> Reg {
  let lhs_location = reg_allocator.stack[expr]
  let mut reg1 = prepareTempReg(reg_allocator)
  if lhs_location.is_empty() {
    let temp = reg_allocator.used_regs[expr]
    if temp.is_empty() {
      let res = externalVar[expr.to_string()]
      if not(res.is_empty()) {
        riscvs.push(Li(reg1, res.unwrap().to_string()))
        return reg1
      }
      let expr_type = varTable[expr]
      if not(expr_type.is_empty()) &&
        not(
          closureTable[expr.to_string()].is_empty() &&
          isMakeClosure[expr.to_string()].is_empty(),
        ) {
        match expr_type.unwrap() {
          ClosureFn(_) => {
            let reg = callMalloc(8,reg_allocator)
            let temp = prepareTempReg(reg_allocator)
            riscvs.push(La(temp, expr.to_string()))
            riscvs.push(Sd(temp, { base: reg, offset: 0 }))
            riscvs.push(Mv(temp, reg))
            return temp
          }
          _ => ()
        }
      }
      for index = 0; index < reg_allocator.fv_list.length(); index = index + 1 {
        let fv_var = reg_allocator.fv_list[index]
        if fv_var.0 == expr {
          let temp = prepareTempReg(reg_allocator)
          riscvs.push(Ld(temp, { base: S11, offset: 8 * (index + 1) }))
          match fv_var.1 {
            Int(_) => {
              riscvs.push(Lw(temp, { base: temp, offset: 0 }))
              return temp
            }
            _ => {
              riscvs.push(Ld(temp, { base: temp, offset: 0 }))
              return temp
            }
          }
        }
      }
      @util.die("error")
    }
    reg1 = reg_allocator.used_regs[expr].unwrap()
  } else {
    let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
    match varTable[expr].unwrap() {
      Int(_) => riscvs.push(Lw(reg1, lhs_memAccess))
      _ => riscvs.push(Ld(reg1, lhs_memAccess))
    }
  }
  reg1
}

fn prepareFOperand(expr : @types.Name, reg_allocator : RegAllocator) -> FReg {
  let lhs_location = reg_allocator.stack[expr]
  let mut reg1 = prepareTempFReg(reg_allocator)
  if lhs_location.is_empty() {
    let temp = reg_allocator.used_fregs[expr]
    if temp.is_empty() {
      for index = 0; index < reg_allocator.fv_list.length(); index = index + 1 {
        let fv_var = reg_allocator.fv_list[index]
        if fv_var.0 == expr {
          let temp = prepareTempReg(reg_allocator)
          riscvs.push(Ld(temp, { base: S11, offset: 8 * (index + 1) }))
          match fv_var.1 {
            Double(_) => {
              let ftemp = prepareTempFReg(reg_allocator)
              riscvs.push(Fld(ftemp, { base: temp, offset: 0 }))
              return ftemp
            }
            _ => @util.die("Need a Double")
          }
        }
      }
      //TODO
      // let res=externalFVar[expr.to_string()]
      // if(not(res.is_empty())){
      //     riscvs.push(Li(reg1, res.to_string()))
      //     return reg1
      // }
      @util.die("error")
    }
    reg1 = reg_allocator.used_fregs[expr].unwrap()
  } else {
    let lhs_memAccess = { base: Sp, offset: lhs_location.unwrap() }
    match varTable[expr].unwrap() {
      Double(_) => riscvs.push(Fld(reg1, lhs_memAccess))
      _ => @util.die("Need double")
    }
  }
  reg1
}

fn prepareOperands(
  lhs : @types.Name,
  rhs : @types.Name,
  reg_allocator : RegAllocator
) -> (Reg, Reg) {
  (prepareOperand(lhs, reg_allocator), prepareOperand(rhs, reg_allocator))
}

fn prepareFOperands(
  lhs : @types.Name,
  rhs : @types.Name,
  reg_allocator : RegAllocator
) -> (FReg, FReg) {
  (prepareFOperand(lhs, reg_allocator), prepareFOperand(rhs, reg_allocator))
}

fn prepareArgs(args : Array[@types.Name], initial : RegAllocator) -> Unit {
  let mut regIndex = 0
  let mut fregIndex = 0
  for index = 0; index < args.length(); index = index + 1 {
    let arg = args[index]
    let arg_type = varTable[arg]
    if arg_type.is_empty() {
      continue
    }
    match arg_type.unwrap() {
      Int(_) => {
        let reg = prepareOperand(arg, initial)
        riscvs.push(Mv(reg_arg_list[regIndex], reg))
        regIndex += 1
      }
      Double(_) => {
        let reg = prepareFOperand(arg, initial)
        riscvs.push(FmvD(freg_arg_list[fregIndex], reg))
        fregIndex += 1
      }
      _ => {
        let reg = prepareOperand(arg, initial)
        riscvs.push(Mv(reg_arg_list[regIndex], reg))
        regIndex += 1
      }
    }
  }
}

fn prepareTempFReg(reg_allocator : RegAllocator) -> FReg {
  let temp_list = [Ft0, Ft1, Ft2]
  let temp_reg = temp_list[reg_allocator.temp_findex]
  reg_allocator.temp_findex += 1
  reg_allocator.temp_findex %= temp_list.length()
  temp_reg
}

fn prepareTempReg(reg_allocator : RegAllocator) -> Reg {
  let temp_list = [T0, T1, T2,T3,T4,T5,T6]
  let temp_reg = temp_list[reg_allocator.temp_index]
  reg_allocator.temp_index += 1
  reg_allocator.temp_index %= temp_list.length()
  temp_reg
}

fn callMalloc(size : Int, regAllocator : RegAllocator) -> Reg {
  let temp = prepareTempReg(regAllocator)
  let res = prepareTempReg(regAllocator)
  riscvs.push(Mv(temp, A0))
  riscvs.push(Li(A0, size.to_string()))
  riscvs.push(Addi(Sp, Sp, -8))
  riscvs.push(Sd(Ra, { base: Sp, offset: 0 }))
  riscvs.push(Call("minimbt_malloc"))
  riscvs.push(Ld(Ra, { base: Sp, offset: 0 }))
  riscvs.push(Addi(Sp, Sp, 8))
  riscvs.push(Mv(res, A0))
  riscvs.push(Mv(A0, temp))
  res
}

fn callCreatePtrArray(size : Int, regAllocator : RegAllocator) -> Reg {
  let temp = prepareTempReg(regAllocator)
  let temp2 = prepareTempReg(regAllocator)
  let res = prepareTempReg(regAllocator)
  riscvs.push(Mv(temp, A0))
  riscvs.push(Mv(temp2, A1))
  riscvs.push(Li(A0, size.to_string()))
  riscvs.push(Li(A1, "0"))
  riscvs.push(Addi(Sp, Sp, -8))
  riscvs.push(Sd(Ra, { base: Sp, offset: 0 }))
  riscvs.push(Call("minimbt_create_ptr_array"))
  riscvs.push(Ld(Ra, { base: Sp, offset: 0 }))
  riscvs.push(Addi(Sp, Sp, 8))
  riscvs.push(Mv(res, A0))
  riscvs.push(Mv(A0, temp))
  riscvs.push(Mv(A1, temp2))
  res
}

fn createClosure(
  size : Int,
  closure : @closure.Closure,
  regAllocator : RegAllocator
) -> Reg {
  let reg_array = callCreatePtrArray(size + 1,regAllocator)
  let func_ptr = prepareTempReg(regAllocator)
  riscvs.push(La(func_ptr, closure.name._))
  riscvs.push(Sd(func_ptr, { base: reg_array, offset: 0 }))
  for index = 0; index < closure.actual_free_vars.length(); index = index + 1 {
    let fv_name = closure.actual_free_vars[index]
    match varTable[fv_name].unwrap() {
      Int(_) => {
        let temp = prepareOperand(fv_name, regAllocator)
        let reg = callMalloc(4,regAllocator)
        riscvs.push(Sw(temp, { base: reg, offset: 0 }))
        riscvs.push(Sd(reg, { base: reg_array, offset: 8 * (index + 1) }))
      }
      Double(_) => {
        let temp = prepareFOperand(fv_name, regAllocator)
        let reg = callMalloc(8,regAllocator)
        riscvs.push(Fsd(temp, { base: reg, offset: 0 }))
        riscvs.push(Sd(reg, { base: reg_array, offset: 8 * (index + 1) }))
      }
      _ => {
        let temp = prepareOperand(fv_name, regAllocator)
        let reg = callMalloc(8,regAllocator)
        riscvs.push(Sd(temp, { base: reg, offset: 0 }))
        riscvs.push(Sd(reg, { base: reg_array, offset: 8 * (index + 1) }))
      }
    }
  }
  reg_array
}

fn processInstruction(
  expr : @closure.Expr,
  reg_allocator : RegAllocator
) -> Reg {
  match expr {
    //TODO
    Unit => T0
    MakeTuple(vars) => {
      let reg_array = callCreatePtrArray(vars.length(),reg_allocator)
      //todo:t3
      for index = 0; index < vars.length(); index = index + 1 {
        let var = vars[index]
        match varTable[var].unwrap() {
          Int(_) => {
            let reg = callMalloc(4,reg_allocator)
            let temp = prepareOperand(var, reg_allocator)
            riscvs.push(Sw(temp, { base: reg, offset: 0 }))
            riscvs.push(Sd(reg, { base: reg_array, offset: 8 * index }))
          }
          Double(_) => {
            let reg = callMalloc(8,reg_allocator)
            let temp = prepareFOperand(var, reg_allocator)
            riscvs.push(Fsd(temp, { base: reg, offset: 0 }))
            riscvs.push(Sd(reg, { base: reg_array, offset: 8 * index }))
          }
          _ => {
            let reg = callMalloc(8,reg_allocator)
            let temp = prepareOperand(var, reg_allocator)
            riscvs.push(Sd(temp, { base: reg, offset: 0 }))
            riscvs.push(Sd(reg, { base: reg_array, offset: 8 * index }))
          }
        }
      }
      reg_array
    }
    LetTuple(vars, tuple, rest) => {
      let tuple_reg = prepareOperand(tuple, reg_allocator)
      for index = 0; index < vars.length(); index = index + 1 {
        let var = vars[index]
        varTable[var.0] = var.1
        let var_location = reg_allocator.stack[var.0]
        let var_memAccess = { base: Sp, offset: var_location.unwrap() }
        match var.1 {
          Int(_) => {
            let temp = prepareTempReg(reg_allocator)
            riscvs.push(Ld(temp, { base: tuple_reg, offset: 8 * index }))
            riscvs.push(Lw(temp, { base: temp, offset: 0 }))
            riscvs.push(Sw(temp, var_memAccess))
          }
          _ => {
            let temp = prepareTempReg(reg_allocator)
            riscvs.push(Ld(temp, { base: tuple_reg, offset: 8 * index }))
            riscvs.push(Ld(temp, { base: temp, offset: 0 }))
            riscvs.push(Sd(temp, var_memAccess))
          }
        }
      }
      processInstruction(rest, reg_allocator)
    }
    MakeClosure((var, var_ty), closure, rest) => {
      varTable[var] = var_ty
      let fvs = closure.actual_free_vars
      let closure_reg = createClosure(fvs.length(), closure, reg_allocator)
      let closure_memAccess = {
        base: Sp,
        offset: reg_allocator.stack[var].unwrap(),
      }
      riscvs.push(Sd(closure_reg, closure_memAccess))
      isMakeClosure[var.to_string()] = true
      processInstruction(rest, reg_allocator)
    }
    ExternalArray(label) => {
      @util.die("externalarray")
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
      riscvs.push(FmvXD(reg, Ft0))
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
      reg1
    }
    FAdd(lhs, rhs) => {
      let temp = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareFOperands(lhs, rhs, reg_allocator)
      riscvs.push(FaddD(reg1, reg1, reg2))
      riscvs.push(FmvXD(temp, reg1))
      temp
    }
    FSub(lhs, rhs) => {
      let temp = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareFOperands(lhs, rhs, reg_allocator)
      riscvs.push(FsubD(reg1, reg1, reg2))
      riscvs.push(FmvXD(temp, reg1))
      temp
    }
    FMul(lhs, rhs) => {
      let temp = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareFOperands(lhs, rhs, reg_allocator)
      riscvs.push(FmulD(reg1, reg1, reg2))
      riscvs.push(FmvXD(temp, reg1))
      temp
    }
    FDiv(lhs, rhs) => {
      let temp = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareFOperands(lhs, rhs, reg_allocator)
      riscvs.push(FdivD(reg1, reg1, reg2))
      riscvs.push(FmvXD(temp, reg1))
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
      riscvs.push(FmvXD(reg1, Ft0))
      reg1
    }
    Let((var, ty), rhs, rest) => {
      println(var)
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
        ClosureFn(_, _) => {
          varTable[var] = ty
          let var_memAccess = {
            base: Sp,
            offset: reg_allocator.stack[var].unwrap(),
          }
          riscvs.push(Sd(rhs_reg, var_memAccess))
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
      let temp_reg = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareOperands(lhs, rhs, reg_allocator)
      riscvs.push(Bne(reg1, reg2, else_label))
      let ret_reg = processInstruction(then, reg_allocator)
      //todo:double
      riscvs.push(Mv(temp_reg, ret_reg))
      riscvs.push(J(end_label))
      riscvs.push(Label(else_label))
      let elseResult = processInstruction(els, reg_allocator)
      riscvs.push(Mv(temp_reg, elseResult))
      riscvs.push(Label(end_label))
      temp_reg
    }
    IfLe(lhs, rhs, then, els) => {
      let else_label = create_label_else()
      let end_label = create_label_end()
      let temp_reg = prepareTempReg(reg_allocator)
      let (reg1, reg2) = prepareOperands(lhs, rhs, reg_allocator)
      riscvs.push(Blt(reg2, reg1, else_label))
      let ret_reg = processInstruction(then, reg_allocator)
      //todo:double
      riscvs.push(Mv(temp_reg, ret_reg))
      riscvs.push(J(end_label))
      riscvs.push(Label(else_label))
      let elseResult = processInstruction(els, reg_allocator)
      riscvs.push(Mv(temp_reg, elseResult))
      riscvs.push(Label(end_label))
      temp_reg
    }
    Var(var) =>
      match varTable[var].unwrap() {
        Double(_) => {
          let temp = prepareFOperand(var, reg_allocator)
          let res = prepareTempReg(reg_allocator)
          riscvs.push(FmvXD(res, temp))
          res
        }
        _ => prepareOperand(var, reg_allocator)
      }
    // assume this is a double array
    ArrayGet(arr, idx) => {
      let reg1 = prepareOperand(arr, reg_allocator)
      let reg2 = prepareOperand(idx, reg_allocator)
      match varTable[arr].unwrap() {
        Array(Int) => {
          let temp = prepareTempReg(reg_allocator)
          riscvs.push(Li(temp, "4"))
          riscvs.push(Mul(reg2, temp, reg2))
          riscvs.push(Add(reg1, reg1, reg2))
          riscvs.push(Lw(temp, { base: reg1, offset: 0 }))
          temp
        }
        _ => {
          let temp = prepareTempReg(reg_allocator)
          riscvs.push(Li(temp, "8"))
          riscvs.push(Mul(reg2, temp, reg2))
          riscvs.push(Add(reg1, reg1, reg2))
          riscvs.push(Ld(temp, { base: reg1, offset: 0 }))
          temp
        }
      }
    }
    ArrayPut(arr, idx, value) => {
      let arr_reg = prepareOperand(arr, reg_allocator)
      let idx_reg = prepareOperand(idx, reg_allocator)
      let value_ty = varTable[value].unwrap()
      match value_ty {
        Int(_) => {
          let value_reg = prepareOperand(value, reg_allocator)
          let temp = prepareTempReg(reg_allocator)
          riscvs.push(Li(temp, "4"))
          riscvs.push(Mul(idx_reg, temp, idx_reg))
          riscvs.push(Add(arr_reg, arr_reg, idx_reg))
          riscvs.push(Sw(value_reg, { base: arr_reg, offset: 0 }))
          value_reg
        }
        Double => {
          let value_reg = prepareFOperand(value, reg_allocator)
          let temp = prepareTempReg(reg_allocator)
          riscvs.push(Li(temp, "8"))
          riscvs.push(Mul(idx_reg, temp, idx_reg))
          riscvs.push(Add(arr_reg, arr_reg, idx_reg))
          riscvs.push(Fsd(value_reg, { base: arr_reg, offset: 0 }))
          riscvs.push(FmvXD(temp, value_reg))
          temp
        }
        _ => {
          let value_reg = prepareOperand(value, reg_allocator)
          let temp = prepareTempReg(reg_allocator)
          riscvs.push(Li(temp, "8"))
          riscvs.push(Mul(idx_reg, temp, idx_reg))
          riscvs.push(Add(arr_reg, arr_reg, idx_reg))
          riscvs.push(Sd(value_reg, { base: arr_reg, offset: 0 }))
          value_reg
        }
      }
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
          riscvs.push(FmvXD(reg_ret, freg_ret))
          reg_ret
        }
        _ => reg_ret
      }
    }
    CallClosure(closure, args) => {
      riscvs.push(Comment("start callClosure"))
      riscvs.push(Comment(closure.to_string()))
      riscvs.push(Comment(curFunction[0]))
      let temp = closureTable[closure.to_string()]
      if (curFunction[0]!=closure.to_string()&&(temp.is_empty()||not(isMakeClosure[closure.to_string()].is_empty()))) {
        riscvs.push(Comment("here"))
        save()
        prepareArgs(args, reg_allocator)
        let closure_reg = prepareOperand(closure, reg_allocator)
        //TODO:save s11
        riscvs.push(Mv(S11, closure_reg))
        let func_ptr = prepareTempReg(reg_allocator)
        riscvs.push(Ld(func_ptr, { base: closure_reg, offset: 0 }))
        riscvs.push(Addi(Sp, Sp, -8))
        riscvs.push(Sd(Ra, { base: Sp, offset: 0 }))
        riscvs.push(Jalr(func_ptr))
        riscvs.push(Ld(Ra, { base: Sp, offset: 0 }))
        riscvs.push(Addi(Sp, Sp, 8))
        load()
        return reg_ret
      }
      // let func=temp.unwrap()
      // let actual_free_vars = Array::new()
      // for fv in func.formal_free_vars {
      //   if(closureTable[fv.0.to_string()].is_empty()){
      //   actual_free_vars.push(fv.0)
      //   }
      // }
      //let cls:@closure.Closure={name:func.name,actual_free_vars:actual_free_vars}
      //let closure_reg=createClosure(func.formal_free_vars.length(), cls, reg_allocator)
      save()
      //riscvs.push(Mv(S11, closure_reg))
      prepareArgs(args, reg_allocator)
      riscvs.push(Addi(Sp, Sp, -8))
      riscvs.push(Sd(Ra, { base: Sp, offset: 0 }))
      riscvs.push(Call(closure.to_string()))
      riscvs.push(Ld(Ra, { base: Sp, offset: 0 }))
      riscvs.push(Addi(Sp, Sp, 8))
      load()
      riscvs.push(Comment("end callClosure"))
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
  curFunction[0]=funtion.name._
  let stackSize : Int = preProcess(funtion.body, reg_allocator) +
    funtion.args.length() * 8
  res.body.push(Addi(Sp, Sp, -stackSize))
  let mut reg_index = 0
  let mut freg_index = 0
  for index = 0; index < funtion.args.length(); index = index + 1 {
    let arg = funtion.args[index]
    match arg.1 {
      Int(_) => {
        reg_allocator.stack[arg.0] = reg_allocator.stack_offset
        reg_allocator.stack_offset += 4
        riscvs.push(
          Sw(
            reg_arg_list[reg_index],
            { base: Sp, offset: reg_allocator.stack_offset - 4 },
          ),
        )
        reg_index += 1
      }
      Double(_) => {
        reg_allocator.stack[arg.0] = reg_allocator.stack_offset
        reg_allocator.stack_offset += 8
        riscvs.push(
          Fsd(
            freg_arg_list[freg_index],
            { base: Sp, offset: reg_allocator.stack_offset - 8 },
          ),
        )
        freg_index += 1
      }
      _ => {
        reg_allocator.stack[arg.0] = reg_allocator.stack_offset
        reg_allocator.stack_offset += 8
        riscvs.push(
          Sd(
            reg_arg_list[reg_index],
            { base: Sp, offset: reg_allocator.stack_offset - 8 },
          ),
        )
        reg_index += 1
      }
    }
  }
  reg_allocator.stack_offset = stackSize
  let return_reg = processInstruction(funtion.body, reg_allocator)
  for asm in riscvs {
    res.body.push(asm)
  }
  res.body.push(Mv(reg_ret, return_reg))
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
      logger.write_string(".global ")
      logger.write_string("\{label.0}\n")
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
  curFunction.push("NULL")
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
  let _ = processIntBody(input.body)
  let _ = processDoubleBody(input.body)
  for fun in input.fundefs {
    let regAllocator = {
      available_regs: reg_allocatable_list,
      available_fregs: freg_allocatable_list,
      used_regs: @hashmap.new(),
      used_fregs: @hashmap.new(),
      stack: @hashmap.new(),
      fv_list: fun.formal_free_vars,
      stack_offset: 0,
      temp_index: 0,
      temp_findex: 0,
    }
    varTable[fun.old_name] = fun.ty
    registerTable[fun.name._] = regAllocator
  }
  for fun in input.fundefs {
    for arg in fun.args {
      varTable[arg.0] = arg.1
    }
    res.push(processFunction(fun, registerTable[fun.name._].unwrap()))
  }
  for func in res {
    if func.name == "minimbt_main" {
      func.data = asmData
    }
  }
  res
}

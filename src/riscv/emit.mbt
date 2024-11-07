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

// impl for RegAllocator {
//     pub fn new() -> Self {
//         RegAllocator {
//             available_regs: Array::new[
//                 Reg::T0, Reg::T1, Reg::T2, Reg::T3, Reg::T4, Reg::T5, Reg::T6, // 临时寄存器
//                 Reg::S0, Reg::S1, Reg::S2, Reg::S3, Reg::S4, Reg::S5, Reg::S6, Reg::S7, Reg::S8, Reg::S9, Reg::S10, Reg::S11, // 保存寄存器
//                 Reg::A0, Reg::A1, Reg::A2, Reg::A3, Reg::A4, Reg::A5, Reg::A6, Reg::A7, // 参数寄存器
//             ],
//             used_regs: HashMap::new(),
//             stack: Vec::new(),
//             stack_offset: 0,
//         }
//     }

//     // 分配寄存器
//     pub fn allocate(   mut self, var_name:    str) -> Option<Reg> {
//         if let Some(reg) = self.available_regs.pop() {
//             self.used_regs.insert(var_name.to_string(), reg);
//             Some(reg)
//         } else {
//             // 寄存器不足时进行溢出处理，将栈上保存当前寄存器的值
//             self.handle_register_spill(var_name)
//         }
//     }

//     // 释放寄存器
//     pub fn free(   mut self, var_name:    str) {
//         if let Some(reg) = self.used_regs.remove(var_name) {
//             // 释放寄存器前要先检查是否存储过栈
//             if let Some((saved_var, saved_reg)) = self.stack.iter().find(|(_, r)|   r ==    reg) {
//                 // 恢复寄存器值
//                 self.restore_register_from_stack(saved_var, saved_reg);
//             }
//             self.available_regs.push(reg);  // 释放寄存器
//         }
//     }

//     // 处理寄存器溢出（保存栈并分配新寄存器）
//     fn handle_register_spill(   mut self, var_name:    str) -> Option<Reg> {
//         // 获取一个要溢出的寄存器
//         if let Some((old_var_name, old_reg)) = self.used_regs.iter().next() {
//             // 先把溢出的寄存器值保存到栈中
//             self.spill_to_stack(old_var_name, old_reg);
//             self.used_regs.remove(old_var_name); // 移除溢出寄存器的使用
//         }

//         // 继续分配一个新的寄存器
//         self.allocate(var_name)
//     }

//     // 将寄存器的值保存到栈中
//     fn spill_to_stack(   mut self, var_name:    str, reg:    Reg) {
//         // 通过栈偏移量计算栈位置
//         self.stack.push((var_name.to_string(), reg.clone()));
//         self.stack_offset += 4; // 每次溢出使用4字节（假设是32位寄存器）
//     }

//     // 恢复寄存器的值
//     fn restore_register_from_stack(   mut self, var_name:    str, reg:    Reg) {
//         // 模拟从栈恢复寄存器值的过程
//         self.stack_offset -= 4;
//         self.stack.retain(|(v, _)| v != var_name);
//     }

//     // 栈操作模拟：实际可能需要生成汇编代码来进行栈操作
//     pub fn get_stack_offset(   self) -> i32 {
//         self.stack_offset
//     }
// }

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
    LetTuple(lhs, rhs, rest) => {
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
) -> Reg  {
  match expr {
    Add(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Add(T0, T0, T1))
      T0
    }
    Sub(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Sub(T0, T0, T1))
      T0
    }
    Mul(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Mul(T0, T0, T1))
      T0
    }
    Div(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
      riscvs.push(Lw(T1, rhs_memAccess))
      riscvs.push(Div(T0, T0, T1))
      T0
    }
    FAdd(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Fld(Ft0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
      riscvs.push(Fld(Ft1, rhs_memAccess))
      riscvs.push(FaddD(Ft0, Ft0, Ft1))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    FSub(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Fld(Ft0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
      riscvs.push(Fld(Ft1, rhs_memAccess))
      riscvs.push(FsubD(Ft0, Ft0, Ft1))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    FMul(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Fld(Ft0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
      riscvs.push(Fld(Ft1, rhs_memAccess))
      riscvs.push(FmulD(Ft0, Ft0, Ft1))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    FDiv(lhs, rhs) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Fld(Ft0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
      riscvs.push(Fld(Ft1, rhs_memAccess))
      riscvs.push(FdivD(Ft0, Ft0, Ft1))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    Neg(var) => {
      let var_location = reg_allocator.stack[var]
      let var_memAccess = {base: Sp, offset: var_location.unwrap()}
      riscvs.push(Lw(T0, var_memAccess))
      riscvs.push(Neg(T0, T0))
      T0
    }
    FNeg(var) => {
      let var_location = reg_allocator.stack[var]
      let var_memAccess = {base: Sp, offset: var_location.unwrap()}
      riscvs.push(Fld(Ft0, var_memAccess))
      riscvs.push(FnegD(Ft0, Ft0))
      riscvs.push(FmvDX(Ft0, T0))
      T0
    }
    Let((var, _), rhs, rest) => {
      let rhs_reg = processInstruction(rhs, reg_allocator)
      let var_memAccess = {base: Sp, offset: reg_allocator.stack[var].unwrap()}
      riscvs.push(Sw(rhs_reg, var_memAccess))
      processInstruction(rest, reg_allocator)
    }

    IfEq(lhs, rhs, then, els) => {
      let lhs_location = reg_allocator.stack[lhs]
      let rhs_location = reg_allocator.stack[rhs]
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
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
      let lhs_memAccess = {base: Sp, offset: lhs_location.unwrap()}
      riscvs.push(Lw(T0, lhs_memAccess))
      let rhs_memAccess = {base: Sp, offset: rhs_location.unwrap()}
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
      if (var_location.is_empty()) {
        let var_reg = reg_allocator.used_regs[var].unwrap()
        var_reg
      }
      else {
        let var_memAccess = {base: Sp, offset: var_location.unwrap()}
        riscvs.push(Ld(T0, var_memAccess))
        T0
      }
    }
    // assume this is a double array
    ArrayGet(arr, idx) => {
      let arr_location = reg_allocator.stack[arr]
      let arr_memAccess = {base: Sp, offset: arr_location.unwrap()}
      riscvs.push(Ld(T0, arr_memAccess))
      let idx_location = reg_allocator.stack[idx]
      let idx_memAccess = {base: Sp, offset: idx_location.unwrap()}
      riscvs.push(Ld(T1, idx_memAccess))
      riscvs.push(Add(T0, T0, T1))
      let element_location = {base: T0, offset: 0}
      riscvs.push(Ld(T0, element_location))
      T0
    }
    ArrayPut(arr, idx, value) => {
      let arr_location = reg_allocator.stack[arr]
      let arr_memAccess = {base: Sp, offset: arr_location.unwrap()}
      riscvs.push(Ld(T0, arr_memAccess))
      let idx_location = reg_allocator.stack[idx]
      let idx_memAccess = {base: Sp, offset: idx_location.unwrap()}
      riscvs.push(Ld(T1, idx_memAccess))
      riscvs.push(Add(T0, T0, T1))
      let value_location = reg_allocator.stack[value]
      let value_memAccess = {base: Sp, offset: value_location.unwrap()}
      riscvs.push(Ld(T1, value_memAccess))
      let element_location = {base: T0, offset: 0}
      riscvs.push(Sd(T1, element_location))
      T1
    }
  }
}

fn processFunction(
  funtion : @closure.FuncDef,
  reg_allocator : RegAllocator
) -> AssemblyFunction {
  let res = {
    name: funtion.name.to_string(),
    export: false,
    body: Array::new(),
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

pub fn emit(input : @closure.Program) -> Array[AssemblyFunction] {
  let res = Array::new()
  for fun in input.fundefs {
    res.push(processFunction(fun, regAllocator))
  }
  res
}

pub struct AssemblyFunction {
  name : String
  export : Bool
  body : Array[RvAsm]
}

pub fn AssemblyFunction::output(
  self : AssemblyFunction,
  logger : Logger,
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


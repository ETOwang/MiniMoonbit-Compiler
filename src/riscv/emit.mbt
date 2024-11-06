pub struct RegAllocator {
    available_regs: Array[Reg]               // 可用寄存器
    used_regs: @immut/hashmap.T[String, Reg]         // 已使用的寄存器
    stack: Array[(String, Reg)]               // 存储溢出时的寄存器和变量信息
    stack_offset: Int                      // 栈偏移量，表示当前栈的位置
}




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
    name: String
    export: Bool
    instructions: Array[RvAsm]
}




pub fn emit(input: @closure.Program) -> Array[AssemblyFunction] {
    // let mut functions: Vec<AssemblyFunction> = Vec::new();
    
    // // 创建寄存器分配器
    // let mut reg_allocator = RegAllocator::new();

    // // 处理每个函数
    // for func in input {
    //     let mut assembly_instructions: Vec<RvAsm> = Vec::new();

    //     // 处理函数中的每一条指令
    //     for instr in func.instructions {
    //         match instr {
    //             // 假设处理的是赋值操作
    //             RvAsm::Assign(var_name, expr) => {
    //                 // 为变量分配寄存器或处理溢出
    //                 let reg = reg_allocator.allocate(   var_name);
    //                 match reg {
    //                     Some(r) => {
    //                         // 根据表达式生成汇编代码
    //                         let asm = generate_assignment_asm(   var_name, expr, r);
    //                         assembly_instructions.push(asm);
    //                     },
    //                     None => {
    //                         // 如果寄存器溢出，将变量存入栈
    //                         let stack_offset = reg_allocator.get_stack_offset();
    //                         let asm = generate_stack_assignment_asm(   var_name, expr, stack_offset);
    //                         assembly_instructions.push(asm);
    //                     }
    //                 }
    //             },
    //             // 如果是其他类型的汇编指令
    //             _ => {
    //                 let asm = generate_other_asm(instr);
    //                 assembly_instructions.push(asm);
    //             }
    //         }
    //     }

    //     // 为当前函数生成汇编代码
    //     let assembly_function = AssemblyFunction {
    //         name: func.name,
    //         export: func.export,
    //         body: assembly_instructions,
    //     };

    //     // 将生成的汇编函数添加到最终输出中
    //     functions.push(assembly_function);
    // }

    // functions
}









pub struct AssemblyFunction {
  name : String
  export : Bool
  body : Array[RvAsm]
}

pub fn AssemblyFunction::output(
  self : AssemblyFunction,
  logger : Logger,
  reg_allocator:    RegAllocator
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

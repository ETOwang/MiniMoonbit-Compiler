pub struct RegAllocator {
    available_regs: Array[Reg]               // 可用寄存器
    used_regs: @immut/hashmap.T[String, Reg]         // 已使用的寄存器
    stack: Array[(String, Reg)]               // 存储溢出时的寄存器和变量信息
    stack_offset: Int                      // 栈偏移量，表示当前栈的位置
}




impl for RegAllocator {
    pub fn new() -> Self {
        RegAllocator {
            available_regs: Array::new[
                Reg::T0, Reg::T1, Reg::T2, Reg::T3, Reg::T4, Reg::T5, Reg::T6, // 临时寄存器
                Reg::S0, Reg::S1, Reg::S2, Reg::S3, Reg::S4, Reg::S5, Reg::S6, Reg::S7, Reg::S8, Reg::S9, Reg::S10, Reg::S11, // 保存寄存器
                Reg::A0, Reg::A1, Reg::A2, Reg::A3, Reg::A4, Reg::A5, Reg::A6, Reg::A7, // 参数寄存器
            ],
            used_regs: HashMap::new(),
            stack: Vec::new(),
            stack_offset: 0,
        }
    }

    // 分配寄存器
    pub fn allocate(   mut self, var_name:    str) -> Option<Reg> {
        if let Some(reg) = self.available_regs.pop() {
            self.used_regs.insert(var_name.to_string(), reg);
            Some(reg)
        } else {
            // 寄存器不足时进行溢出处理，将栈上保存当前寄存器的值
            self.handle_register_spill(var_name)
        }
    }

    // 释放寄存器
    pub fn free(   mut self, var_name:    str) {
        if let Some(reg) = self.used_regs.remove(var_name) {
            // 释放寄存器前要先检查是否存储过栈
            if let Some((saved_var, saved_reg)) = self.stack.iter().find(|(_, r)|   r ==    reg) {
                // 恢复寄存器值
                self.restore_register_from_stack(saved_var, saved_reg);
            }
            self.available_regs.push(reg);  // 释放寄存器
        }
    }

    // 处理寄存器溢出（保存栈并分配新寄存器）
    fn handle_register_spill(   mut self, var_name:    str) -> Option<Reg> {
        // 获取一个要溢出的寄存器
        if let Some((old_var_name, old_reg)) = self.used_regs.iter().next() {
            // 先把溢出的寄存器值保存到栈中
            self.spill_to_stack(old_var_name, old_reg);
            self.used_regs.remove(old_var_name); // 移除溢出寄存器的使用
        }
        
        // 继续分配一个新的寄存器
        self.allocate(var_name)
    }

    // 将寄存器的值保存到栈中
    fn spill_to_stack(   mut self, var_name:    str, reg:    Reg) {
        // 通过栈偏移量计算栈位置
        self.stack.push((var_name.to_string(), reg.clone()));
        self.stack_offset += 4; // 每次溢出使用4字节（假设是32位寄存器）
    }

    // 恢复寄存器的值
    fn restore_register_from_stack(   mut self, var_name:    str, reg:    Reg) {
        // 模拟从栈恢复寄存器值的过程
        self.stack_offset -= 4;
        self.stack.retain(|(v, _)| v != var_name);
    }

    // 栈操作模拟：实际可能需要生成汇编代码来进行栈操作
    pub fn get_stack_offset(   self) -> i32 {
        self.stack_offset
    }
}





pub struct InputFunction {
    name: String
    export: Bool
    instructions: Array[RvAsm]
}




pub fn emit(input: Vec<InputFunction>) -> Vec<AssemblyFunction> {
    let mut functions: Vec<AssemblyFunction> = Vec::new();
    
    // 创建寄存器分配器
    let mut reg_allocator = RegAllocator::new();

    // 处理每个函数
    for func in input {
        let mut assembly_instructions: Vec<RvAsm> = Vec::new();

        // 处理函数中的每一条指令
        for instr in func.instructions {
            match instr {
                // 假设处理的是赋值操作
                RvAsm::Assign(var_name, expr) => {
                    // 为变量分配寄存器或处理溢出
                    let reg = reg_allocator.allocate(   var_name);
                    match reg {
                        Some(r) => {
                            // 根据表达式生成汇编代码
                            let asm = generate_assignment_asm(   var_name, expr, r);
                            assembly_instructions.push(asm);
                        },
                        None => {
                            // 如果寄存器溢出，将变量存入栈
                            let stack_offset = reg_allocator.get_stack_offset();
                            let asm = generate_stack_assignment_asm(   var_name, expr, stack_offset);
                            assembly_instructions.push(asm);
                        }
                    }
                },
                // 如果是其他类型的汇编指令
                _ => {
                    let asm = generate_other_asm(instr);
                    assembly_instructions.push(asm);
                }
            }
        }

        // 为当前函数生成汇编代码
        let assembly_function = AssemblyFunction {
            name: func.name,
            export: func.export,
            body: assembly_instructions,
        };

        // 将生成的汇编函数添加到最终输出中
        functions.push(assembly_function);
    }

    functions
}




fn generate_assignment_asm(var_name:    str, expr: Expression, reg: Reg) -> RvAsm {
    // 生成赋值操作的汇编代码
    match expr {
        Expression::Literal(value) => {
            return RvAsm::li(reg, string); 
        }
        Expression::Var(v) => {
            // 如果是变量，将另一个寄存器的值赋给目标寄存器
            let src_reg = reg_allocator.used_regs.get(   v).unwrap(); // 获取源寄存器
            return RvAsm::mv(reg,   src_reg); 
        }
        _ => {
            // 其他类型的表达式需要进一步处理
            unimplemented!()
        }
    }
}




fn generate_stack_assignment_asm(var_name:    str, expr: Expression, stack_offset: i32) -> RvAsm {
    // 处理寄存器溢出，将值存入栈中的汇编
    match expr {
        Expression::Literal(value) => {
            return RvAsm::sw(value, stack_offset, Reg::Sp); // 假设 RvAsm::sw 是存储字节指令
        }
        Expression::Var(v) => {
            let src_reg = reg_allocator.used_regs.get(   v).unwrap(); // 获取源寄存器
            return RvAsm::sw(  src_reg, stack_offset, Reg::Sp); // 假设将寄存器值存到栈中
        }
        _ => {
            unimplemented!()
        }
    }
}




fn generate_other_asm(instruction: RvAsm) -> RvAsm {
    // 生成其他类型的汇编代码
    match instruction {
        //   reg-reg arith  
        // 加法指令
        RvAsm::Add(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::add(result_reg,   reg1,   reg2);
        }

        // 减法指令
        RvAsm::Sub(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::sub(result_reg,   reg1,   reg2);
        }

        // 按位异或指令
        RvAsm::Xor(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::xor(result_reg,   reg1,   reg2);
        }

        // 按位或指令
        RvAsm::Or(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::or(result_reg,   reg1,   reg2);
        }

        // 按位与指令
        RvAsm::And(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::and(result_reg,   reg1,   reg2);
        }

        // 左移指令
        RvAsm::Sll(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::sll(result_reg,   reg1,   reg2);
        }

        // 右移逻辑指令
        RvAsm::Srl(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::srl(result_reg,   reg1,   reg2);
        }

        // 右移算术指令
        RvAsm::Sra(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::sra(result_reg,   reg1,   reg2);
        }

        // 小于指令
        RvAsm::Slt(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::slt(result_reg,   reg1,   reg2);
        }

        // 小于无符号指令
        RvAsm::Sltu(var1, var2, result) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let reg2 = reg_allocator.used_regs.get(   var2).unwrap();
            let result_reg = reg_allocator.allocate(   result).unwrap();
            return RvAsm::sltu(result_reg,   reg1,   reg2);
        }

        RvAsm::Addi(var1, var2, imm) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let result_reg = reg_allocator.allocate(   var2).unwrap();
            return RvAsm::addi(result_reg,   reg1, imm);
        }

        //   reg-imm arith  
        // Xori: XOR immediate with a register
        RvAsm::Xori(var1, var2, imm) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let result_reg = reg_allocator.allocate(   var2).unwrap();
            return RvAsm::xori(result_reg,   reg1, imm);
        }

        // Ori: OR immediate with a register
        RvAsm::Ori(var1, var2, imm) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let result_reg = reg_allocator.allocate(   var2).unwrap();
            return RvAsm::ori(result_reg,   reg1, imm);
        }

        // Andi: AND immediate with a register
        RvAsm::Andi(var1, var2, imm) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let result_reg = reg_allocator.allocate(   var2).unwrap();
            return RvAsm::andi(result_reg,   reg1, imm);
        }

        // Slli: Shift left logical immediate
        RvAsm::Slli(var1, var2, imm) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let result_reg = reg_allocator.allocate(   var2).unwrap();
            return RvAsm::slli(result_reg,   reg1, imm);
        }

        // Srli: Shift right logical immediate
        RvAsm::Srli(var1, var2, imm) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let result_reg = reg_allocator.allocate(   var2).unwrap();
            return RvAsm::srli(result_reg,   reg1, imm);
        }

        // Srai: Shift right arithmetic immediate
        RvAsm::Srai(var1, var2, imm) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let result_reg = reg_allocator.allocate(   var2).unwrap();
            return RvAsm::srai(result_reg,   reg1, imm);
        }

        // Slti: Set less than immediate
        RvAsm::Slti(var1, var2, imm) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let result_reg = reg_allocator.allocate(   var2).unwrap();
            return RvAsm::slti(result_reg,   reg1, imm);
        }

        // Sltiu: Set less than immediate unsigned
        RvAsm::Sltiu(var1, var2, imm) => {
            let reg1 = reg_allocator.used_regs.get(   var1).unwrap();
            let result_reg = reg_allocator.allocate(   var2).unwrap();
            return RvAsm::sltiu(result_reg,   reg1, imm);
        }


        //   memory access  
        // Lb: Load byte (signed)
        RvAsm::Lb(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let result_reg = reg_allocator.allocate(   reg).unwrap();
            return RvAsm::lb(result_reg,   base_reg, offset);
        }
        
        // Lh: Load halfword (signed)
        RvAsm::Lh(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let result_reg = reg_allocator.allocate(   reg).unwrap();
            return RvAsm::lh(result_reg,   base_reg, offset);
        }

        // Lw: Load word (signed)
        RvAsm::Lw(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let result_reg = reg_allocator.allocate(   reg).unwrap();
            return RvAsm::lw(result_reg,   base_reg, offset);
        }

        // Ld: Load doubleword (signed)
        RvAsm::Ld(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let result_reg = reg_allocator.allocate(   reg).unwrap();
            return RvAsm::ld(result_reg,   base_reg, offset);
        }

        // Lbu: Load byte (unsigned)
        RvAsm::Lbu(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let result_reg = reg_allocator.allocate(   reg).unwrap();
            return RvAsm::lbu(result_reg,   base_reg, offset);
        }

        // Lhu: Load halfword (unsigned)
        RvAsm::Lhu(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let result_reg = reg_allocator.allocate(   reg).unwrap();
            return RvAsm::lhu(result_reg,   base_reg, offset);
        }

        // Lwu: Load word (unsigned)
        RvAsm::Lwu(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let result_reg = reg_allocator.allocate(   reg).unwrap();
            return RvAsm::lwu(result_reg,   base_reg, offset);
        }

        // Sb: Store byte
        RvAsm::Sb(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let source_reg = reg_allocator.used_regs.get(   reg).unwrap();
            return RvAsm::sb(  source_reg,   base_reg, offset);
        }

        // Sh: Store halfword
        RvAsm::Sh(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let source_reg = reg_allocator.used_regs.get(   reg).unwrap();
            return RvAsm::sh(  source_reg,   base_reg, offset);
        }

        // Sw: Store word
        RvAsm::Sw(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let source_reg = reg_allocator.used_regs.get(   reg).unwrap();
            return RvAsm::sw(  source_reg,   base_reg, offset);
        }

        // Sd: Store doubleword
        RvAsm::Sd(reg, mem_access) => {
            let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
            let offset = mem_access.offset;
            let source_reg = reg_allocator.used_regs.get(   reg).unwrap();
            return RvAsm::sd(  source_reg,   base_reg, offset);
        }

        //   control flow  
        // BEQ: if Reg1 == Reg2, jump to Label
    RvAsm::Beq(reg1, reg2, label) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        return RvAsm::beq(  reg1,   reg2, label);
    },

    // BNE: if Reg1 != Reg2, jump to Label
    RvAsm::Bne(reg1, reg2, label) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        return RvAsm::bne(  reg1,   reg2, label);
    },

    // BLT: if Reg1 < Reg2, jump to Label
    RvAsm::Blt(reg1, reg2, label) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        return RvAsm::blt(  reg1,   reg2, label);
    },

    // BGE: if Reg1 >= Reg2, jump to Label
    RvAsm::Bge(reg1, reg2, label) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        return RvAsm::bge(  reg1,   reg2, label);
    },

    // BLE: if Reg1 <= Reg2, jump to Label
    RvAsm::Ble(reg1, reg2, label) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        return RvAsm::ble(  reg1,   reg2, label);
    },

    // BGT: if Reg1 > Reg2, jump to Label
    RvAsm::Bgt(reg1, reg2, label) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        return RvAsm::bgt(  reg1,   reg2, label);
    },

    // BLTU: if unsigned(Reg1) < Reg2, jump to Label
    RvAsm::Bltu(reg1, reg2, label) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        return RvAsm::bltu(  reg1,   reg2, label);
    },

    // BGEU: if unsigned(Reg1) >= Reg2, jump to Label
    RvAsm::Bgeu(reg1, reg2, label) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        return RvAsm::bgeu(  reg1,   reg2, label);
    },

    //  ecall  
    // Ecall: 系统调用
    RvAsm::Ecall => {
        return RvAsm::ecall();  // 生成 Ecall 指令
    },

    //   rv32/64m  
    // Mul: 乘法 (Reg    Reg)
    RvAsm::Mul(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::mul(  reg1,   reg2,   reg3);  // 生成乘法指令
    },

    // Mulw: 乘法并截断结果 (Reg    Reg -> Reg)
    RvAsm::Mulw(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::mulw(  reg1,   reg2,   reg3);  // 生成带截断的乘法指令
    },

    // Mulh: 乘法高位结果 (Reg    Reg -> Reg (高位))
    RvAsm::Mulh(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::mulh(  reg1,   reg2,   reg3);  // 生成高位乘法指令
    },

    // Mulhsu: 乘法高位有符号与无符号混合 (Reg    Reg -> Reg (高位))
    RvAsm::Mulhsu(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::mulhsu(  reg1,   reg2,   reg3);  // 生成混合符号的乘法高位指令
    },

    // Mulhu: 无符号乘法高位结果 (Reg    Reg -> Reg (高位))
    RvAsm::Mulhu(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::mulhu(  reg1,   reg2,   reg3);  // 生成无符号乘法高位指令
    },

    // Div: 除法 (Reg / Reg)
    RvAsm::Div(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::div(  reg1,   reg2,   reg3);  // 生成除法指令
    },

    // Divw: 带截断的除法 (Reg / Reg)
    RvAsm::Divw(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::divw(  reg1,   reg2,   reg3);  // 生成带截断的除法指令
    },

    // Divu: 无符号除法 (Reg / Reg)
    RvAsm::Divu(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::divu(  reg1,   reg2,   reg3);  // 生成无符号除法指令
    },

    // Rem: 余数 (Reg % Reg)
    RvAsm::Rem(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::rem(  reg1,   reg2,   reg3);  // 生成余数指令
    },

    // Remw: 带截断的余数 (Reg % Reg)
    RvAsm::Remw(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::remw(  reg1,   reg2,   reg3);  // 生成带截断的余数指令
    },

    // Remu: 无符号余数 (Reg % Reg)
    RvAsm::Remu(reg1, reg2, reg3) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        let reg3 = reg_allocator.used_regs.get(   reg3).unwrap();
        return RvAsm::remu(  reg1,   reg2,   reg3);  // 生成无符号余数指令
    },

    //   rvf  
    // FaddD: 浮点加法 (FReg + FReg -> FReg)
    RvAsm::FaddD(freg1, freg2, freg3) => {
        let freg1 = reg_allocator.used_fregs.get(   freg1).unwrap();
        let freg2 = reg_allocator.used_fregs.get(   freg2).unwrap();
        let freg3 = reg_allocator.used_fregs.get(   freg3).unwrap();
        return RvAsm::faddD(  freg1,   freg2,   freg3);  // 生成浮点加法指令
    },

    // FsubD: 浮点减法 (FReg - FReg -> FReg)
    RvAsm::FsubD(freg1, freg2, freg3) => {
        let freg1 = reg_allocator.used_fregs.get(   freg1).unwrap();
        let freg2 = reg_allocator.used_fregs.get(   freg2).unwrap();
        let freg3 = reg_allocator.used_fregs.get(   freg3).unwrap();
        return RvAsm::fsubD(  freg1,   freg2,   freg3);  // 生成浮点减法指令
    },

    // FmulD: 浮点乘法 (FReg    FReg -> FReg)
    RvAsm::FmulD(freg1, freg2, freg3) => {
        let freg1 = reg_allocator.used_fregs.get(   freg1).unwrap();
        let freg2 = reg_allocator.used_fregs.get(   freg2).unwrap();
        let freg3 = reg_allocator.used_fregs.get(   freg3).unwrap();
        return RvAsm::fmulD(  freg1,   freg2,   freg3);  // 生成浮点乘法指令
    },

    // FdivD: 浮点除法 (FReg / FReg -> FReg)
    RvAsm::FdivD(freg1, freg2, freg3) => {
        let freg1 = reg_allocator.used_fregs.get(   freg1).unwrap();
        let freg2 = reg_allocator.used_fregs.get(   freg2).unwrap();
        let freg3 = reg_allocator.used_fregs.get(   freg3).unwrap();
        return RvAsm::fdivD(  freg1,   freg2,   freg3);  // 生成浮点除法指令
    },

    // Fld: 浮点加载 (FReg = MemAccess[Reg, Int])
    RvAsm::Fld(freg, mem_access) => {
        let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
        let offset = mem_access.offset;
        let freg = reg_allocator.allocate_freg(   freg).unwrap();
        return RvAsm::fld(  freg,   base_reg, offset);  // 生成浮点加载指令
    },

    // Fsd: 浮点存储 (MemAccess[Reg, Int] = FReg)
    RvAsm::Fsd(freg, mem_access) => {
        let base_reg = reg_allocator.used_regs.get(   mem_access.base).unwrap();
        let offset = mem_access.offset;
        let freg = reg_allocator.used_fregs.get(   freg).unwrap();
        return RvAsm::fsd(  freg,   base_reg, offset);  // 生成浮点存储指令
    },

    // FbeqD: 浮点等于比较 (FReg == FReg ? Label)
    RvAsm::FbeqD(freg1, freg2, label) => {
        let freg1 = reg_allocator.used_fregs.get(   freg1).unwrap();
        let freg2 = reg_allocator.used_fregs.get(   freg2).unwrap();
        return RvAsm::fbeqD(  freg1,   freg2, label);  // 生成浮点等于比较并跳转指令
    },

    // FbleD: 浮点小于等于比较 (FReg <= FReg ? Label)
    RvAsm::FbleD(freg1, freg2, label) => {
        let freg1 = reg_allocator.used_fregs.get(   freg1).unwrap();
        let freg2 = reg_allocator.used_fregs.get(   freg2).unwrap();
        return RvAsm::fbleD(  freg1,   freg2, label);  // 生成浮点小于等于比较并跳转指令
    }

    // FmvDX: 将浮点寄存器值移到整型寄存器 (FReg -> Reg)
    RvAsm::FmvDX(freg, reg) => {
        let freg = reg_allocator.used_fregs.get(   freg).unwrap();
        let reg = reg_allocator.used_regs.get(   reg).unwrap();
        return RvAsm::fmvDX(  freg,   reg);  // 生成浮点到整型寄存器的移动指令
    }

    // Nop: No operation (无操作)
    RvAsm::Nop => {
        return RvAsm::nop();  // 生成一个 NOP 指令，不做任何操作
    }

    // La: Load address (将标签的地址加载到寄存器)
    RvAsm::La(reg, label) => {
        let reg = reg_allocator.used_regs.get(   reg).unwrap();
        return RvAsm::la(  reg, label);  // 将标签的地址加载到寄存器
    }

    // Li: Load immediate (将常数立即数加载到寄存器)
    RvAsm::Li(reg, string) => {
        let reg = reg_allocator.used_regs.get(   reg).unwrap();
        return RvAsm::li(  reg, string);  // 将常数立即数加载到寄存器
    }

    // Neg: Negate (将寄存器值取反)
    RvAsm::Neg(reg1, reg2) => {
        let reg1 = reg_allocator.used_regs.get(   reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(   reg2).unwrap();
        return RvAsm::neg(  reg1,   reg2);  // 将 reg2 的值取反并存入 reg1
    }

    // FnegD: Floating point negate (浮点取反)
    RvAsm::FnegD(freg1, freg2) => {
        let freg1 = reg_allocator.used_fregs.get( freg1).unwrap();
        let freg2 = reg_allocator.used_fregs.get(   freg2).unwrap();
        return RvAsm::fnegD(  freg1,   freg2);  // 将浮点寄存器 freg2 取反并存入 freg1
    }

    // Mv: Move (将寄存器值复制到另一个寄存器)
    RvAsm::Mv(reg1, reg2) => {
        let reg1 = reg_allocator.used_regs.get(reg1).unwrap();
        let reg2 = reg_allocator.used_regs.get(reg2).unwrap();
        return RvAsm::mv(  reg1,   reg2);  // 将 reg2 的值复制到 reg1
    }

    // FmvD: Move floating point (将浮点寄存器值复制到另一个浮点寄存器)
    RvAsm::FmvD(freg1, freg2) => {
        let freg1 = reg_allocator.used_fregs.get(freg1).unwrap();
        let freg2 = reg_allocator.used_fregs.get(freg2).unwrap();
        return RvAsm::fmvD(freg1, freg2);  // 将浮点寄存器 freg2 的值复制到 freg1
    }

    // J: Jump (跳转到标签位置)
    RvAsm::J(label) => {
        return RvAsm::j(label);  // 无条件跳转到指定标签
    }

    // Jalr: Jump and link register (通过寄存器跳转并保存返回地址)
    RvAsm::Jalr(reg) => {
        let reg = reg_allocator.used_regs.get(   reg).unwrap();
        return RvAsm::jalr(reg);  // 跳转到寄存器 reg 指定的地址
    },

    // Jr: Jump register (通过寄存器跳转)
    RvAsm::Jr(reg) => {
        let reg = reg_allocator.used_regs.get(   reg).unwrap();
        return RvAsm::jr(reg);  // 跳转到寄存器 reg 指定的地址
    },

    // Call: Call a function (调用一个函数)
    RvAsm::Call(label) => {
        return RvAsm::call(label);  // 跳转到函数标签，保存返回地址
    },

    // Tail: Tail call (尾调用，跳转至函数标签)
    RvAsm::Tail(label) => {
        return RvAsm::tail(label);  // 跳转至函数标签，不保存返回地址
    },

    // Ret: Return from function (函数返回)
    RvAsm::Ret => {
        return RvAsm::ret();  // 从当前函数返回
    },

    // 注释指令
    // Label: 定义一个标签
    RvAsm::Label(label) => {
        return RvAsm::label(label);  // 生成标签定义
    },

    // Comment: 生成注释
    RvAsm::Comment(comment) => {
        return RvAsm::comment(comment);  // 生成注释
    },


    _ => {
        unimplemented!()
    }
    }
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

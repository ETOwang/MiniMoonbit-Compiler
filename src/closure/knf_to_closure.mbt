pub typealias LocalEnv = @immut/hashmap.T[Name, LowType]

pub fn fv(expr : @knf.Knf) -> Array[Name] {
  match expr {
    Unit => []
    Int(_) => []
    Double(_) => []
    Neg(x) => [x]
    Add(x, y) => [x, y]
    Sub(x, y) => [x, y]
    FNeg(x) => [x]
    FAdd(x, y) => [x, y]
    FSub(x, y) => [x, y]
    FMul(x, y) => [x, y]
    FDiv(x, y) => [x, y]
    IfEq(x, y, e1, e2) => add_to_array([x, y], union(fv(e1), fv(e2)))
    IfLe(x, y, e1, e2) => add_to_array([x, y], union(fv(e1), fv(e2)))
    Let((x, t), e1, e2) => union(fv(e1), remove(x, fv(e2)))
    LetRec(f, rest) => union(fv(rest), [f])
    Var(x) => [x]
    LetTuple(xts, y, e) => add_to_array([y], diff(fv(e), map(xts, fst)))
    ExternalArray(x) => [x]
  }
}

// 辅助函数实现
pub fn add_to_array(
  arr : Array[Name],
  new_elements : Array[Name]
) -> Array[Name] {
  let mut result = arr
  for elem in new_elements {
    if not(result.contains(elem)) {
      result.push(elem)
    }
  }
  result
}

pub fn union(arr1 : Array[Name], arr2 : Array[Name]) -> Array[Name] {
  add_to_array(arr1, arr2)
}

pub fn remove(element : Name, arr : Array[Name]) -> Array[Name] {
  arr.filter(fn(e) { e != element })
}

pub fn prepend_array(arr : Array[Name], element : Name) -> Array[Name] {
  [element] + arr
}

pub fn diff(arr1 : Array[Name], arr2 : Array[Name]) -> Array[Name] {
  arr1.filter(fn(e) { not(arr2.contains(e)) })
}

pub fn map(arr : Array[(Name, Type)], f : (Name, Type) -> Name) -> Array[Name] {
  arr.map(fn(x : (Name, Type)) -> Name { f(x.0, x.1) })
}

pub fn knf_program_to_closure(
    prog: @knf.Knf,
    extern_env: Map[String, Type]
) -> Program {
    match prog {
        // 处理递归定义
        LetRec(f, rest) => {
            // 递归处理下一个程序部分
            let cout_closure = knf_program_to_closure(rest, extern_env)

            // 获取自由变量
            let free_vars = fv(f.body)

            // 创建函数定义
            let func_def = {
                name: f.name.name.unwrap(),
                old_name: f.name, // 旧名称与新名称相同
                is_closure: true, 
                ty: f.ty,
                args: f.args, // 使用函数的参数
                formal_free_vars: free_vars,
                body: body_closure,
            }
            extern_env.add_function(func_def)

            // 创建闭包
            let closure = MakeClosure(name: f.name, actual_fv: free_vars)
            // 返回新的程序，包含闭包
            Program(
                fundefs: [func_def], // 返回函数定义
                body: LetRec(closure, cout_closure.body)
            )
        }

        // 处理普通的Let表达式
        Let((x, t), e1, e2) => {
            let e1_closure = knf_program_to_closure(e1, extern_env)
            let e2_closure = knf_program_to_closure(e2, extern_env)
            Let((x, t), e1_closure, e2_closure)
        }

        // 处理If表达式
        If(cond, then_branch, else_branch) => {
            let then_closure = knf_program_to_closure(then_branch, extern_env)
            let else_closure = knf_program_to_closure(else_branch, extern_env)
            If(cond, then_closure, else_closure)
        }

        // 处理函数调用
        CallClosure(name, args) => {
            let closure_args = args.map(|arg| knf_program_to_closure(arg, extern_env))
            CallClosure(name, closure_args)
        }

        // 处理其他表达式
        Var(x) => Var(x)
        Neg(x) => Neg(x)
        Add(x, y) => Add(x, y)
        Sub(x, y) => Sub(x, y)
        Mul(x, y) => Mul(x, y)
        Div(x, y) => Div(x, y)
        FNeg(x) => FNeg(x)
        FAdd(x, y) => FAdd(x, y)
        FSub(x, y) => FSub(x, y)
        FMul(x, y) => FMul(x, y)
        FDiv(x, y) => FDiv(x, y)
        IfEq(x, y, e1, e2) => {
            let e1_closure = knf_program_to_closure(e1, extern_env)
            let e2_closure = knf_program_to_closure(e2, extern_env)
            IfEq(x, y, e1_closure, e2_closure)
        }
        IfLe(x, y, e1, e2) => {
            let e1_closure = knf_program_to_closure(e1, extern_env)
            let e2_closure = knf_program_to_closure(e2, extern_env)
            IfLe(x, y, e1_closure, e2_closure)
        }
    }
}

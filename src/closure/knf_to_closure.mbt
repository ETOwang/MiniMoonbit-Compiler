pub typealias LocalEnv = @immut/hashmap.T[Name, LowType]

pub fn fv(expr : @knf.Knf) -> Array[Name] {
  match expr {
    Unit => []
    Int(_) => []
    Double(_) => []
    Neg(x) => [x]
    Add(x, y) => [x, y]
    Sub(x, y) => [x, y]
    Mul(x, y) => [x, y]
    Div(x, y) => [x, y]
    FNeg(x) => [x]
    FAdd(x, y) => [x, y]
    FSub(x, y) => [x, y]
    FMul(x, y) => [x, y]
    FDiv(x, y) => [x, y]
    IfEq(x, y, e1, e2) => add_to_array([x, y], union(fv(e1), fv(e2)))
    IfLe(x, y, e1, e2) => add_to_array([x, y], union(fv(e1), fv(e2)))
    Let((x, _), e1, e2) => union(fv(e1), remove(x, fv(e2)))
    Var(x) => [x]
    LetRec(f, rest) => {
      let mut free_vars = fv(f.body)
      for arg in f.args {
        free_vars = remove(arg.0, free_vars)
      }
      remove(f.name, union(free_vars, fv(rest)))
    }
    Apply(x, ys) => add_to_array([x], ys)
    Tuple(xs) => xs
    LetTuple(xts, y, e) => {
      let mut free_vars = fv(e)
      for xt in xts {
        free_vars = remove(xt.0, free_vars)
      }
      add_to_array([y], free_vars)
    }
    Get(x, y) => [x, y]
    Put(x, y, z) => [x, y, z]
    ExternalArray(x) => [x]
    ExternalFunctionApplication(_, xs) => xs
  }
}

// 辅助函数实现
pub fn add_to_array(
  arr : Array[Name],
  new_elements : Array[Name]
) -> Array[Name] {
  //TODO:引用传递
  for elem in new_elements {
    if not(arr.contains(elem)) {
      arr.push(elem)
    }
  }
  arr
}

pub fn union(arr1 : Array[Name], arr2 : Array[Name]) -> Array[Name] {
  add_to_array(arr1, arr2)
}

pub fn remove(element : Name, arr : Array[Name]) -> Array[Name] {
  arr.filter(fn(e) { e != element })
}

pub fn knf_program_to_closure(
  prog : @knf.Knf,
  extern_env : Map[String, Type]
) -> Program {
  match prog {
    Unit => { fundefs: [], body: Unit }
    Int(i) => { fundefs: [], body: Int(i) }
    Double(d) => { fundefs: [], body: Double(d) }
    Neg(x) => { fundefs: [], body: Neg(x) }
    Add(x, y) => { fundefs: [], body: Add(x, y) }
    Sub(x, y) => { fundefs: [], body: Sub(x, y) }
    Mul(x, y) => { fundefs: [], body: Mul(x, y) }
    Div(x, y) => { fundefs: [], body: Div(x, y) }
    FNeg(x) => { fundefs: [], body: FNeg(x) }
    FAdd(x, y) => { fundefs: [], body: FAdd(x, y) }
    FSub(x, y) => { fundefs: [], body: FSub(x, y) }
    FMul(x, y) => { fundefs: [], body: FMul(x, y) }
    FDiv(x, y) => { fundefs: [], body: FDiv(x, y) }
    IfEq(x, y, e1, e2) => {
      let e1_closure = knf_program_to_closure(e1, extern_env).body
      let e2_closure = knf_program_to_closure(e2, extern_env).body
      { fundefs: [], body: IfEq(x, y, e1_closure, e2_closure) }
    }
    IfLe(x, y, e1, e2) => {
      let e1_closure = knf_program_to_closure(e1, extern_env).body
      let e2_closure = knf_program_to_closure(e2, extern_env).body
      { fundefs: [], body: IfLe(x, y, e1_closure, e2_closure) }
    }
    Let((x, t), e1, e2) => {
      let e1_closure = knf_program_to_closure(e1, extern_env).body
      let e2_closure = knf_program_to_closure(e2, extern_env).body
      {
        fundefs: [],
        body: Let((x, type_to_lowtype(t)), e1_closure, e2_closure),
      }
    }
    Var(x) => { fundefs: [], body: Var(x) }
    // 处理递归定义
    LetRec(f, rest) => {
      for arg in f.args {
        extern_env[arg.0.to_string()] = arg.1
      }
      extern_env[f.name.to_string()] = f.ty
      let body = knf_program_to_closure(f.body, extern_env).body
      let free_vars = fv(f.body)
      let fvs = free_vars.map(
        fn(x) {
          match extern_env.get(x.to_string()) {
            Some(ty) => (x, type_to_lowtype(ty))
            None => @util.die(x.to_string() + " not found in extern_env")
          }
        },
      )
      // 创建函数定义
      let func_def = {
        name: f.name.to_string(),
        old_name: f.name, // 旧名称与新名称相同
        is_closure: true,
        ty: type_to_lowtype(f.ty),
        args: f.args.map(fn(arg) { (arg.0, type_to_lowtype(arg.1)) }),
        // 使用函数的参数
        formal_free_vars: fvs,
        body,
      }
      let cls = { name: func_def.name, actual_free_vars: free_vars }
      // 创建闭包
      let closure = MakeClosure(
        (f.name, type_to_lowtype(f.ty)),
        cls,
        knf_program_to_closure(rest, extern_env).body,
      )
      // 返回新的程序，包含闭包
      let fundefs = knf_program_to_closure(rest, extern_env).fundefs
      fundefs.push(func_def)
      {
        fundefs, // 返回函数定义
        body: closure,
      }
    }
    Apply(x, ys) => { fundefs: [], body: CallClosure(x, ys) } //TODO: 处理直接函数调用
    Tuple(xs) => { fundefs: [], body: MakeTuple(xs) }
    LetTuple(xts, y, e) => {
      for xt in xts {
        extern_env[xt.0.to_string()] = xt.1
      }
      let e_closure = knf_program_to_closure(e, extern_env).body
      {
        fundefs: [],
        body: LetTuple(
          xts.map(fn(x) { (x.0, type_to_lowtype(x.1)) }),
          y,
          e_closure,
        ),
      }
    }
    Get(x, y) => { fundefs: [], body: ArrayGet(x, y) }
    Put(x, y, z) => { fundefs: [], body: ArrayPut(x, y, z) }
    ExternalArray(x) => { fundefs: [], body: ExternalArray(x.to_string()) }
    ExternalFunctionApplication(name, xs) =>
      { fundefs: [], body: CallDirect(name, xs) }
  }
  // 处理函数调用
}

pub fn type_to_lowtype(ty : Type) -> LowType {
  match ty {
    Type::Unit => LowType::Unit
    Type::Bool => LowType::Bool
    Type::Int => LowType::Int
    Type::Double => LowType::Double
    Type::Tuple(tys) => LowType::Tuple(tys.map(type_to_lowtype))
    Type::Array(ty) => LowType::Array(type_to_lowtype(ty))
    Type::Ptr => LowType::Ptr
    Type::Fun(args, ty) => {
      let args_lowtype = args.map(type_to_lowtype)
      let ret_lowtype = type_to_lowtype(ty)
      LowType::ClosureFn(args_lowtype, ret_lowtype)
    }
    _ => @util.die(ty.to_string())
  }
}

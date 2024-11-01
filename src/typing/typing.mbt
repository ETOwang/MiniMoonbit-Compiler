//类型推导上下文
pub let extenv : Map[String, @types.Type] = {
  "read_int": Fun([], Int),
  "print_int": Fun([Int], Unit),
  "read_char": Fun([], Int),
  "print_char": Fun([Int], Unit),
  "print_newline": Fun([], Unit),
  "int_of_float": Fun([Double], Int),
  "float_of_int": Fun([Int], Double),
  "truncate": Fun([Double], Int),
  "floor": Fun([Double], Double),
  "abs_float": Fun([Double], Double),
  "sqrt": Fun([Double], Double),
  "sin": Fun([Double], Double),
  "cos": Fun([Double], Double),
  "atan": Fun([Double], Double),
}

pub fn logger(msg : String) -> Unit {
  //println(msg)
}

type LocalCtx @immut/hashmap.T[String, @types.Type]

// 类型缺失时生成新变量
fn new_tvar() -> @types.Type {
  Var(Ref::new(None))
}

type! TyErr {
  Mismatch(@types.Type, @types.Type, String) // 类型不匹配错误，包含期望类型和实际类型
  Other(String) // 其他错误，包含错误描述
} derive(Show)

fn repr(ty : @types.Type) -> @types.Type {
  match ty {
    Var(t) =>
      match t.val {
        Some(inner_ty) => {
          let actual_ty = repr(inner_ty)
          t.val = Some(actual_ty)
          actual_ty
        }
        _ => ty
      }
    other_ty => other_ty
  }
}

fn check_occur(tvar : @types.Type, ty : @types.Type) -> Unit!TyErr {
  if occur_check(tvar, ty) {
    raise TyErr::Other("Type variable occurs in type")
  }
}

// 定义 occur_check 函数，用于检查类型变量是否在类型中出现
fn occur_check(tvar : @types.Type, ty : @types.Type) -> Bool {
  //TODO
  false
}

//归一化
fn unify(t1 : @types.Type, t2 : @types.Type) -> Unit!TyErr {
  let t1 = repr(t1)
  let t2 = repr(t2)
  match (t1, t2) {
    (Int, Int) | (Bool, Bool) | (Double, Double) | (Unit, Unit) => ()
    (Var(t) as tvar, ty) | (ty, Var(t) as tvar) => {
      check_occur!(tvar, ty)
      t.val = Some(ty)
    }
    //Todo;
    //handle the function, tuple, and array Type
    // 函数类型处理
    (Fun(params1, ret1), Fun(params2, ret2)) => {
      if params1.length() != params2.length() {
        raise TyErr::Mismatch(
          t1, t2, "Function parameter count mismatch at Line 99",
        )
      }
      for index = 0; index < params1.length(); index = index + 1 {
        let p1 = params1[index]
        let p2 = params2[index]
        unify!(p1, p2)
      }
      unify!(ret1, ret2)
    }

    // 元组类型处理
    (Tuple(types1), Tuple(types2)) => {
      if types1.length() != types2.length() {
        raise TyErr::Mismatch(
          t1, t2, "Tuple element count mismatch at Line 111",
        )
      }
      for index = 0; index < types1.length(); index = index + 1 {
        let t1_elem = types1[index]
        let t2_elem = types2[index]
        unify!(t1_elem, t2_elem)
      }
    }

    // 数组类型处理
    (Array(elem_type1), Array(elem_type2)) => unify!(elem_type1, elem_type2)
    _ => raise TyErr::Mismatch(t1, t2, "Type mismatch at Line 127")
  }
}

//类型推断
fn infer(ctx : LocalCtx, e : @types.Syntax) -> @types.Type!TyErr {
  match e {
    Unit => Unit
    Int(_) => Int
    Bool(_) => Bool
    Double(_) => Double
    Var(x) =>
      match ctx._[x] {
        Some(t) => t
        //新类型变量
        None => {
          let t = new_tvar()
          extenv[x] = t
          t
        }
      }

    //函数类型推导
    LetRec({ name: (f, t), args, body }, rest) => {
      let env_with_f = ctx._.add(f, t)
      let params_ty = args.map(fn { (_, t) => t })
      let mut env_with_params = env_with_f
      for p in args {
        env_with_params = env_with_params.add(p.0, p.1)
      }
      let body_ty = infer!(env_with_params, body)
      unify!(t, Fun(params_ty, body_ty))
      infer!(env_with_f, rest)
    }

    //函数调用类型推导
    App(f, args) => {
      let ret_ty = new_tvar()
      let f_ty = infer!(ctx, f)
      let args_ty = []
      for a in args {
        args_ty.push(infer!(ctx, a))
      }
      unify!(f_ty, Fun(args_ty, ret_ty))
      ret_ty
    }

    //一元负号推导
    Neg(expr, ~kind) as tvar => {
      let ty = infer!(ctx, expr) // 推断表达式类型
      match kind {
        Some(Int) => {
          unify!(ty, Int)
          Int
        }
        Some(Double) => {
          unify!(ty, Double)
          Double
        }
        None =>
          match ty {
            Var(t) =>
              match t.val {
                None => {
                  tvar.kind = Some(Int)
                  Int
                }
                Some(ty) => {
                  tvar.kind = Some(
                    match ty {
                      Int => Int
                      Double => Double
                      _ => Int
                    },
                  )
                  ty
                }
              }
            t => {
              tvar.kind = Some(
                match t {
                  Int => Int
                  Double => Double
                  _ => Int
                },
              )
              t
            }
          }
      }
    }
    //二元算术推导
    Prim(lhs, rhs, _, ~kind) as tvar => {
      let lhs_ty = infer!(ctx, lhs)
      let rhs_ty = infer!(ctx, rhs)
      match kind {
        Some(Int) => {
          unify!(lhs_ty, Int)
          unify!(rhs_ty, Int)
          Int
        }
        Some(Double) => {
          unify!(lhs_ty, Double)
          unify!(rhs_ty, Double)
          Double
        }
        None =>
          match (lhs_ty, rhs_ty) {
            (Var(l), Var(r)) =>
              match (l.val, r.val) {
                (None, None) => {
                  tvar.kind = Some(Int)
                  Int
                }
                _ => {
                  unify!(lhs_ty, rhs_ty)
                  tvar.kind = Some(
                    match lhs_ty {
                      Int => Int
                      Double => Double
                      _ => Int
                    },
                  )
                  lhs_ty
                }
              }
            _ => {
              unify!(lhs_ty, rhs_ty)
              tvar.kind = Some(
                match lhs_ty {
                  Int => Int
                  Double => Double
                  _ => Int
                },
              )
              lhs_ty
            }
          }
      }
    }

    //数组类型推导
    Array(lhs, rhs) => {
      let first = infer!(ctx, lhs)
      let second = infer!(ctx, rhs)
      unify!(first, Int)
      Array(second)
    }

    //If推导
    If(cond, then_expr, else_expr) => {
      let cond_ty = infer!(ctx, cond)
      unify!(cond_ty, Bool) // 条件必须是布尔类型
      let then_ty = infer!(ctx, then_expr)
      let else_ty = infer!(ctx, else_expr)
      unify!(then_ty, else_ty) // 两个分支的类型必须一致
      then_ty
    }

    //比较类型推导
    Eq(lhs, rhs) | LE(lhs, rhs) => {
      let lhs_ty = infer!(ctx, lhs)
      let rhs_ty = infer!(ctx, rhs)
      unify!(lhs_ty, rhs_ty) // 左右操作数类型必须一致
      Bool
    }
    Not(expr) => {
      let ty = infer!(ctx, expr)
      unify!(ty, Bool) // 操作数必须是布尔类型
      Bool
    }
    Tuple(elements) => {
      let types = []
      for element in elements {
        types.push(infer!(ctx, element))
      }
      Tuple(types)
    }
    Get(vector, subscript) => {
      let vector_ty = infer!(ctx, vector)
      let subscript_ty = infer!(ctx, subscript)
      match vector_ty {
        Array(t) => {
          unify!(subscript_ty, Int)
          t
        }
        Var(t) =>
          match t.val {
            Some(ty) =>
              match ty {
                Array(t) => {
                  unify!(subscript_ty, Int)
                  t
                }
                _ =>
                  raise TyErr::Mismatch(
                    vector_ty, subscript_ty, "Get vector type mismatch at Line 318",
                  )
              }
            None =>
              raise TyErr::Mismatch(
                vector_ty, subscript_ty, "Get vector type mismatch at Line 318",
              )
          }
        _ =>
          raise TyErr::Mismatch(
            vector_ty, subscript_ty, "Get vector type mismatch at Line 318",
          )
      }
    }
    LetTuple(types, tuple_expr, rest) => {
      let tuple_ty = infer!(ctx, tuple_expr)
      unify!(tuple_ty, Tuple(types.map(fn { (_, t) => t })))
      let mut env_with_params = ctx
      for index = 0; index < types.length(); index = index + 1 {
        env_with_params = env_with_params._.add(types[index].0, types[index].1)
      }
      infer!(env_with_params, rest)
    }
    Let(var, var_value, rest) => {
      let var_ty = infer!(ctx, var_value)
      unify!(var_ty, var.1)
      infer!(ctx._.add(var.0, var.1), rest)
    }
    Put(lhs, rhs, rest) => {
      let lhs_ty = repr(infer!(ctx, lhs))
      let rhs_ty = repr(infer!(ctx, rhs))
      unify!(lhs_ty, rhs_ty)
      infer!(ctx, rest)
    }
  }
}

//类型清理
fn deref_type(t : @types.Type) -> @types.Type {
  match t {
    Fun(params, result) =>
      Fun(params.map(fn { t => deref_type(t) }), deref_type(result))
    Tuple(types) => Tuple(types.map(fn { t => deref_type(t) }))
    Array(t) => Array(deref_type(t))
    Var(inner_t) =>
      match inner_t.val {
        Some(ty) => {
          let ty = deref_type(ty)
          inner_t.val = Some(ty)
          ty
        }
        None => {
          inner_t.val = Some(Unit)
          Unit
        }
      }
    t => t
  }
}

// 对整个语法树进行清理
fn deref_term(syntax : @types.Syntax) -> @types.Syntax {
  match syntax {
    //整数、布尔值、变量无需处理
    Int(_) | Bool(_) | Unit | Double(_) => syntax
    Var(x) => Var(x)

    // 对 let 表达式，清理绑定的类型和剩余部分
    Let((x, t), expr1, expr2) => {
      let new_t = deref_type(t)
      let new_expr1 = deref_term(expr1)
      let new_expr2 = deref_term(expr2)
      Let((x, new_t), new_expr1, new_expr2)
    }

    // 对递归函数 letrec 表达式，清理函数体及其他部分
    LetRec({ name, args, body }, rest) => {
      let new_body = deref_term(body)
      let new_rest = deref_term(rest)
      let func_def : @types.Fundef = {
        name: (name.0, deref_type(name.1)),
        args: args.map(fn { (x, t) => (x, deref_type(t)) }),
        body: new_body,
      }
      LetRec(func_def, new_rest)
    }

    // 对函数应用表达式，清理函数及参数类型
    App(f, args) => {
      let new_f = deref_term(f)
      let new_args = args.map(deref_term)
      App(new_f, new_args)
    }

    // 对 tuple 表达式，清理每个元素类型
    Tuple(elements) => {
      let new_elements = elements.map(deref_term)
      Tuple(new_elements)
    }

    // 对数组表达式，清理元素类型
    Array(arr_expr, len_expr) => {
      let new_arr_expr = deref_term(arr_expr)
      let new_len_expr = deref_term(len_expr)
      Array(new_arr_expr, new_len_expr)
    }

    // 其他表达式类型，如函数定义、数组等
    Prim(lhs, rhs, op, ~kind) => {
      let new_lhs = deref_term(lhs)
      let new_rhs = deref_term(rhs)
      Prim(new_lhs, new_rhs, op, ~kind)
    }
    Eq(lhs, rhs) => {
      let new_lhs = deref_term(lhs)
      let new_rhs = deref_term(rhs)
      Eq(new_lhs, new_rhs)
    }
    Not(expr) => {
      let new_expr = deref_term(expr)
      Not(new_expr)
    }
    LE(lhs, rhs) => {
      let new_lhs = deref_term(lhs)
      let new_rhs = deref_term(rhs)
      LE(new_lhs, new_rhs)
    }
    If(cond, then_expr, else_expr) => {
      let new_cond = deref_term(cond)
      let new_then_expr = deref_term(then_expr)
      let new_else_expr = deref_term(else_expr)
      If(new_cond, new_then_expr, new_else_expr)
    }
    Get(vector, subscript) => {
      let new_vector = deref_term(vector)
      let new_subscript = deref_term(subscript)
      Get(new_vector, new_subscript)
    }
    LetTuple(types, tuple_expr, rest) => {
      let new_types = types.map(fn { (x, t) => (x, deref_type(t)) })
      let new_tuple_expr = deref_term(tuple_expr)
      let new_rest = deref_term(rest)
      LetTuple(new_types, new_tuple_expr, new_rest)
    }
    Put(vector, subscript, rest) => {
      let new_vector = deref_term(vector)
      let new_subscript = deref_term(subscript)
      let new_rest = deref_term(rest)
      Put(new_vector, new_subscript, new_rest)
    }
    Neg(expr, ~kind) => {
      let new_expr = deref_term(expr)
      Neg(new_expr, ~kind)
    }
  }
}

//主函数
pub fn typing(e : @types.Syntax) -> @types.Syntax!TyErr {
  let mut ctx = @immut/hashmap.T::new()
  for item in extenv {
    ctx = ctx.add(item.0, item.1)
  }
  unify!(Unit, infer!(ctx, e))
  for ext_f, ext_t in extenv {
    extenv[ext_f] = deref_type(ext_t)
  }
  deref_term(e)
}

pub fn wrapper(e : @types.Syntax) -> @types.Syntax {
  try {
    typing!(e)
  } catch {
    TyErr::Mismatch(t1, t2, msg) => {
      println("Type mismatch: " + t1.to_string() + " and " + t2.to_string())
      println(msg)
      @util.die("Type mismatch")
    }
    TyErr::Other(msg) => {
      println(msg)
      @util.die("Type error")
    }
  }
}

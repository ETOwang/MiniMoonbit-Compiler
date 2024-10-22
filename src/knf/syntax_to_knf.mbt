pub typealias LocalEnv = @immut/hashmap.T[String, Type]

// Assuming Op is defined in a module named 'operations'

struct KnfEnv {
  mut counter : Int
  externals : @immut/hashmap.T[String, Type]

  name_and_type : @moonbitlang/core/hashmap.T[Name, Type]
}

struct SignTable { 
  table : Map[String, (Name, Type)]
}
let signTable : SignTable = {table: Map::new()}
let externalSignTable : Map[String, (Name, Type)] = Map::new()

pub fn getTypeFromSynax(s: @types.Syntax) -> Type {
  Type::Unit
}
pub fn KnfEnv::new(externals : @immut/hashmap.T[String, Type]) -> KnfEnv {
  { counter: 1, externals, name_and_type: @moonbitlang/core/hashmap.T::new() }
}

pub fn KnfEnv::init_counter_from_existing(
  self : KnfEnv,
  existing : Knf
) -> Unit {
  self.counter = knf_max_counter(existing) + 1
}

fn KnfEnv::new_temp(self : KnfEnv) -> Name {
  let temp = Name::slot_only(self.counter)
  self.counter += 1
  temp
}

fn KnfEnv::new_named_temp(self : KnfEnv, name : Name) -> Name {
  let counter = self.counter
  self.counter += 1
  { ..name, slot: counter }
}

// fn bind (f: String, xs: Array[Name], e2s: Array[@types.Syntax], self: KnfEnv, t: Type, ifExternal: Bool) -> Knf {
//   if (e2s.is_empty()) {
//     if ifExternal {
//       return ExternalFunctionApplication(f, xs)
//     }
//     else {
//       let fName = signTable.table.get(f).unwrap().0
//       return Apply(fName, xs)
//     }
//   }
//   else {
//     let e2 = e2s.pop().unwrap()
//     insert_let(self, to_knf(self, e2), t, fn (y: Name) -> Knf {
//       xs.push(y)
//       bind(f, xs, e2s, self, t, ifExternal)
//     })
//   }
// }



// 提取Knf中的自由变量，和alpha变换有关
fn fv(expr: Knf) -> Set[Name] {
  let varNameSet :Set[Name] = Set::new();
    match expr {
        Unit | Int(_) | Double(_) | ExternalArray(_) => return varNameSet
        Neg(x) | FNeg(x) => {
          varNameSet.insert(x)
          return varNameSet
        }
        Add(x, y) | Sub(x, y) | FAdd(x, y) | FSub(x, y) | FMul(x, y) | FDiv(x, y) | Get(x, y) => {
          varNameSet.insert(x)
          varNameSet.insert(y)
          return varNameSet
        }
        IfEq(x, y, e1, e2) | IfLe(x, y, e1, e2) => {
          varNameSet.insert(x)
          varNameSet.insert(y)
          ignore(varNameSet.union(fv(e1)))
          ignore(varNameSet.union(fv(e2)))
          return varNameSet
        }
        Let((x, t), e1, e2) => {
          ignore(varNameSet.remove(x))
          let  varInE2 = fv(e2)
          for item in varInE2 {
            ignore(varNameSet.remove(item))
          }
          ignore(varNameSet.union(fv(e1)))
          varNameSet
          //  S.union(fv(e1), S. remove(x, fv(e2)))
        }
        Var(x) => {
          varNameSet.insert(x)
          return varNameSet
        }
        LetRec({name :n, ty: t, args: params, body: e1}, e2) => {
          let varInE1 = fv(e1)
          let varInParams:Set[Name] = Set::new()
          for item in params {
            varInParams.insert(item.0)
          }
          for item in varInE1 {
            if varInParams.contains(item) == false {
              varNameSet.insert(item)
            }
          }
          let varInE2 = fv(e2)
          ignore(varInE2.union(varNameSet))
          varNameSet.remove(n)
          return varNameSet
          // let zs = Set::difference(fv(e1), Set::of_list(List::map(fst, params)))
          //   let zs = Set.difference(fv(e1), S.of_list(List.map(fst, yts)));
          //   S.diff(S.union(zs, fv(e2)), S.singleton(x))
        } 
        Apply(x, ys) => {
          for item in ys {
            if varNameSet.contains(item) == false {
              varNameSet.insert(item)
            }
          }
          if varNameSet.contains(x) {
            varNameSet.remove(x)
          }
          return varNameSet
        }
        Tuple(xs) | ExternalFunctionApplication(_, xs) => {
          for item in xs {
            if varNameSet.contains(item) == false {
              varNameSet.insert(item)
            }
          }
          return varNameSet
        }
        Put(x, y, z) => {
          varNameSet.insert(x)
          varNameSet.insert(y)
          varNameSet.insert(z)
          return varNameSet
        }
        LetTuple(xs, y, e) => {
          varNameSet.insert(y)
          let varInE = fv(e)
          let varInXs:Set[Name] = Set::new()
          for item in xs {
            varInXs.insert(item.0)
          }
          for item in varInE {
            if varInXs.contains(item) == false {
              varNameSet.insert(item)
            }
          }
          ignore(varNameSet.union(fv(e)))
          return varNameSet
        } 
        // S.add(y, S.diff(fv(e), S.of_list(List.map(fst, xs))))
    }
}



fn insert_let(self : KnfEnv, e: Knf, t: Type, k: (Name) -> Knf) -> Knf  {
    match e {
        Var(x) => k(x) // 如果是变量，直接调用继续函数 k
        _ => {
            let x = new_temp(self) // 生成一个临时标识符
            let e1 = k(x); // 调用继续函数，得到新的表达式和类型
            return Let((x, t), e, e1) // 创建 Let 表达式并返回
        }
    }
}


pub fn get_knf_type(self: KnfEnv, knf: Knf) -> Type {
  match knf {
    Knf::Unit => Type::Unit           // 如果是 Unit，返回 Type.Unit
    Knf::Int(_) => Type::Int           // 如果是 Int，返回 Type.Int
    Knf::Double(_) => Type::Double     // 如果是 Double，返回 Type.Double
    Knf::Neg(_) => Type::Int // 假设 Neg 返回 Int 类型
    Knf::Add(_, _) => Type::Int // 假设 Add 返回 Int 类型
    Knf::Sub(_, _) => Type::Int
    Knf::Mul(_, _) => Type::Int
    Knf::Div(_, _) => Type::Int
    Knf::FNeg(_) => Type::Double // 假设 FNeg 返回 Double 类型
    Knf::FAdd(_, _) => Type::Double
    Knf::FSub(_, _) => Type::Double
    Knf::FMul(_, _) => Type::Double
    Knf::FDiv(_, _) => Type::Double
    Knf::IfEq(_, _, true_case, false_case) => {
      // 假设 IfEq 返回 true_case 的类型
      get_knf_type(self, true_case)
    }
    Knf::IfLe(_, _, true_case, false_case) => {
      // 假设 IfLe 返回 true_case 的类型
      get_knf_type(self, true_case)
    }
    Knf::Let(_, _, body) => get_knf_type(self, body) // 假设 Let 返回 body 的类型
    Knf::Var(name) => {
      match self.name_and_type.get(name) {
        Some(ty) => ty
        None => abort("Type not found for variable: \{name}")
      }
    }
    Knf::LetRec(_, body) => get_knf_type(self, body) // 假设 LetRec 返回 body 的类型
    Knf::Apply(_, _) => Type::Int // 假设 Apply 返回 Int 类型
    Knf::Tuple(elements) => {
      let types: Array[Type] = Array::new();
      for element in elements {
        types.push(Type::Int); // 这里统一用 Int 代替，实际应该根据具体元素类型来处理
      }
      Type::Tuple(types) // 返回包含具体类型的元组
    }
    Knf::LetTuple(_, _, body) => get_knf_type(self, body) // 假设 LetTuple 返回 body 的类型
    Knf::Get(_, _) => Type::Int // 假设 Get 返回 Int 类型
    Knf::Put(_, _, _) => Type::Unit // 假设 Put 返回 Unit 类型
    Knf::ExternalArray(_) => Type::Array(Type::Int)
    Knf::ExternalFunctionApplication(_, _) => Type::Unit
    // 可以添加更多变体的处理...
  }
}

pub fn addVarToEnv(self: KnfEnv, x: String, t: Type) -> Name {
  return new_temp(self)
}

pub fn KnfEnv::to_knf(self : KnfEnv, s : @types.Syntax) -> Knf { 
  match s {
    Unit => Knf::Unit

    Bool(b) => Knf::Int(if b { 1 } else { 0 })

    Int(i) => Knf::Int(i)

    Double(d) => Knf::Double(d)

    // Var(x) => Knf::Var(new_temp(self))
    
    
    // 对每一个子节点递归调用 to_knf!，然后将结果作为参数构建新的 Knf
    // Tuple(elements) => {
    //   let mut bindings: Array[(Name, Knf)] = []
    //   let mut child_names : Array[Name] = []
      
    //   // 使用 LetTuple 将所有绑定组合在一起
    //   let mut tuple_type:Array[(Name, Type)] =  []// 先转换为数组
    //   let tuple_name = new_temp(self); // 创建新的元组名称
    //   Knf::LetTuple(
    //     {
    //       for elem in elements {
    //         let name = new_temp(self) // 生成唯一名称
    //         let knf_elem = to_knf(self, elem) // 递归转换
    //         let child = Knf::Let((name, get_knf_type(self, knf_elem)), knf_elem, knf_elem)
    //         child_names.push(name)
    //         bindings.push((name, child))
    //       } // 保存绑定
    //       for binding in bindings {
    //         tuple_type.push((binding.0, get_knf_type(self, binding.1))) // 提取名字和类型
    //       } 
    //       else {
    //         tuple_type
    //       }
    //     }, 
    //     tuple_name, 
    //     Knf::Tuple(
    //         child_names
    //     )); // 组合为 LetTuple
    //   // let mut bindings = []
    //   // let mut knf_elements = []

    //   // for elem in elements {
    //   //   let name = new_temp(self) // 生成唯一名称
    //   //   let knf_elem = to_knf!(self, elem) // 递归转换
    //   //   bindings.push((name, knf_elem)) // 保存绑定
    //   //   knf_elements.push(Knf::Var(name)) // 使用变量
    //   // }

    //   // // 从后往前创建 Let 绑定
    //   // let mut result = knf_elements.pop().unwrap() // 先取出最后一个元素
    //   // while  bindings.length() > 0 {
    //   //   let binding_tmp = bindings.pop().unwrap() // 逐个取出绑定
    //   //   let tmp:(Name, Type) = (binding_tmp.0, get_knf_type(self, binding_tmp.1))
    //   //   let knf_element = knf_elements.pop().unwrap() // 逐个取出元素
    //   //   result = Knf::Let(tmp, knf_element, result); // 逐步构建 ANF
    //   // }
    //   // result
    // }


    // NOT: Let((newName, type), childSynax, FNeg)
    Not(inner) => {
      to_knf(self, If(inner, Int(1), Int(0)))
    }

    Neg(inner, ..) => {
      insert_let(self, to_knf(self, inner), Type::Int, fn (x: Name) -> Knf { Neg(x) })
    }

    Eq(_, _) | LE(_, _) as cmp => {
      to_knf(self, If(cmp, Int(1), Int(0)))
    }

    If(Not(e1), e2, e3) => {
      to_knf(self, If(e1, e3, e2))
    }

    If(Eq(e1, e2), e3, e4) => {
      insert_let(self, to_knf(self, e1), Type::Unit, fn (x: Name) -> Knf {
        insert_let(self, to_knf(self, e2), Type::Unit, fn (y: Name) -> Knf {
          let e3tmp = to_knf(self, e3)
          let e4tmp = to_knf(self, e4)
          IfEq(x, y, e3tmp, e4tmp)
        })
      })
    }

    If(LE(e1, e2), e3, e4) => {
      insert_let(self, to_knf(self, e1), Type::Unit, fn (x: Name) -> Knf {
        insert_let(self, to_knf(self, e2), Type::Unit, fn (y: Name) -> Knf {
          let e3tmp = to_knf(self, e3)
          let e4tmp = to_knf(self, e4)
          IfLe(x, y, e3tmp, e4tmp)
        })
      })
    }

    If(e1, e2, e3) => {
      to_knf(self, If(Eq(e1, Bool(false)), e3, e2))
    }

    // Syntax.Let((x, t), e1, e2) ->
    //   let e1', t1 = g env e1 in
    //   let e2', t2 = g (M.add x t env) e2 in
    //   Let((x, t), e1', e2'), t2
    Let((x, t), e1, e2) => {
      let e1tmp = to_knf(self, e1)
      let xName = addVarToEnv(self, x, t)
      let e2tmp = to_knf(self, e2)
      Let((xName, t), e1tmp, e2tmp)
    }

  //   Syntax.Var(x) when M.mem x env -> Var(x), M.find x env
  // | Syntax.Var(x) -> (* 外部配列の参照 *)
  //     (match M.find x !Typing.extenv with
  //     | Type.Array(_) as t -> ExtArray x, t
  //     | _ -> failwith (Printf.sprintf "external variable %s does not have an array type" x))
    Var(x) => {
      if signTable.table.get(x).is_empty() == false {
        let xName:Name = signTable.table.get(x).unwrap().0
        Knf::Var(xName)
      }
      else {
        let external = self.externals.find(x)
        match external.unwrap() {
          Array(_) => {
            ExternalArray(externalSignTable.get(x).unwrap().0)
          }
          _ => abort("External variable does not have an array type")
        }
      }
    }

    LetRec({name: (x, t), args: yts, body: e1}, e2) => {
      let xName = addVarToEnv(self, x, t)
      let e2Tmp = to_knf(self, e2)
      let ytsName = []
      for item in yts {
        ytsName.push((addVarToEnv(self, item.0, item.1), item.1))
      }
      LetRec({name: xName,ty: t,  args: ytsName, body: to_knf(self, e1)}, e2Tmp)
    }

    App(Var(f), e2s) => {
      if signTable.table.get(f).is_empty() {
        let external = self.externals.find(f).unwrap()
        match external {
          Fun(_, t) => {
            let xs: Array[Name] = Array::new()

            // let bind = fn (xs: Array[Name], e2s: Array[@types.Syntax], self: KnfEnv, t: Type) -> Knf {
            //   loop e2s, xs {  
            //     [], xs => break ExternalFunctionApplication(f, xs) // break 可以省略
            //     _, xs => continue e2s, xs 
            //     // {
            //     //   let e2 = e2s.pop().unwrap()
            //     //   ignore(insert_let(self, to_knf(self, e2), t, fn (y: Name) -> Knf {
            //     //     bind(xs.push(y), e2s, self, t)
            //     //   }))
            //     // }
            //   }
            // }

            fn bind (xs: Array[Name]) -> Knf {
              if (e2s.is_empty()) {
                return ExternalFunctionApplication(f, xs)
              }
              else {
                let e2 = e2s.pop().unwrap()
                insert_let(self, to_knf(self, e2), t, fn (y: Name) -> Knf {
                  bind(xs)
                })
              }
            }
            bind(xs)
          }
          _ => abort("External function not found")
        }
      }
      else {
        abort("false")
      }
    }

    App(e1, e2s) => {
      let e1Knf = to_knf(self, e1)
      let e1Type = get_knf_type(self, e1Knf)
      match e1Type {
        Fun(_, t) => {
          insert_let(self, e1Knf, get_knf_type(self, e1Knf), fn (f: Name) -> Knf {
            let xs: Array[Name] = Array::new()
            fn bind (xs: Array[Name]) -> Knf {
              if (e2s.is_empty()) {
                return Apply(f, xs)
              }
              else {
                let e2 = e2s.pop().unwrap()
                insert_let(self, to_knf(self, e2), t, fn (y: Name) -> Knf {
                  bind(xs)
                })
              }
            }
            bind(xs)
          })
        }
        _ => abort("Not a function")
      }
    }

    Tuple(es) => {
      let  xs: Array[Name] = Array::new()
      let  ts: Array[Type] = Array::new()
      for e in es {
        let x = new_temp(self) // TODO: 需要取得变量名字
        xs.push(x)
        let t = getTypeFromSynax(e)
        ts.push(t)
      }
      fn bind(xs: Array[Name], es: Array[@types.Syntax], self: KnfEnv) -> Knf {
        if es.is_empty() {
          return Tuple(xs)
        }
        else {
          let e = es.pop().unwrap()
          insert_let(self, to_knf(self, e), Type::Int, fn (y: Name) -> Knf {
            xs.push(y)
            bind(xs, es, self)
          })
        }
      }
      bind(Array::new(), es, self)
    }

    LetTuple(xts, e1, e2) => {
      let e1Knf = to_knf(self, e1)
      insert_let(self,  e1Knf, get_knf_type(self, e1Knf), 
        fn(y: Name) -> Knf {
          let xtsName = []
          for item in xts {
            xtsName.push((addVarToEnv(self, item.0, item.1), item.1))
          }
          LetTuple(xtsName, y, to_knf(self, e2))
      })
    }



    Array(e1, e2) => {
      insert_let(self, to_knf(self, e1), getTypeFromSynax(e1), 
        fn (x: Name) -> Knf {
          let e2Knf = to_knf(self, e2)
          insert_let(self, e2Knf, getTypeFromSynax(e2), 
            fn (y: Name) -> Knf {
              let l = { 
                match e2 {
                  Double(_) => "create_double_array"
                  _ => "create_array"
                }
              }
              ExternalFunctionApplication(l, [x, y])
            })
        })
    }

    Get(e1, e2) => {
      let e1Knf = to_knf(self, e1)
      match get_knf_type(self, e1Knf) {
        Array(x) => {
          insert_let(self, e1Knf, x, 
            fn (x: Name) -> Knf {
              insert_let(self, to_knf(self, e2), Type::Int, 
                fn (y: Name) -> Knf {
                  Get(x, y)
                })
            })
        }
        _ => {
          abort("Not an array")
        }
      }
    }

    Put(e1, e2, e3) => {
      insert_let (self, to_knf(self, e1), getTypeFromSynax(e1), 
        fn (x: Name) -> Knf {
          insert_let(self, to_knf(self, e2), getTypeFromSynax(e2), 
            fn (y: Name) -> Knf {
              insert_let(self, to_knf(self, e3), getTypeFromSynax(e3), 
                fn (z: Name) -> Knf {
                  Put(x, y, z)
                })
            })
        })
    }





    
  
    Prim(a, b, op, kind = k) => {
      if op == @types.Op::Add && k == Some(@types.Kind::Int) {
        let a_name:@types.Name = new_temp(self)
        let b_name:@types.Name = new_temp(self)
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf(self, b), 
            Knf:: Add(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Add && k == Some(@types.Kind::Double) {
        let a_name:@types.Name = new_temp(self)
        let b_name:@types.Name = new_temp(self)
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf(self, b), 
            Knf:: FAdd(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Sub && k == Some(@types.Kind::Int) {
        let a_name:@types.Name = new_temp(self)
        let b_name:@types.Name = new_temp(self)
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf(self, b), 
            Knf:: Sub(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Sub && k == Some(@types.Kind::Double) {
        let a_name:@types.Name = new_temp(self)
        let b_name:@types.Name = new_temp(self)
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf(self, b), 
            Knf:: FSub(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Mul && k == Some(@types.Kind::Int) {
        let a_name:@types.Name = new_temp(self)
        let b_name:@types.Name = new_temp(self)
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf(self, b), 
            Knf:: Mul(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Mul && k == Some(@types.Kind::Double) {
        let a_name:@types.Name = new_temp(self)
        let b_name:@types.Name = new_temp(self)
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf(self, b), 
            Knf:: FMul(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Div && k == Some(@types.Kind::Int) {
        let a_name:@types.Name = new_temp(self)
        let b_name:@types.Name = new_temp(self)
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf(self, b), 
            Knf:: Div(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Div && k == Some(@types.Kind::Double) {
        let a_name:@types.Name = new_temp(self)
        let b_name:@types.Name = new_temp(self)
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf(self, b), 
            Knf:: Div(a_name, b_name)
          )
        )
      }
      else {
        abort("todo")
      }
    }
  }
  // abort("todo")

}

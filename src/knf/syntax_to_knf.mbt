pub typealias LocalEnv = @immut/hashmap.T[String, Type]

// Assuming Op is defined in a module named 'operations'

struct KnfEnv {
  mut counter : Int
  externals : @immut/hashmap.T[String, Type]
  signTable : @hashmap.T[String, (Name, Type)]
  funcTable : @hashmap.T[String, (Name, Type)]
  func_name_and_type : @hashmap.T[Name, Type]
  name_and_type : @hashmap.T[Name, Type]
}

pub fn addVarToEnv(env : KnfEnv, s : String, n : Name, t : Type) -> Bool {
  if env.signTable[s] != None && env.signTable[s].unwrap().1 == Type::Unit {
    ignore(env.signTable.remove(s))
    env.signTable[s] = (n, t)
    env.name_and_type[n] = t
    return true
  }
  env.signTable[s] = (n, t)
  env.name_and_type[n] = t
  true
}

pub fn addFuncToEnv(env : KnfEnv, s : String, n : Name, t : Type) -> Bool {
  env.funcTable[s] = (n, t)
  env.func_name_and_type[n] = t
  true
}

pub fn getVarFromEnv(env : KnfEnv, s : String) -> (Name, Type) {
  if env.signTable[s] != None {
    // println("vvvvv")
    // println(s)
    // println(env.signTable[s].unwrap())
    return env.signTable[s].unwrap()
  }
  return (Name::slot_only(0), Type::Unit)
}

pub fn getFuncFromEnv(env : KnfEnv, s : String) -> (Name, Type) {
  if env.funcTable[s] != None {
    return env.funcTable[s].unwrap()
  }
  return (Name::slot_only(0), Type::Unit)
}

pub fn getTypeFromName(env : KnfEnv, n : Name) -> Type {
  match env.name_and_type[n] {
    Some(t) => t
    None => {
      println(n)
      for item in env.name_and_type {
        println(item)
      }
      println("Func")
      for item in env.func_name_and_type {
        println(item)
      }
      println("Type not found1")
      // for item in env.signTable {
      //   println(item)
      // }
      abort("Type not found")
    }
  }
}

pub fn KnfEnv::new(externals : @immut/hashmap.T[String, Type]) -> KnfEnv {
  {
    counter: 1,
    externals,
    signTable: @hashmap.T::new(),
    func_name_and_type: @hashmap.T::new(),
    funcTable: @hashmap.T::new(),
    name_and_type: @hashmap.T::new(),
  }
}

pub fn KnfEnv::init_counter_from_existing(
  self : KnfEnv,
  existing : Knf
) -> Unit {
  self.counter = knf_max_counter(existing) + 1
}

pub fn KnfEnv::init_env_from_existing(env : KnfEnv) -> KnfEnv {
  {
    counter: env.counter + 1,
    externals: env.externals,
    signTable: @hashmap.T::new(),
    funcTable: @hashmap.T::new(),
    func_name_and_type: @hashmap.T::new(),
    name_and_type: @hashmap.T::new()
  }
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

fn insert_let(self : KnfEnv, e : Knf, t : Type, k : (Name) -> Knf) -> Knf {
  match e {
    Var(x) => k(x) // 如果是变量，直接调用继续函数 k
    _ => {
      let x = new_temp(self) // 生成一个临时标识符
      let e1 = k(x)
      ignore(addVarToEnv(self, x.to_string(), x, t))
      return Let( // 调用继续函数，得到新的表达式和类型
        (x, t),
        e,
        e1,
      ) // 创建 Let 表达式并返回
    }
  }
}

pub fn get_knf_type(self : KnfEnv, knf : Knf) -> Type {
  match knf {
    Knf::Unit => Type::Unit // 如果是 Unit，返回 Type.Unit
    Knf::Int(_) => Type::Int // 如果是 Int，返回 Type.Int
    Knf::Double(_) => Type::Double // 如果是 Double，返回 Type.Double
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
    Knf::IfEq(_, _, true_case, false_case) =>
      // 假设 IfEq 返回 true_case 的类型
      get_knf_type(self, true_case)
    Knf::IfLe(_, _, true_case, false_case) =>
      // 假设 IfLe 返回 true_case 的类型
      get_knf_type(self, true_case)
    Knf::Let(_, _, body) =>
      //println("Let: " + body.to_string())
      get_knf_type(self, body) // 假设 Let 返回 body 的类型
    Knf::Var(name) => {
      if self.func_name_and_type[name] != None {
        return self.func_name_and_type[name].unwrap()
      }
      getTypeFromName(self, name)
    }
    Knf::LetRec(_, body) => get_knf_type(self, body) // 假设 LetRec 返回 body 的类型
    Knf::Apply(ret, _) => {
      if self.func_name_and_type[ret] != None {
        return self.func_name_and_type[ret].unwrap()
      }
      getTypeFromName(self, ret)
    } // 假设 Apply 返回 Int 类型
    Knf::Tuple(elements) => {
      let types : Array[Type] = Array::new()
      for element in elements {
        if self.func_name_and_type[element] != None {
          types.push(self.func_name_and_type[element].unwrap())
        } else {
          types.push(getTypeFromName(self, element))
        }
      }
      Type::Tuple(types) // 返回包含具体类型的元组
    }
    Knf::LetTuple(_, _, body) => get_knf_type(self, body) // 假设 LetTuple 返回 body 的类型
    Knf::Get(array, _) => getTypeFromName(self, array) // 假设 Get 返回 Int 类型
    Knf::Put(_, e2, e3) => getTypeFromName(self, e3) // 假设 Put 返回 Unit 类型
    Knf::ExternalArray(_) => Type::Array(Type::Int)
    Knf::ExternalFunctionApplication(_, _) => Type::Unit
    // 可以添加更多变体的处理...
  }
}

pub fn KnfEnv::to_knf(self : KnfEnv, s : @types.Syntax) -> Knf {
  match s {
    Unit => Knf::Unit
    Bool(b) => Knf::Int(if b { 1 } else { 0 })
    Int(i) => Knf::Int(i)
    Double(d) => Knf::Double(d)

    // NOT: Let((newName, type), childSynax, FNeg)
    Not(inner) => to_knf(self, If(inner, Int(1), Int(0)))
    Neg(inner, kind=k) =>
      match k {
        Some(@types.Kind::Int) =>
          insert_let(
            self,
            to_knf(self, inner),
            Type::Int,
            fn(x : Name) -> Knf { Neg(x) },
          )
        Some(@types.Kind::Double) =>
          insert_let(
            self,
            to_knf(self, inner),
            Type::Double,
            fn(x : Name) -> Knf { FNeg(x) },
          )
        None => {
          println("Type not found2")
          abort("Kind not found")
        }
      }
    // insert_let(self, to_knf(self, inner), Type::Int, fn (x: Name) -> Knf { Neg(x) })
    Eq(_, _) | LE(_, _) as cmp => to_knf(self, If(cmp, Int(1), Int(0)))
    If(Not(e1), e2, e3) => to_knf(self, If(e1, e3, e2))
    If(Eq(e1, e2), e3, e4) => {
      let k1 = to_knf(self, e1)
      let k2 = to_knf(self, e2)
      let k3 = to_knf(self, e3)
      let k4 = to_knf(self, e4)
      insert_let(
        self,
        k1,
        get_knf_type(self, k1),
        fn(x : Name) -> Knf {
          insert_let(
            self,
            k2,
            get_knf_type(self, k2),
            fn(y : Name) -> Knf { IfEq(x, y, k3, k4) },
          )
        },
      )
    }
    If(LE(e1, e2), e3, e4) => {
      let k1 = to_knf(self, e1)
      let k2 = to_knf(self, e2)
      let k3 = to_knf(self, e3)
      let k4 = to_knf(self, e4)
      insert_let(
        self,
        k1,
        get_knf_type(self, k1),
        fn(x : Name) -> Knf {
          insert_let(
            self,
            k2,
            get_knf_type(self, k2),
            fn(y : Name) -> Knf { IfLe(x, y, k3, k4) },
          )
        },
      )
    }
    If(e1, e2, e3) => to_knf(self, If(Eq(e1, Bool(false)), e3, e2))

    // Syntax.Let((x, t), e1, e2) ->
    //   let e1', t1 = g env e1 in
    //   let e2', t2 = g (M.add x t env) e2 in
    //   Let((x, t), e1', e2'), t2
    Let((x, t), e1, e2) => {
      let e1tmp = to_knf(self, e1)
      let xName = new_temp(self)
      match t {
        Type::Fun(_, _) => ignore(addFuncToEnv(self, x, xName, t))
        _ => ignore(addVarToEnv(self, x, xName, t))
      }
      let e2tmp = to_knf(self, e2)
      Let((xName, t), e1tmp, e2tmp)
    }

    //   Syntax.Var(x) when M.mem x env -> Var(x), M.find x env
    // | Syntax.Var(x) -> (* 外部配列の参照 *)
    //     (match M.find x !Typing.extenv with
    //     | Type.Array(_) as t -> ExtArray x, t
    //     | _ -> failwith (Printf.sprintf "external variable %s does not have an array type" x))
    Var(x) => {
      let n = getVarFromEnv(self, x).0
      if n.to_string() == "_0" {
        let m = getFuncFromEnv(self, x).0
        Knf::Var(m)
      } else {
        Knf::Var(n)
      }
      // if getVarFromEnv(self, x).0.name == None {
      //   if (self.externals.find(x) != None) {
      //       let external = self.externals.find(x)
      //       match external.unwrap() {
      //       Fun(args_types, return_type) => {
      //         ExternalFunctionApplication(x, [])
      //       }
      //       _ => abort("External variable does not have an array type")
      //     }
      //   }
      //   else {
      //     let xName = (new_temp(self));
      //     ignore(addVarToEnv(self, x, xName, Type::Unit));
      //     Knf::Var(xName)
      //   }
      // }
      // else  {
      //   Knf::Var(getVarFromEnv(self, x).0)
      // }
    }
    LetRec({ name: (x, t), args: yts, body: e1 }, e2) => {
      let xName = new_temp(self)
      // println(x)
      let argsType : Array[Type] = Array::new()
      for item in yts {
        argsType.push(item.1)
      }
      match t {
        Type::Fun(_, _) =>
          ignore(addFuncToEnv(self, x, xName, Type::Fun(argsType, t)))
        _ => ignore(addVarToEnv(self, x, xName, Type::Fun(argsType, t)))
      }
      // ignore(addFuncToEnv(self, x, xName, Type::Fun(argsType, t)))
      // for item in self.signTable {
      //   println(item.0)
      // }
      let newEnv = init_env_from_existing(self)
      for item in self.signTable {
        newEnv.signTable[item.0] = item.1
      }
      for item in self.funcTable {
        newEnv.funcTable[item.0] = item.1
      }
      for item in self.func_name_and_type {
        newEnv.func_name_and_type[item.0] = item.1
      }
      for item in self.name_and_type {
        newEnv.name_and_type[item.0] = item.1
      }
      let mut index = 0
      self.counter += 200
      let ytsName = []
      for item in yts {
        let yName = new_temp(newEnv)
        ytsName.push((yName, item.1))
      }
      for items in yts {
        //println(items.0 + " " + items.1.to_string())
        match items.1 {
          Type::Fun(_, _) =>
            ignore(addFuncToEnv(newEnv, items.0, ytsName[index].0, items.1))
          _ => ignore(addVarToEnv(newEnv, items.0, ytsName[index].0, items.1))
        }
        // ignore(addVarToEnv(newEnv, items.0, ytsName[index].0, items.1))
        index = index + 1
      }
      //println(e1)
      let k1 = to_knf(newEnv, e1)
      //println("E2: " + e2.to_string())
      let k2 = to_knf(self, e2)
      // println("e2 END")
      if x != "main" {
        LetRec({ name: xName, ty: t, args: ytsName, body: k1 }, k2)
      } else {
        LetRec(
          { name: xName, ty: t, args: ytsName, body: k1 },
          Apply(xName, []),
        )
      }
    }
    App(Var(f), e2s) =>
      // println("APP NAME: " + f + " " + "args: " + e2s.to_string())
      if self.externals.find(f) != None {
        // println(f)
        let external = self.externals.find(f).unwrap()
        match external {
          Fun(_, t) => {
            // println(f + " " + t.to_string());
            let xs : Array[Name] = Array::new()
            let mut index = 0
            fn bind(xs : Array[Name]) -> Knf {
              if index == e2s.length() {
                return ExternalFunctionApplication("minimbt_" + f, xs)
              } else {
                let e2 = e2s[index]
                index = index + 1
                let k2 = to_knf(self, e2)
                // println("E2: " + e2.to_string() + " K2: " + k2.to_string())
                // println("Point")
                let t1 = get_knf_type(self, k2)
                insert_let(
                  self,
                  k2,
                  t1,
                  fn(y : Name) -> Knf {
                    xs.push(y)
                    bind(xs)
                  },
                )
              }
            }

            bind(xs)
          }
          _ => {
            println("Type not found3")
            abort("External function not found")
          }
        }
      } else {
        let e1Name = getFuncFromEnv(self, f).0
        let e1Type = getFuncFromEnv(self, f).1
        match e1Type {
          Fun(_, t) =>
            insert_let(
              self,
              Var(e1Name),
              e1Type,
              fn(f1 : Name) -> Knf {
                let xs : Array[Name] = Array::new()
                let mut index = 0
                fn bind(xs : Array[Name]) -> Knf {
                  if index == e2s.length() {
                    return Apply(f1, xs)
                  } else {
                    let e2 = e2s[index]
                    index = index + 1
                    let k2 = to_knf(self, e2)
                    let t1 = get_knf_type(self, k2)
                    insert_let(
                      self,
                      k2,
                      t1,
                      fn(y : Name) -> Knf {
                        xs.push(y)
                        bind(xs)
                      },
                    )
                  }
                }
                // println(f)
                bind(xs)
              },
            )
          _ => {
            for item in self.funcTable {
              println(item)
            }
            println(f)
            println("Type not found4")
            abort("Not a function")
          }
        }
      }
    App(e1, e2s) => {
      let e1Knf = to_knf(self, e1)
      // println("APP: " + e1.to_string() + " " + e2s.to_string())
      let e1Type = get_knf_type(self, e1Knf)
      // println("E1TYPE: " + e1Type.to_string())
      // println(e1Type)
      match e1Type {
        Fun(_, t) =>
          insert_let(
            self,
            e1Knf,
            get_knf_type(self, e1Knf),
            fn(f : Name) -> Knf {
              let xs : Array[Name] = Array::new()
              let mut index = 0
              fn bind(xs : Array[Name]) -> Knf {
                if e2s.length() == index {
                  // println(f.to_string() + " " + xs.to_string())
                  return Apply(f, xs)
                } else {
                  let e2 = e2s[index]
                  // println("E2: " + e2.to_string())
                  index = index + 1
                  let k2 = to_knf(self, e2)
                  let t1 = get_knf_type(self, k2)
                  // println("T1: " + t1.to_string())
                  insert_let(
                    self,
                    k2,
                    t1,
                    fn(y : Name) -> Knf {
                      xs.push(y)
                      bind(xs)
                    },
                  )
                }
              }

              bind(xs)
            },
          )
        _ => {
          // println("Wrong type") 
          println("Type not found2")
          abort("Not a function")
        }
      }
    }
    Tuple(es) => {
      let xs : Array[Name] = Array::new()
      let ts : Array[Type] = Array::new()
      let elementKnf : Array[Knf] = Array::new()
      for e in es {
        let x = new_temp(self)
        xs.push(x)
        let k = to_knf(self, e)
        elementKnf.push(k)
        let t = get_knf_type(self, k)
        ts.push(t)
      }
      fn bind(
        xs : Array[Name],
        es : Array[@types.Syntax],
        self : KnfEnv
      ) -> Knf {
        if es.is_empty() {
          return Tuple(xs)
        } else {
          let e = es.pop().unwrap()
          let k = elementKnf.pop().unwrap()
          let t = ts.pop().unwrap()
          insert_let(
            self,
            k,
            t,
            fn(y : Name) -> Knf {
              xs.push(y)
              bind(xs, es, self)
            },
          )
        }
      }

      bind(Array::new(), es, self)
    }
    LetTuple(xts, e1, e2) => {
      let e1Knf = to_knf(self, e1)
      insert_let(
        self,
        e1Knf,
        get_knf_type(self, e1Knf),
        fn(y : Name) -> Knf {
          let xtsName = []
          for item in xts {
            let newName = new_temp(self)
            ignore(addVarToEnv(self, item.0, newName, item.1))
            xtsName.push((newName, item.1))
          }
          LetTuple(xtsName, y, to_knf(self, e2))
        },
      )
    }
    Array(e1, e2) => {
      let k1 = to_knf(self, e1)
      insert_let(
        self,
        to_knf(self, e1),
        Type::Int,
        fn(x : Name) -> Knf {
          let e2Knf = to_knf(self, e2)
          insert_let(
            self,
            e2Knf,
            get_knf_type(self, e2Knf),
            fn(y : Name) -> Knf {
              let l = match e2 {
                Double(_) => "minimbt_create_float_array"
                Int(_) => "minimbt_create_array"
                _ => "minimbt_create_ptr_array"
              }
              ExternalFunctionApplication(l, [x, y])
            },
          )
        },
      )
    }
    Get(e1, e2) => {
      let e1Knf = to_knf(self, e1)
      match get_knf_type(self, e1Knf) {
        Array(x) =>
          insert_let(
            self,
            e1Knf,
            x,
            fn(x : Name) -> Knf {
              insert_let(
                self,
                to_knf(self, e2),
                Type::Int,
                fn(y : Name) -> Knf { Get(x, y) },
              )
            },
          )
        _ => abort("Not an array")
      }
    }
    Put(e1, e2, e3) => {
      let k1 = to_knf(self, e1)
      let k2 = to_knf(self, e2)
      let k3 = to_knf(self, e3)
      insert_let(
        self,
        k1,
        get_knf_type(self, k1),
        fn(x : Name) -> Knf {
          insert_let(
            self,
            k2,
            get_knf_type(self, k2),
            fn(y : Name) -> Knf {
              insert_let(
                self,
                k3,
                get_knf_type(self, k3),
                fn(z : Name) -> Knf { Put(x, y, z) },
              )
            },
          )
        },
      )
    }
    Prim(a, b, op, kind=k) =>
      if op == @types.Op::Add && k == Some(@types.Kind::Int) {
        let ka = to_knf(self, a)
        let kb = to_knf(self, b)
        // println(a)
        // println(b)
        if get_knf_type(self, ka) == Type::Double {
          insert_let(
            self,
            ka,
            Type::Double,
            fn(x : Name) -> Knf {
              insert_let(
                self,
                kb,
                Type::Int,
                fn(y : Name) -> Knf { FAdd(x, y) },
              )
            },
          )
        } else if get_knf_type(self, kb) == Type::Double {
          insert_let(
            self,
            ka,
            Type::Int,
            fn(x : Name) -> Knf {
              insert_let(
                self,
                kb,
                Type::Double,
                fn(y : Name) -> Knf { FAdd(x, y) },
              )
            },
          )
        } else {
          insert_let(
            self,
            ka,
            Type::Int,
            fn(x : Name) -> Knf {
              insert_let(self, kb, Type::Int, fn(y : Name) -> Knf { Add(x, y) })
            },
          )
        }
      } else if op == @types.Op::Add && k == Some(@types.Kind::Double) {
        let ka = to_knf(self, a)
        let kb = to_knf(self, b)
        insert_let(
          self,
          ka,
          Type::Double,
          fn(x : Name) -> Knf {
            insert_let(
              self,
              kb,
              Type::Double,
              fn(y : Name) -> Knf { FAdd(x, y) },
            )
          },
        )
      } else if op == @types.Op::Sub && k == Some(@types.Kind::Int) {
        let ka = to_knf(self, a)
        let kb = to_knf(self, b)
        if get_knf_type(self, ka) == Type::Double {
          insert_let(
            self,
            ka,
            Type::Double,
            fn(x : Name) -> Knf {
              insert_let(
                self,
                kb,
                Type::Int,
                fn(y : Name) -> Knf { FSub(x, y) },
              )
            },
          )
        } else if get_knf_type(self, kb) == Type::Double {
          insert_let(
            self,
            ka,
            Type::Int,
            fn(x : Name) -> Knf {
              insert_let(
                self,
                kb,
                Type::Double,
                fn(y : Name) -> Knf { FSub(x, y) },
              )
            },
          )
        } else {
          insert_let(
            self,
            ka,
            Type::Int,
            fn(x : Name) -> Knf {
              insert_let(self, kb, Type::Int, fn(y : Name) -> Knf { Sub(x, y) })
            },
          )
        }
      } else if op == @types.Op::Sub && k == Some(@types.Kind::Double) {
        let ka = to_knf(self, a)
        let kb = to_knf(self, b)
        insert_let(
          self,
          ka,
          Type::Int,
          fn(x : Name) -> Knf {
            insert_let(self, kb, Type::Int, fn(y : Name) -> Knf { FSub(x, y) })
          },
        )
      } else if op == @types.Op::Mul && k == Some(@types.Kind::Int) {
        let ka = to_knf(self, a)
        let kb = to_knf(self, b)
        if get_knf_type(self, ka) == Type::Double {
          insert_let(
            self,
            ka,
            Type::Double,
            fn(x : Name) -> Knf {
              insert_let(
                self,
                kb,
                Type::Int,
                fn(y : Name) -> Knf { FMul(x, y) },
              )
            },
          )
        } else if get_knf_type(self, kb) == Type::Double {
          insert_let(
            self,
            ka,
            Type::Int,
            fn(x : Name) -> Knf {
              insert_let(
                self,
                kb,
                Type::Double,
                fn(y : Name) -> Knf { FMul(x, y) },
              )
            },
          )
        } else {
          insert_let(
            self,
            ka,
            Type::Int,
            fn(x : Name) -> Knf {
              insert_let(self, kb, Type::Int, fn(y : Name) -> Knf { Mul(x, y) })
            },
          )
        }
      } else if op == @types.Op::Mul && k == Some(@types.Kind::Double) {
        let ka = to_knf(self, a)
        let kb = to_knf(self, b)
        insert_let(
          self,
          ka,
          Type::Int,
          fn(x : Name) -> Knf {
            insert_let(self, kb, Type::Int, fn(y : Name) -> Knf { FMul(x, y) })
          },
        )
      } else if op == @types.Op::Div && k == Some(@types.Kind::Int) {
        let ka = to_knf(self, a)
        let kb = to_knf(self, b)
        if get_knf_type(self, ka) == Type::Double {
          insert_let(
            self,
            ka,
            Type::Double,
            fn(x : Name) -> Knf {
              insert_let(
                self,
                kb,
                Type::Int,
                fn(y : Name) -> Knf { FDiv(x, y) },
              )
            },
          )
        } else if get_knf_type(self, kb) == Type::Double {
          insert_let(
            self,
            ka,
            Type::Int,
            fn(x : Name) -> Knf {
              insert_let(
                self,
                kb,
                Type::Double,
                fn(y : Name) -> Knf { FDiv(x, y) },
              )
            },
          )
        } else {
          insert_let(
            self,
            ka,
            Type::Int,
            fn(x : Name) -> Knf {
              insert_let(self, kb, Type::Int, fn(y : Name) -> Knf { Div(x, y) })
            },
          )
        }
      } else if op == @types.Op::Div && k == Some(@types.Kind::Double) {
        let ka = to_knf(self, a)
        let kb = to_knf(self, b)
        insert_let(
          self,
          ka,
          Type::Int,
          fn(x : Name) -> Knf {
            insert_let(self, kb, Type::Int, fn(y : Name) -> Knf { FDiv(x, y) })
          },
        )
      } else {
        abort("todo")
      }
  }
  // abort("todo")

}

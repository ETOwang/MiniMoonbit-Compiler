// pub enum @types.Syntax {
//   Unit
//   Bool(Bool) // true false
//   Int(Int) // int
//   Double(Double) // double
//   Var(String) // _
//   Tuple(Array[@types.Syntax]) // (_, _, _)
//   Not(@types.Syntax) // not(_)
//   Array(@types.Syntax, @types.Syntax) // Array::make(_, _)
//   Neg(@types.Syntax, mut ~kind : Kind?) // -_
//   App(@types.Syntax, Array[@types.Syntax]) // _(_, _, _) or _()
//   Get(@types.Syntax, @types.Syntax) // _[_]
//   If(@types.Syntax, @types.Syntax, @types.Syntax) // if _ { _ } else { _ }
//   Prim(@types.Syntax, @types.Syntax, Op, mut ~kind : Kind?) // _+ - * / _
//   Eq(@types.Syntax, @types.Syntax) // _==_
//   LE(@types.Syntax, @types.Syntax) // _<=_
//   Let((String, Type), @types.Syntax, @types.Syntax) // let _: _ = _; _
//   LetRec(Fundef, @types.Syntax) // fn f() {} ; _
//   LetTuple(Array[(String, Type)], @types.Syntax, @types.Syntax) // let (_ , _) : (_, _)= _; _
//   Put(@types.Syntax, @types.Syntax, @types.Syntax) // _[_] = _ ; _
// } derive(Show)

// pub enum Kind {
//   Int
//   Double
// } derive(Show, Eq)

// pub enum Op {
//   Add
//   Sub
//   Mul
//   Div
// } derive(Show, Eq)

// pub struct Fundef {
//   name : (String, Type)
//   args : Array[(String, Type)]
//   body : Syntax
// } derive(Show)

pub fn generator(ast: @types.Syntax) -> String {
  jscodegen(ast) + "\n" + "export default main;"
}

fn jscodegen(ast: @types.Syntax) -> String {
  match ast {
    @types.Syntax::Unit => ""
    @types.Syntax::Bool(value) => if value { "true" } else { "false" }
    @types.Syntax::Int(value) => value.to_string()
    @types.Syntax::Double(value) => value.to_string()
    @types.Syntax::Var(name) => {
      let mut js_name = name
      match name {
        "print_int" => js_name = "minimbt_print_int"
        "read_int" => js_name = "minimbt_read_int"
        "read_char" => js_name = "minimbt_read_char"
        "print_char" => js_name = "minimbt_print_char"
        "print_endline" => js_name = "minimbt_print_endline"
        "print_newline" => js_name = "minimbt_print_newline"
        "int_of_float" => js_name = "minimbt_int_of_float"
        "float_of_int" => js_name = "minimbt_float_of_int"
        "truncate" => js_name = "minimbt_truncate"
        "floor" => js_name = "minimbt_floor"
        "abs_float" => js_name = "minimbt_abs_float"
        "sqrt" => js_name = "minimbt_sqrt"
        "sin" => js_name = "minimbt_sin"
        "cos" => js_name = "minimbt_cos"
        "atan" => js_name = "minimbt_atan"
        _ => js_name = name
      }
      js_name
    }
    @types.Syntax::Tuple(elements) => {
      let mut result = ""
      if not(elements.is_empty()) {
          result = jscodegen(elements[0])
          for elem in elements[1:] {
          result = result + "," + jscodegen(elem)
        }
      }
      "[" + result + "]"
    }
    @types.Syntax::Not(expr) => "!" + "(" + jscodegen(expr) + ")"
    @types.Syntax::Array(size, init) => "Array(" + jscodegen(size) + ").fill(" + jscodegen(init) + ")"
    @types.Syntax::Neg(expr) => "-" + jscodegen(expr)
    @types.Syntax::App(func, args) => {
      let mut result = jscodegen(func) + "("
      if not(args.is_empty()) {
        result = result + jscodegen(args[0])
        for arg in args[1:] {
          result = result + ", " + jscodegen(arg)
        }
      }
      result + ")"
    }
    @types.Syntax::Get(array, index) => jscodegen(array) + "[" + jscodegen(index) + "]"
    @types.Syntax::If(cond, then_branch, else_branch) => "if (" + jscodegen(cond) + ") { \n"  + jscodegen(then_branch) + ";\n" + "} else { \n" + jscodegen(else_branch) + ";\n" +  "}"
    @types.Syntax::Prim(lhs, rhs, op, ..) => {
      let mut op = op.to_string()
      match op {
        "Add" => op = "+"
        "Sub" => op = "-"
        "Mul" => op = "*"
        "Div" => op = "/"
        _ => @util.die("wrong op")
      }
      "(" + calcuPrim(lhs) + " " + op + " " + calcuPrim(rhs) + ")"
    }
    @types.Syntax::Eq(lhs, rhs) => jscodegen(lhs) + " === " + jscodegen(rhs)
    @types.Syntax::LE(lhs, rhs) => jscodegen(lhs) + " <= " + jscodegen(rhs)
    @types.Syntax::Let((name, _), value, rest) => "let " + name + " = " + jscodegen(value) + "\n" + jscodegen(rest)
    @types.Syntax::LetRec(fundef, rest) => {
      jscodegen_fundef(fundef) + "\n" + jscodegen(rest)
    }
    @types.Syntax::LetTuple(arr, value, rest) => {
      let mut count = 0
      let mut result = genVarName(arr[0].0, count)
      count = 1
      for arg in arr[1:] {
        result = result + ", " + genVarName(arg.0, count)
        count = count + 1
      }
      "let [" + result + "] = " + jscodegen(value) + "\n" + jscodegen(rest)
    }
    @types.Syntax::Put(array, value, rest) => jscodegen(array) + " = " + jscodegen(value) + ";\n" + jscodegen(rest)
  }
}

fn genVarName(name: String, n: Int) -> String {
  if name == "_" {
    "tempvar" + n.to_string()
  }
  else {
    name
  }
}


fn jscodegen_fundef(fundef: @types.Fundef) -> String {
  let name = fundef.name
  let args = fundef.args
  let body = fundef.body
  let mut arg_list = ""
  if not(args.is_empty()) {
    arg_list = args[0].0
    for arg in args[1:] {
      arg_list = arg_list + "," + arg.0
    }
  }
  if name.0 == "main" {
    "function " + name.0 + "(" + arg_list + ") {\n" + jscodegen(body) + ";\n" + "minimbt_print_endline();" + "\n}"
  }
  else {
    "function " + name.0 + "(" + arg_list + ") {\n" + jscodegen_with_return(body) + "\n}"
  }
}

fn jscodegen_with_return(ast: @types.Syntax) -> String {
  match ast {
    @types.Syntax::Let((name, _), value, rest) => "let " + name + " = " + jscodegen(value) + "\n" + jscodegen_with_return(rest)
    @types.Syntax::LetRec(fundef, rest) => {
      jscodegen_fundef(fundef) + "\n" + jscodegen_with_return(rest)
    }
    @types.Syntax::LetTuple(arr, value, rest) => {
      let mut result = arr[0].0
      for arg in arr[1:] {
        result = result + "," + arg.0
      }
      "let [" + result + "] = " + jscodegen(value) + "\n" + jscodegen_with_return(rest)
    }
    @types.Syntax::Put(array, value, rest) => jscodegen(array) + " = " + jscodegen(value) + ";\n" + jscodegen_with_return(rest)
    @types.Syntax::If(cond, then_branch, else_branch) => "if (" + jscodegen(cond) + ") { \n"  + jscodegen_with_return(then_branch) + ";\n" + "} else { \n" + jscodegen_with_return(else_branch) + ";\n" +  "}"
    _ => "return " + jscodegen(ast) 
  }
}

fn calcuPrim(ast: @types.Syntax) -> String {
  match ast {
    @types.Syntax::If(cond, then_branch, else_branch) => "(" + jscodegen(cond) + " ? " + jscodegen(then_branch) + " : " + jscodegen(else_branch) + ")"
    @types.Syntax::Prim(lhs, rhs, op, ..) => {
      let mut op = op.to_string()
      match op {
        "Add" => op = "+"
        "Sub" => op = "-"
        "Mul" => op = "*"
        "Div" => op = "/"
        _ => @util.die("wrong op")
      }
      "(" + calcuPrim(lhs) + " " + op + " " + calcuPrim(rhs) + ")"
    }
    _ => jscodegen(ast)
  }
}
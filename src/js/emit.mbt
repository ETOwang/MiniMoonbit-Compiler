pub struct State {
  output : String
  indent : String
  indentLevel : Int
}

pub fn State::new() -> State {
  State {
    output: "",
    indent: "  ",
    indentLevel: 0
  }
}

pub fn State::write(self : State, code : String) -> Unit {
  self.output = self.output + code
}

pub fn State::toString(self : State) -> String {
  self.output
}

pub struct Generator {}

pub fn Generator::Unit(node : Node, state : State) -> Unit {
  state.write("undefined")
}

pub fn Generator::Bool(node : Node, state : State) -> Unit {
  state.write(if node.value then "true" else "false")
}

pub fn Generator::Int(node : Node, state : State) -> Unit {
  state.write(toString(node.value))
}

pub fn Generator::Double(node : Node, state : State) -> Unit {
  state.write(toString(node.value))
}

pub fn Generator::Var(node : Node, state : State) -> Unit {
  state.write(node.name)
}

pub fn Generator::Tuple(node : Node, state : State) -> Unit {
  state.write("[")
  for i in 0..len(node.elements) {
    if i > 0 {
      state.write(", ")
    }
    Generator::generate(node.elements[i], state)
  }
  state.write("]")
}

pub fn Generator::Not(node : Node, state : State) -> Unit {
  state.write("!")
  Generator::generate(node.argument, state)
}

pub fn Generator::Array(node : Node, state : State) -> Unit {
  state.write("Array(")
  Generator::generate(node.size, state)
  state.write(", ")
  Generator::generate(node.value, state)
  state.write(")")
}

pub fn Generator::Neg(node : Node, state : State) -> Unit {
  state.write("-")
  Generator::generate(node.argument, state)
}

pub fn Generator::App(node : Node, state : State) -> Unit {
  Generator::generate(node.callee, state)
  state.write("(")
  for i in 0..len(node.arguments) {
    if i > 0 {
      state.write(", ")
    }
    Generator::generate(node.arguments[i], state)
  }
  state.write(")")
}

pub fn Generator::Get(node : Node, state : State) -> Unit {
  Generator::generate(node.object, state)
  state.write("[")
  Generator::generate(node.property, state)
  state.write("]")
}

pub fn Generator::If(node : Node, state : State) -> Unit {
  state.write("if (")
  Generator::generate(node.test, state)
  state.write(") {")
  Generator::generate(node.consequent, state)
  state.write("} else {")
  Generator::generate(node.alternate, state)
  state.write("}")
}

pub fn Generator::Prim(node : Node, state : State) -> Unit {
  Generator::generate(node.left, state)
  state.write(" " + node.operator + " ")
  Generator::generate(node.right, state)
}

pub fn Generator::Eq(node : Node, state : State) -> Unit {
  Generator::generate(node.left, state)
  state.write(" === ")
  Generator::generate(node.right, state)
}

pub fn Generator::LE(node : Node, state : State) -> Unit {
  Generator::generate(node.left, state)
  state.write(" <= ")
  Generator::generate(node.right, state)
}

pub fn Generator::Let(node : Node, state : State) -> Unit {
  state.write("let ")
  state.write(node.id.name)
  state.write(" = ")
  Generator::generate(node.init, state)
  state.write("; ")
  Generator::generate(node.body, state)
}

pub fn Generator::LetRec(node : Node, state : State) -> Unit {
  state.write("function ")
  state.write(node.id.name)
  state.write("() {")
  Generator::generate(node.body, state)
  state.write("} ")
  Generator::generate(node.next, state)
}

pub fn Generator::LetTuple(node : Node, state : State) -> Unit {
  state.write("let [")
  for i in 0..len(node.ids) {
    if i > 0 {
      state.write(", ")
    }
    state.write(node.ids[i].name)
  }
  state.write("] = ")
  Generator::generate(node.init, state)
  state.write("; ")
  Generator::generate(node.body, state)
}

pub fn Generator::Put(node : Node, state : State) -> Unit {
  Generator::generate(node.object, state)
  state.write("[")
  Generator::generate(node.property, state)
  state.write("] = ")
  Generator::generate(node.value, state)
  state.write(";")
}

pub fn Generator::generate(node : Node, state : State) -> Unit {
  match node.type {
    "Unit" => Generator::Unit(node, state)
    "Bool" => Generator::Bool(node, state)
    "Int" => Generator::Int(node, state)
    "Double" => Generator::Double(node, state)
    "Var" => Generator::Var(node, state)
    "Tuple" => Generator::Tuple(node, state)
    "Not" => Generator::Not(node, state)
    "Array" => Generator::Array(node, state)
    "Neg" => Generator::Neg(node, state)
    "App" => Generator::App(node, state)
    "Get" => Generator::Get(node, state)
    "If" => Generator::If(node, state)
    "Prim" => Generator::Prim(node, state)
    "Eq" => Generator::Eq(node, state)
    "LE" => Generator::LE(node, state)
    "Let" => Generator::Let(node, state)
    "LetRec" => Generator::LetRec(node, state)
    "LetTuple" => Generator::LetTuple(node, state)
    "Put" => Generator::Put(node, state)
    _ => abort("Unknown node type: " + node.type)
  }
}

pub fn generate(node : Node) -> String {
  let state = State::new()
  Generator::generate(node, state)
  state.toString()
}

// 示例AST节点
let ast = Node {
  type: "Let",
  id: { name: "x" },
  init: { type: "Int", value: 42 },
  body: { type: "Var", name: "x" }
}

// 生成JavaScript代码
let code = generate(ast)
print(code) // 输出: let x = 42; x
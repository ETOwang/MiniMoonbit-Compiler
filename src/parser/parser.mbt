// fn parse(source_code: String) -> @types.Syntax {
//   let context:@lex.Context = {str: source_code, offset: 0, array: []}
//   @lex.lex(context)
//   prog(context)
// }

pub enum Syntax {
  Unit
  Bool(Bool) // true false
  Int(Int) // int
  Double(Double) // double
  Var(String) // _
  Tuple(Array[Syntax]) // (_, _, _)
  Not(Syntax) // not(_)
  Array(Syntax, Syntax) // Array::make(_, _)
  Neg(Syntax, mut ~kind : Kind?) // -_
  App(Syntax, Array[Syntax]) // _(_, _, _) or _()
  Get(Syntax, Syntax) // _[_]
  If(Syntax, Syntax, Syntax) // if _ { _ } else { _ }
  Prim(Syntax, Syntax, Op, mut ~kind : Kind?) // _+ - * / _
  Eq(Syntax, Syntax) // _==_
  LE(Syntax, Syntax) // _<=_
  Let((String, Type), Syntax, Syntax) // let _: _ = _; _
  LetRec(Fundef, Syntax) // fn f() {} ; _
  LetTuple(Array[(String, Type)], Syntax, Syntax) // let (_ , _) : (_, _)= _; _
  Put(Syntax, Syntax, Syntax) // _[_] = _
} derive(Show)

pub enum Kind {
  Int
  Double
} derive(Show, Eq)

pub enum Op {
  Add
  Sub
  Mul
  Div
} derive(Show, Eq)

pub struct Fundef {
  name : (String, Type)
  args : Array[(String, Type)]
  body : Syntax
} derive(Show)

pub enum Type {
  Unit
  Bool
  Int
  Double
  Fun(Array[Type], Type) // (_, _, _) -> _
  Tuple(Array[Type]) // (_, _, _)
  Array(Type) // Array[_]
  Var(Ref[Type?])
  Ptr
} derive(Show)

// prog: top_level* EOF
// 在 AST 上实际与非顶级的 stmt 相同，并且需要在结尾补上一个 Unit

// top_level: top_let_decl | toplevel_fn_decl

// unit_expr: '(' ')'; // ()
fn unit_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Lparen).1
  rest = skip(rest, @lex.Rparen).1
  (@types.Syntax::Unit, rest)
}

// tuple_expr: '(' expr (',' expr)+ ')'; // (x, y); 1-tuple is not allowed
fn tuple_expr(rest: ArrayView[@lex.Token]) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Lparen).1
  let mut (syn, rest) = expr(rest)
  let mut arr = Array::new()
  arr.push(x)
  while skip(rest, @lex.Comma).0 {
    let x: @types.Syntax = expr(rest).0
    arr.push(x)
  }
  rest = skip(rest, @lex.Rparen).1
  (@types.Syntax::Tuple(arr), rest)
}

// block_expr: '{' stmt '}'; // { blah; blah; }
fn block_expr(rest: ArrayView[@lex.Token]) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Lcurlybracket).1
  let mut (syn, rest) = stmt(rest)
  rest = skip(rest, @lex.Rcurlybracket).1
  (syn, rest)
}

// bool_expr: 'true' | 'false';
fn bool_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  match rest[0] {
    @lex.True => (@types.Syntax::Bool(true), rest[1:])
    @lex.False => (@types.Syntax::Bool(false), rest[1:])
  }
}

// neg_expr: '-' value_expr;
fn neg_expr(rest: ArrayView[@lex.Token]) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Not).1
  let mut (syn, rest) = value_expr(rest)
  (@types.Syntax::Neg(syn, _), rest)
}

// floating_point_expr: NUMBER '.' NUMBER?
fn floating_point_expr(rest: ArrayView[@lex.Token]) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  let value1 = Int::to_double( match rest[0] {
    @lex.Number(n) => n
    _ => @util.die("expected num")
  })
  rest = skip(rest, @lex.Dot).1
  let value2 = match rest[0] {
    @lex.Number(n) => n
    _ => @util.die("expected num")
  }
  let mut decimal = Int::to_double(value2)
  while decimal > 1 {
    decimal = decimal / 10
  }
  let val: Double = value1 + decimal
  (@types.Syntax::Double(val), rest)
}

// int_expr: NUMBER
fn int_expr(rest: ArrayView[@lex.Token]) -> (@types.Syntax, ArrayView[@lex.Token]) {
  
}

// 跳过rest中的第一个token，返回剩下的token
fn skip(
  rest : ArrayView[@lex.Token],
  tk : @lex.Token
) -> (Bool, ArrayView[@lex.Token]) {
  match rest[0] {
    tk => (true, rest[1:])
    _ => (false, rest)
  }
}

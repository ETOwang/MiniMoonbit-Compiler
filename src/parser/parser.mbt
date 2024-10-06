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

// get_or_apply_level_expr:
//  value_expr # value_expr_
// x[y]
//  | get_or_apply_level_expr '[' expr ']' # get_expr_   
// f(x, y)
//  | get_or_apply_level_expr '(' (expr (',' expr)*)? ')' # apply_expr;
fn get_or_apply_level_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let (syn, new_rest) = value_expr(rest) //value_expr
  let mut rest = rest
  while true { 
    match rest[0] {
      @lex.Lbracket => { // get_or_apply_level_expr '[' expr ']'
        rest = skip(rest, @lex.Lbracket).1 // '['
        let (exp_syn, new_rest) = expr(rest) // expr
        rest = new_rest
        rest = skip(rest, @lex.Rbracket).1 // ']'
        let syn = @types.Syntax::Get(syn, exp_syn)
        continue
      }
      @lex.Lparen => { // get_or_apply_level_expr '(' (expr (',' expr)*)? ')'
        rest = skip(rest, @lex.Lparen).1 // '('
        let mut args = []
        if not(skip(rest, @lex.Rparen).0) { // 如果括号中存在参数
          let (exp, new_rest) = expr(rest) // 解析第一个参数
          args.push(exp)
          rest = new_rest
          while skip(rest, @lex.Comma).0 { // (',' expr)* 解析后续参数
            rest = rest[1:] // 跳过 ','
            let (exp, new_rest) = expr(rest)  
            args.push(exp)
            rest = new_rest
          }
        }
        rest = skip(rest, @lex.Rparen).1
        let syn = @types.Syntax::App(syn, args)
        continue
      }
      _ => break
    }
  }
  (syn, rest)
}

// value_expr:
//  unit_expr: '(' ')'
//  | tuple_expr '(' expr (',' expr)+ ')'
//  | bool_expr  'true' | 'false'
//  | identifier_expr IDENTIFIER
//  | block_expr '{' stmt '}'
//  | neg_expr  '-' value_expr
//  | floating_point_expr NUMBER '.' NUMBER?
//  | int_expr NUMBER
//  | not_expr 'not' '(' expr ')'
//  | array_make_expr 'Array' ':' ':' 'make' '(' expr ',' expr ')'
fn value_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  match rest[0] { //对应上方规则，判断是哪一种value_expr
    @lex.Lparen => { 
      match rest[1] {
        @lex.Rparen => unit_expr(rest)
        _ => tuple_expr(rest) 
      }
    }
    @lex.Lcurlybracket => block_expr(rest)
    @lex.True | @lex.False => bool_expr(rest)
    @lex.Sub => neg_expr(rest)
    @lex.Number(n) => {
      match rest[1] {
        @lex.Dot => floating_point_expr(rest)
        _ => int_expr(rest)
      }
    }
    @lex.Not => not_expr(rest)
    @lex.Array => array_make_expr(rest)
    @lex.Identifier(str) => identifier_expr(rest)
    _ => @util.die("wrong value_expr")
  }
}

// unit_expr: '(' ')'; // ()
fn unit_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Lparen).1 //'('
  rest = skip(rest, @lex.Rparen).1 // ')'
  (@types.Syntax::Unit, rest)
}

// tuple_expr: '(' expr (',' expr)+ ')'; // (x, y); 1-tuple is not allowed
fn tuple_expr(
  rest: ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Lparen).1 // '('
  let (syn, rest) = expr(rest) // expr
  let mut rest = rest // 让rest为可修改参数
  let mut arr = Array::new() // (',' expr)+
  arr.push(syn)
  while skip(rest, @lex.Comma).0 {
    rest = rest[1:]
    let x: @types.Syntax = expr(rest).0
    arr.push(x)
  }
  if arr.length() < 2 { // 1-tuple is not allowed
    @util.die("1-tuple is not allowed")
  }
  rest = skip(rest, @lex.Rparen).1 // ')'
  (@types.Syntax::Tuple(arr), rest)
}

// block_expr: '{' stmt '}'; // { blah; blah; }
fn block_expr(
  rest: ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Lcurlybracket).1 // '{'
  let (syn, rest) = stmt(rest) // stmt
  let mut rest = rest
  rest = skip(rest, @lex.Rcurlybracket).1 // '}'
  (syn, rest)
}

// bool_expr: 'true' | 'false';
fn bool_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  match rest[0] {
    @lex.True => (@types.Syntax::Bool(true), rest[1:]) // 'true'
    @lex.False => (@types.Syntax::Bool(false), rest[1:]) // 'false'
  }
}

// neg_expr: '-' value_expr;
fn neg_expr(
  rest: ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Sub).1 // '-'
  let (syn, rest) = value_expr(rest) // value_expr
  (@types.Syntax::Neg(syn, kind=None), rest)
}

// floating_point_expr: NUMBER '.' NUMBER?
fn floating_point_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  let value1 = Int::to_double( // Number1, 转换为double类型
    match rest[0] {
      @lex.Number(n) => n
      _ => @util.die("expected num")
    },
  )
  rest = skip(rest, @lex.Dot).1 // '.'
  let value2 = match rest[0] { // Number2
    @lex.Number(n) => n
    _ => 0 // Number2 可以没有
  }
  let mut decimal = Int::to_double(value2) // Number2 转化为小数
  while decimal > 1 {  // 例如： 12.57 --> Number1 = 12, Number2 = 57 --> 12 + 0.57
    decimal = decimal / 10
  }
  let val : Double = value1 + decimal 
  (@types.Syntax::Double(val), rest)
}

// int_expr: NUMBER
fn int_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  let value = match rest[0] { // Number
    @lex.Number(n) => n
    _ => @util.die("expect num")
  }
  (@types.Syntax::Int(value), rest[1:]) // 模式匹配不会进行skip，最后需要手动移动ArrayView
}

// not_expr: 'not' '(' expr ')'
fn not_expr(
  rest: ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Not).1 // 'not'
  rest = skip(rest, @lex.Lparen).1 // '('
  let (syn, rest) = expr(rest) // expr
  let mut rest = skip(rest, @lex.Rparen).1 // ')'
  (@types.Syntax::Not(syn), rest)
}

// array_make_expr: 'Array' ':' ':' 'make' '(' expr ',' expr ')'
fn array_make_expr(
  rest: ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Array).1 // 'Array'
  rest = skip(rest, @lex.Colon).1 // ':'
  rest = skip(rest, @lex.Colon).1 // ':'
  rest = skip(rest, @lex.Make).1 // 'make'
  rest = skip(rest, @lex.Lparen).1 // '('
  let (syn1, rest) = expr(rest) // expr
  let mut rest = skip(rest, @lex.Comma).1 // ','
  let (syn2, rest) = expr(rest) // expr
  let mut rest = skip(rest, @lex.Rparen).1 //')'
  (@types.Syntax::Array(syn1, syn2), rest)
}

// identifier_expr: IDENTIFIER
fn identifier_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  let str = match rest[0] { // Ident
    @lex.Identifier(s) => s
    _ => @util.die("expected string")
  }
  (@types.Syntax::Var(str), rest[1:]) // 模式匹配不会进行skip，最后需要手动移动ArrayView
}

// 希望跳过rest中的第一个token不处理，返回剩下的token
fn skip(
  rest : ArrayView[@lex.Token],
  tk : @lex.Token
) -> (Bool, ArrayView[@lex.Token]) {
  match rest[0] {  
    tk => (true, rest[1:]) // 当前ArrayView中第一个Token与tk匹配时进行跳过，返回true + 新ArrayView
    _ => (false, rest) // 否则返回false + 原ArrayView
  }
}

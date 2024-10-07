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

// main_fn_decl: 'fn' ('main' | 'init') fn_body;
fn main_fn_decl(
  rest : ArrayView[@lex.Token]
) -> (@types.Fundef, ArrayView[@lex.Token]) {
  let mut rest = skip(rest, @lex.Fn)
  let name = match rest[0] {
    @lex.Identifier("main") => "main"
    @lex.Identifier("init") => "init"
    _ => @util.die("Expected 'main' or 'init'")
  }
  rest = skip(rest, @lex.Identifier(name))
  let (body, rest) = fn_body(rest)
  let params = []
  let return_type = @types.Syntax::Unit
  let fundef = @types.Fundef ( // TOCHECK: 我不理解这里为什么报错，文档里就是这样构造结构体的
    (name, return_type),
    params,
    body
  )
  
  (fundef, rest)
}

// top_fn_decl:
// 'fn' IDENTIFIER '(' param_list? ')' '->' type fn_body
fn top_fn_decl(
  rest : ArrayView[@lex.Token]
) -> (@types.Fundef, ArrayView[@lex.Token]) {
  let mut rest = skip(rest, @lex.Fn)

  let name = match rest[0] {
    @lex.Identifier(str) => str
    _ => @util.die("Expected function name")
  }
  rest = skip(rest, @lex.Identifier(name))

  rest = skip(rest, @lex.Lparen)

  let mut params = []
  if not(checkToken(rest, @lex.Rparen)) {
    let (param_list, new_rest) = param_list(rest)
    params = param_list
    rest = new_rest
  }

  rest = skip(rest, @lex.Rparen)
  rest = skip(rest, @lex.Arrow)
  let (return_type, rest) = type_annotation(rest)
  let (body, rest) = fn_body(rest)
  
  let fundef = @types.Fundef ( // TOCHECK: 我不理解这里为什么报错，文档里就是这样构造结构体的
    (name, return_type),
    params,
    body
  )
  
  (fundef, rest)
}

// param_list: param (',' param)*
fn param_list(
  rest : ArrayView[@lex.Token]
) -> (Array[(String, @types.Type)], ArrayView[@lex.Token]) {
  let mut rest = rest
  let mut params = []

  let (param, new_rest) = param(rest)
  params.push(param)
  rest = new_rest

  while checkToken(rest, @lex.Comma) {
    rest = skip(rest, @lex.Comma)
    let (param, new_rest) = param(rest)
    params.push(param)
    rest = new_rest
  }

  (params, rest)
}

// param: IDENTIFIER type_annotation
fn param(
  rest : ArrayView[@lex.Token]
) -> ((String, @types.Type), ArrayView[@lex.Token]) {
  let mut rest = rest
  let name = match rest[0] {
    @lex.Identifier(str) => str
    _ => @util.die("Expected identifier")
  }
  rest = skip(rest, @lex.Identifier(name))

  let (ty, rest) = type_annotation(rest)
  ((name, ty), rest)
}

// fn_body: '{' stmt '}'
fn fn_body(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = skip(rest, @lex.Lcurlybracket)
  let (syn, new_rest) = stmt(rest)
  rest = new_rest
  rest = skip(rest, @lex.Rcurlybracket)
  (syn, rest)
}


// nontop_fn_decl:
// 'fn' IDENTIFIER '(' nontop_param_list? ')' (
// '->' type
// )? fn_body;
fn nontop_fn_decl(
  rest : ArrayView[@lex.Token]
) -> (@types.Fundef, ArrayView[@lex.Token]) {
  let mut rest = skip(rest, @lex.Fn)
  let name = match rest[0] {
    @lex.Identifier(str) => str
    _ => @util.die("Expected identifier")
  }
  rest = skip(rest, @lex.Identifier(name))

  rest = skip(rest, @lex.Lparen)

  let mut args = []
  if not(checkToken(rest, @lex.Rparen)) {
    let (param_list, new_rest) = nontop_param_list(rest)
    args = param_list
    rest = new_rest
  }

  rest = skip(rest, @lex.Rparen)

  let mut ret_ty = @types.Type::Unit
  if checkToken(rest, @lex.Arrow) {
    rest = skip(rest, @lex.Arrow)
    let (ty, new_rest) = type_annotation(rest)
    ret_ty = ty
    rest = new_rest
  }

  let (body, new_rest) = fn_body(rest)
  rest = new_rest

  let fundef = @types.Fundef ( // TOCHECK: 我不理解这里为什么报错，文档里就是这样构造结构体的
    (name, ret_ty),
    args,
    body
  )

  (fundef, rest)
}

// nontop_param_list: nontop_param (',' nontop_param)*
fn nontop_param_list(
  rest : ArrayView[@lex.Token]
) -> (Array[(String, @types.Type)], ArrayView[@lex.Token]) {
  let mut rest = rest
  let mut param_ls = []

  let (param, new_rest) = nontop_param(rest)
  param_ls.push(param)
  rest = new_rest
  while checkToken(rest, @lex.Comma) {
    rest = skip(rest, @lex.Comma)
    let (param, new_rest) = nontop_param(rest)
    param_ls.push(param)
    rest = new_rest
  }

  (param_ls, rest)
}

// nontop_param: IDENTIFIER type_annotation?
fn nontop_param(
  rest : ArrayView[@lex.Token]
) -> ((String, @types.Type), ArrayView[@lex.Token]) {
  let mut rest = rest
  let name = match rest[0] {
    @lex.Identifier(str) => str
    _ => @util.die("Expected identifier")
  }
  rest = skip(rest, @lex.Identifier(name))

  let mut param_type = @types.Type::Unit
  if checkToken(rest, @lex.Colon) {
    rest = skip(rest, @lex.Colon)
    let (ty, new_rest) = type_annotation(rest)
    rest = new_rest
    param_type = ty
  }
  ((name, param_type), rest)
}

// stmt:
// let_tuple_stmt
// | let_stmt
// | fn_decl_stmt
// | assign_stmt
// | expr_stmt;
fn stmt(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest

  match rest[0] {
    @lex.Let => match rest[1] {
      @lex.Lparen => let_tuple_stmt(rest)
      _ => let_stmt(rest)
    }
    @lex.Fn => fn_decl_stmt(rest)
    _ => {
      let mut tmp_rest = get_expr(rest).1
      if checkToken(tmp_rest, @lex.Equ) {
        assign_stmt(rest)
      }
      else {
        expr_stmt(rest)
      }
    }
  }
}


// let_tuple_stmt:
// 'let' '(' IDENTIFIER (',' IDENTIFIER)* ')' type_annotation? '=' expr ';' stmt;
// LetTuple(Array[(String, Type)], Syntax, Syntax)
fn let_tuple_stmt(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = skip(rest, @lex.Let)
  rest = skip(rest, @lex.Lparen)
  
  // 解析标识符列表
  let mut identifiers = []
  let name = match rest[0] {
    @lex.Identifier(str) => str
    _ => @util.die("Expected identifier")
  }
  identifiers.push(name)
  rest = skip(rest, @lex.Identifier(name))
  
  while checkToken(rest, @lex.Comma) {
    rest = skip(rest, @lex.Comma)
    let name = match rest[0] {
      @lex.Identifier(str) => str
      _ => @util.die("Expected identifier")
    }
    identifiers.push(name)
    rest = skip(rest, @lex.Identifier(name))
  }
  
  rest = skip(rest, @lex.Rparen)
  
  let mut ty_arr = []
  if checkToken(rest, @lex.Colon) {
    rest = skip(rest, @lex.Colon)
    let (ty, new_rest) = type_annotation(rest)
    rest = new_rest
    match ty {
      @types.Type::Tuple(arr) => ty_arr = arr
    }
  } 
  let ident_arr = []
  let mut i = 0
  while i < identifiers.length() {
    ident_arr.push((identifiers[i], ty_arr[i]))
    i = i + 1
  }

  rest = skip(rest, @lex.Equ)

  let (expr_syntax, new_rest) = expr(rest)
  rest = new_rest

  rest = skip(rest, @lex.Semicolon)

  let (stmt_syntax, new_rest) = stmt(rest)
  rest = new_rest

  (@types.Syntax::LetTuple(ident_arr, expr_syntax, stmt_syntax), rest)
}

// let_stmt:
// 'let' IDENTIFIER type_annotation? '=' expr ';' stmt;
// let_stmt:
// 'let' IDENTIFIER type_annotation? '=' expr ';' stmt;
fn let_stmt(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = skip(rest, @lex.Let)

  let name = match rest[0] {
    @lex.Identifier(str) => str
    _ => @util.die("Expected identifier")
  }
  rest = skip(rest, @lex.Identifier(name))

  let mut var_type = @types.Type::Unit
  if checkToken(rest, @lex.Colon) {
    rest = skip(rest, @lex.Colon)
    let (ty, new_rest) = type_annotation(rest)
    var_type = ty
    rest = new_rest
  }

  rest = skip(rest, @lex.Equ)
  let (expr_syntax, new_rest) = expr(rest)
  rest = new_rest
  rest = skip(rest, @lex.Semicolon)
  let (stmt_syntax, new_rest) = stmt(rest)
  rest = new_rest
  (@types.Syntax::Let((name, var_type), expr_syntax, stmt_syntax), rest)
}


// fn_decl_stmt: nontop_fn_decl ';' stmt
fn fn_decl_stmt(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let (fundef, new_rest) = nontop_fn_decl(rest)
  let mut rest = new_rest
  rest = skip(rest, @lex.Semicolon)
  let (stmt_syntax, new_rest) = stmt(rest)
  rest = new_rest
  (@types.Syntax::LetRec(fundef, stmt_syntax), rest)
}

// x[y] = z
// assign_stmt: get_expr '=' expr ';' stmt
fn assign_stmt(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let (gexpr_syntax, new_rest) = get_expr(rest)
  let mut rest = new_rest
  rest = skip(rest, @lex.Equ)
  let (expr_syntax, new_rest) = expr(rest)
  rest = new_rest
  rest = skip(rest, @lex.Semicolon)
  let (stmt_syntan, new_rest) = stmt(rest)
  rest = new_rest
  (@types.Syntax::Put(gexpr_syntax, expr_syntax, stmt_syntan), rest)
}

// get_expr: get_or_apply_level_expr '[' expr ']'
fn get_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let (base_expr, new_rest) = get_or_apply_level_expr(rest)
  let mut rest = new_rest
  rest = skip(rest, @lex.Lbracket)
  let (expr, new_rest) = expr(rest)
  rest = new_rest
  rest = skip(rest, @lex.Rbracket)
  (@types.Syntax::Get(base_expr, expr), rest)
}

// expr_stmt: expr
fn expr_stmt(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let (syntax, rest) = expr(rest)
  match syntax {
    @types.Syntax::Prim(_) => (syntax, rest)
    _ => @util.die("Expected a primary expression") // 尝试进行错误处理
  }
}

// Expressions, in order of precedence.
// expr: // not associative
// add_sub_level_expr '==' add_sub_level_expr
// | add_sub_level_expr '<=' add_sub_level_expr
// | add_sub_level_expr;
fn expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let (syn1, new_rest) = add_sub_level_expr(rest)
  let mut rest = new_rest
  let mut syn = syn1
  match rest[0] {
    @lex.Equ => {
      rest = skip(rest, @lex.Equ)
      let (syn2, new_rest) = add_sub_level_expr(rest)
      rest = new_rest
      syn = @types.Syntax::Eq(syn1, syn2)
    }
    @lex.Le => {
      rest = skip(rest, @lex.Le)
      let (syn2, new_rest) = add_sub_level_expr(rest)
      rest = new_rest
      syn = @types.Syntax::LE(syn1, syn2)
    }
  }
  (syn, rest)
}

// add_sub_level_expr: // left associative
//  add_sub_level_expr '+' mul_div_level_expr
// | add_sub_level_expr '-' mul_div_level_expr
// | mul_div_level_expr;
fn add_sub_level_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let (left_syntax, new_rest) = mul_div_level_expr(rest)
  let mut rest = new_rest
  let mut left_syntax = left_syntax 
  while true {
    match rest[0] {
      @lex.Add => {
        rest = skip(rest, @lex.Add)
        let (expr, new_rest) = mul_div_level_expr(rest)
        rest = new_rest
        left_syntax = @types.Syntax::Prim(left_syntax, expr, Add, kind=None)
        continue
      }
      @lex.Sub => {
        rest = skip(rest, @lex.Sub)
        let (expr, new_rest) = mul_div_level_expr(rest)
        rest = new_rest
        left_syntax = @types.Syntax::Prim(left_syntax, expr, Sub, kind=None)
        continue
      }
      _ => break
    }
  }
  (left_syntax, rest)
}

// mul_div_level_expr: // left associative
// mul_div_level_expr '*' if_level_expr
// | mul_div_level_expr '/' if_level_expr
// | if_level_expr;
fn mul_div_level_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let (left_syntax, new_rest) = if_level_expr(rest)
  let mut rest = new_rest
  let mut left_syntax = left_syntax
  while true {
    match rest[0] {
      @lex.Mul => {
        rest = skip(rest, @lex.Mul)
        let (expr, new_rest) = if_level_expr(rest)
        rest = new_rest
        left_syntax = @types.Syntax::Prim(left_syntax, expr, Mul, kind=None)
        continue
      }
      @lex.Div => {
        rest = skip(rest, @lex.Div)
        let (expr, new_rest) = if_level_expr(rest)
        rest = new_rest
        left_syntax = @types.Syntax::Prim(left_syntax, expr, Div, kind=None)
        continue
      }
      _ => break
    }
  }
  (left_syntax, rest)
}


// if_level_expr: get_or_apply_level_expr | if_expr
fn if_level_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  match rest[0] {
    @lex.If => if_expr(rest)
    _ => get_or_apply_level_expr(rest)
  }
}

// if_expr: 'if' expr block_expr ('else' block_expr)?
fn if_expr(
  rest : ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.If)
  let (cond_expr, new_rest) = expr(rest)
  rest = new_rest
  let (if_block, new_rest) = block_expr(rest)
  rest = new_rest
  let mut else_block = @types.Syntax::Unit
  if checkToken(rest, @lex.Else) {
    rest = skip(rest, @lex.Else) 
    let (new_else_block, new_rest) = block_expr(rest)
    rest = new_rest
    else_block = new_else_block
  }
  (@types.Syntax::If(cond_expr, if_block, else_block), rest)
}

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
        rest = skip(rest, @lex.Lbracket) // '['
        let (exp_syn, new_rest) = expr(rest) // expr
        rest = new_rest
        rest = skip(rest, @lex.Rbracket) // ']'
        let syn = @types.Syntax::Get(syn, exp_syn)
        continue
      }
      @lex.Lparen => { // get_or_apply_level_expr '(' (expr (',' expr)*)? ')'
        rest = skip(rest, @lex.Lparen) // '('
        let mut args = []
        if not(checkToken(rest, @lex.Rparen)) { // 如果括号中存在参数
          let (exp, new_rest) = expr(rest) // 解析第一个参数
          args.push(exp)
          rest = new_rest
          while checkToken(rest, @lex.Comma) { // (',' expr)* 解析后续参数
            rest = rest[1:] // 跳过 ','
            let (exp, new_rest) = expr(rest)  
            args.push(exp)
            rest = new_rest
          }
        }
        rest = skip(rest, @lex.Rparen)
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
  rest = skip(rest, @lex.Lparen) //'('
  rest = skip(rest, @lex.Rparen) // ')'
  (@types.Syntax::Unit, rest)
}

// tuple_expr: '(' expr (',' expr)+ ')'; // (x, y); 1-tuple is not allowed
fn tuple_expr(
  rest: ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Lparen) // '('
  let (syn, new_rest) = expr(rest) // expr
  rest = new_rest // 让rest为可修改参数
  let mut arr = Array::new() // (',' expr)+
  arr.push(syn)
  while checkToken(rest, @lex.Comma) {
    rest = rest[1:]
    let (x, new_rest) = expr(rest)
    rest = new_rest
    arr.push(x)
  }
  if arr.length() < 2 { // 1-tuple is not allowed
    @util.die("1-tuple is not allowed")
  }
  rest = skip(rest, @lex.Rparen) // ')'
  (@types.Syntax::Tuple(arr), rest)
}

// block_expr: '{' stmt '}'; // { blah; blah; }
fn block_expr(
  rest: ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Lcurlybracket) // '{'
  let (syn, rest) = stmt(rest) // stmt
  let mut rest = rest
  rest = skip(rest, @lex.Rcurlybracket) // '}'
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
  rest = skip(rest, @lex.Sub) // '-'
  let (syn, rest) = value_expr(rest) // value_expr
  (@types.Syntax::Neg(syn, kind=None), rest) // Kind ? 
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
  rest = skip(rest, @lex.Dot) // '.'
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
  rest = skip(rest, @lex.Not) // 'not'
  rest = skip(rest, @lex.Lparen) // '('
  let (syn, rest) = expr(rest) // expr
  let mut rest = skip(rest, @lex.Rparen) // ')'
  (@types.Syntax::Not(syn), rest)
}

// array_make_expr: 'Array' ':' ':' 'make' '(' expr ',' expr ')'
fn array_make_expr(
  rest: ArrayView[@lex.Token]
) -> (@types.Syntax, ArrayView[@lex.Token]) {
  let mut rest = rest
  rest = skip(rest, @lex.Array) // 'Array'
  rest = skip(rest, @lex.Colon) // ':'
  rest = skip(rest, @lex.Colon) // ':'
  rest = skip(rest, @lex.Make) // 'make'
  rest = skip(rest, @lex.Lparen) // '('
  let (syn1, rest) = expr(rest) // expr
  let mut rest = skip(rest, @lex.Comma) // ','
  let (syn2, rest) = expr(rest) // expr
  let mut rest = skip(rest, @lex.Rparen) //')'
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
) -> ArrayView[@lex.Token] {
  match rest[0] {  
    tk => rest[1:]// 当前ArrayView中第一个Token与tk匹配时进行跳过，返回 新ArrayView
    _ => rest // 否则返回 原ArrayView
  }
}

fn checkToken(
  rest: ArrayView[@lex.Token], 
  token: @lex.Token
) -> Bool {
  match rest[0] {
    token => true
    _ => false
  }
}

// type (不包含COLON)
fn type_annotation(
  rest : ArrayView[@lex.Token]
) -> (@types.Type, ArrayView[@lex.Token]) {
  let mut rest = rest
  let ty = match rest[0] {
    @lex.Unit => { // Unit
      rest = skip(rest, @lex.Unit)
      @types.Type::Unit
    }
    @lex.Bool => { // Bool
      rest = skip(rest, @lex.Bool)
      @types.Type::Bool
    }
    @lex.Int => { // Int
      rest = skip(rest, @lex.Int)
      @types.Type::Int
    }
    @lex.Double => { // Double
      rest = skip(rest, @lex.Double)
      @types.Type::Double
    }
    @lex.Fn => { // Fun(Arrar[Type], Type)
      rest = skip(rest, @lex.Fn)
      rest = skip(rest, @lex.Lparen)
      let mut arg_types = []
      if not(checkToken(rest, @lex.Rparen)) {
        let (arg_type, new_rest) = type_annotation(rest)
        arg_types.push(arg_type)
        rest = new_rest
        while checkToken(rest, @lex.Comma) {
          rest = skip(rest, @lex.Comma)
          let (arg_type, new_rest) = type_annotation(rest)
          arg_types.push(arg_type)
          rest = new_rest
        }
      }
      rest = skip(rest, @lex.Rparen)

      let mut ret_type = @types.Type::Unit
      if checkToken(rest, @lex.Arrow) {
        rest = skip(rest, @lex.Arrow)
        let (new_ret_type, new_rest) = type_annotation(rest)
        rest = new_rest
        ret_type = new_ret_type
      }
      @types.Type::Fun(arg_types, ret_type)
    }
    @lex.Lparen => { // Tuple(Array[Type]) //TOCHECK
      rest = skip(rest, @lex.Lparen)
      let mut elem_types = []
      let (elem_type, new_rest) = type_annotation(rest)
      elem_types.push(elem_type)
      rest = new_rest
      while checkToken(rest, @lex.Comma) {
        rest = skip(rest, @lex.Comma)
        let (elem_type, new_rest) = type_annotation(rest)
        elem_types.push(elem_type)
        rest = new_rest
      }
      rest = skip(rest, @lex.Rparen)
      @types.Type::Tuple(elem_types)
    }
    @lex.Array => { // Array(Type) // TOCHECK
      rest = skip(rest, @lex.Array)
      rest = skip(rest, @lex.Lbracket)
      let (elem_type, new_rest) = type_annotation(rest)
      rest = new_rest
      rest = skip(rest, @lex.Rbracket)
      @types.Type::Array(elem_type)
    }
    @lex.Identifier(str) => { // Var(Ref[Type?]) // TOCHECK
      rest = skip(rest, @lex.Identifier(str))
      let (var_type, new_rest) = type_annotation(rest)
      rest = new_rest
      @types.Type::Var(Ref::new(Some(var_type)))
    }
    // Ptr
    _ => @util.die("Unexpected type token")
  }
  (ty, rest)
}
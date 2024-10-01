// Token Kinds
enum Token {
  True //'true'
  False //'false'
  Unit //'Unit'
  Bool //'Bool'
  Int //'Int'
  Double //'Double'
  Array // 'Array'
  Not // 'not'
  If // 'if'
  Else // 'else'
  Fn // 'fn'
  Let // 'let'
  Number(Int) // [0-9]+
  Identifier // [a-zA-Z_][a-zA-Z0-9_]*
  Dot // '.'
  Add // '+'
  Sub // '-'
  Mul // '*'
  Div // '/'
  Assign // '='
  Eq // '=='
  Le // '<='
  Lparen // '('
  Rparen // ')'
  Lbracket // '['
  Rbracket // ']'
  Lcurlybracket // '{'
  Rcurlybracket // '}'
  Arrow // '->'
  Colon // ':'
  Semicolon // ';'
  Comma // ','
  Ws // [ \t\r\n]+ -> skip
  Comment // '//' ~[\r\n]* -> skip
} derive(Show)

struct Context {
  str : String
  mut offset : Int
  array : Array[Token]
}

fn lex(context : Context) -> Unit {
  let { offset, str, array } = context
  if offset >= str.length() {
    return
  }
  match str[offset] {
    // µ¥×Ö½Ú·ûºÅ 
    '+' => {
      array.push(Add)
      context.offset += 1
      lex(context)
    }
    '-' => {
      array.push(Sub)
      context.offset += 1
      lex(context)
    }
    '*' => {
      array.push(Mul)
      context.offset += 1
      lex(context)
    }
    '/' => {
      array.push(Div)
      context.offset += 1
      lex(context)
    }
    '(' => {
      array.push(Lparen)
      context.offset += 1
      lex(context)
    }
    ')' => {
      array.push(Rparen)
      context.offset += 1
      lex(context)
    }
    ' ' | '\n' | '\t' | '\r' => {
      context.offset += 1
      lex(context)
    }
    '.' => {
      array.push(Dot)
      context.offset += 1
      lex(context)
    }
    '=' => {
      array.push(Assign)
      context.offset += 1
      lex(context)
    }
    '[' => {
      array.push(Lbracket)
      context.offset += 1
      lex(context)
    }
    ']' =>  {
      array.push(Rbracket)
      context.offset += 1
      lex(context)
    }
    '{' => {
      array.push(Lcurlybracket)
      context.offset += 1
      lex(context)
    }
    '}' =>  {
      array.push(Rcurlybracket)
      context.offset += 1
      lex(context)
    }
    ':' => {
      array.push(Colon)
      context.offset += 1
      lex(context)
    }
    ';' => {
      array.push(Semicolon)
      context.offset += 1
      lex(context)
    }
    ',' => {
      array.push(Comma)
      context.offset += 1
      lex(context)
    }
    
    ch => if ch >= '0' && ch <= '9' { lex_number(context) } else { panic() }
  }
}

fn lex_number(context : Context) -> Unit {
  let { offset, str, .. } = context
  let number = "\{str[offset]}"
  context.offset += 1
  lex_number_rest(context, number)
}

fn lex_number_rest(context : Context, number : String) -> Unit {
  let { offset, str, array } = context
  if offset >= str.length() {
    array.push(Number(@strconv.parse_int?(number).unwrap()))
    return
  }
  let ch = str[offset]
  if ch >= '0' && ch <= '9' {
    context.offset += 1
    lex_number_rest(context, number + ch.to_string())
  } else {
    array.push(Number(@strconv.parse_int?(number).unwrap()))
    lex(context)
  }
}



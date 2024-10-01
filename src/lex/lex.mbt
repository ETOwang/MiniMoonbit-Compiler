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
  Identifier(String) // [a-zA-Z_][a-zA-Z0-9_]*
  Dot // '.'
  Add // '+'
  Sub // '-'
  Mul // '*'
  Div // '/'
  Assign // '='
  Equ // '=='
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

pub struct Context {
  str : String
  mut offset : Int
  array : Array[Token]
}

pub fn lex(context : Context) -> Unit {
	let str = context.str
  while context.offset < str.length() {

    //空格、制表符、换行符 -> skip
    if str[context.offset] == ' ' ||
      str[context.offset] == '\t' ||
      str[context.offset] == '\r' ||
      str[context.offset] == '\n' {
      context.offset += 1
      continue
    }

    //注释 -> skip
    if context.offset + 1 < str.length() && str[context.offset] == '/' && str[context.offset + 1] == '/' {
      context.offset += 2
      while context.offset < str.length() && str[context.offset] != '\n' {
        context.offset += 1
      }
      continue
    }

    //Number
    if str[context.offset] >= '0' && str[context.offset] <= '9' {
      let number = "\{str[context.offset]}"
      context.offset += 1
      lex_number_rest(context, number)
      continue
    }

    //Identifier
    if (str[context.offset] >= 'a' && str[context.offset] <= 'z') ||
      (str[context.offset] >= 'A' && str[context.offset] <= 'Z') ||
      str[context.offset] == '_' {
      let identifier = "\{str[context.offset]}"
      context.offset += 1
      lex_identifier_rest(context, identifier)
      continue
    }

    //操作符

    //双字节操作符
    if context.offset + 1 < str.length() {
      // ==
      if str[context.offset] == '=' && str[context.offset + 1] == '=' {
        context.array.push(Equ)
        context.offset += 2
        continue
      }
      // <=
      if str[context.offset] == '<' && str[context.offset + 1] == '=' {
        context.array.push(Le)
        context.offset += 2
        continue
      }
      // ->
      if str[context.offset] == '-' && str[context.offset + 1] == '>' {
        context.array.push(Arrow)
        context.offset += 2
        continue
      }
    }

    //单字节操作符
    match str[context.offset] {
      '+' => {
        context.array.push(Add)
        context.offset += 1
        continue
      }
      '-' => {
        context.array.push(Sub)
        context.offset += 1
        continue
      }
      '*' => {
        context.array.push(Mul)
        context.offset += 1
        continue
      }
      '/' => {
        context.array.push(Div)
        context.offset += 1
        continue
      }
      '(' => {
        context.array.push(Lparen)
        context.offset += 1
        continue
      }
      ')' => {
        context.array.push(Rparen)
        context.offset += 1
        continue
      }
      '.' => {
        context.array.push(Dot)
        context.offset += 1
        continue
      }
      '=' => {
        context.array.push(Assign)
        context.offset += 1
        continue
      }
      '[' => {
        context.array.push(Lbracket)
        context.offset += 1
        continue
      }
      ']' => {
        context.array.push(Rbracket)
        context.offset += 1
        continue
      }
      '{' => {
        context.array.push(Lcurlybracket)
        context.offset += 1
        continue
      }
      '}' => {
        context.array.push(Rcurlybracket)
        context.offset += 1
        continue
      }
      ':' => {
        context.array.push(Colon)
        context.offset += 1
        continue
      }
      ';' => {
        context.array.push(Semicolon)
        context.offset += 1
        continue
      }
      ',' => {
        context.array.push(Comma)
        context.offset += 1
        continue
      }
    }

    //错误处理
  }
}

// 匹配第一个数字之后的数字
fn lex_number_rest(context : Context, number : String) -> Unit {
  if context.offset >= context.str.length() {
    context.array.push(Number(@strconv.parse_int?(number).unwrap()))
    return
  }
  let ch = context.str[context.offset]
  // 下一个字符是数字，继续匹配，否则将已获得的数字（目前以String形式保存）转化为Int并构造Number
  if ch >= '0' && ch <= '9' {
    context.offset += 1
    lex_number_rest(context, number + ch.to_string())
  } else {
    context.array.push(Number(@strconv.parse_int?(number).unwrap()))
  }
}

//匹配第一个字符之后的字符
fn lex_identifier_rest(context : Context, identifier : String) -> Unit {
  if context.offset >= context.str.length() {
    context.array.push(Identifier(identifier))
    return
  }
  let ch = context.str[context.offset]
  // 下一个字符是字母、数字、下划线，继续匹配，否则将已获得的字符串构造Identifier
  if (ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= '0' && ch <= '9') ||
    ch == '_' {
    context.offset += 1
    lex_identifier_rest(context, identifier + ch.to_string())
  } else {
    context.array.push(Identifier(identifier))
  }
}

// TODO: 检索Identifier，判断是否为keyword并修改对应的Token

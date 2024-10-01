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

struct Context {
  str : String
  mut offset : Int
  array : Array[Token]
}

fn lex(context : Context) -> Unit {
  let { offset, str, array } = context
  while offset < str.length() {

    //空格、制表符、换行符 -> skip
    if str[offset] == ' ' ||
      str[offset] == '\t' ||
      str[offset] == '\r' ||
      str[offset] == '\n' {
      context.offset += 1
      continue
    }

    //注释 -> skip
    if offset + 1 < str.length() && str[offset] == '/' && str[offset + 1] == '/' {
      context.offset += 2
      while offset < str.length() && str[offset] != '\n' {
        context.offset += 1
      }
      continue
    }

    //Number
    if str[offset] >= '0' && str[offset] <= '9' {
      let number = "\{str[offset]}"
      context.offset += 1
      lex_number_rest(context, number)
      continue
    }

    //Identifier
    if (str[offset] >= 'a' && str[offset] <= 'z') ||
      (str[offset] >= 'A' && str[offset] <= 'Z') ||
      str[offset] == '_' {
      let identifier = "\{str[offset]}"
      context.offset += 1
      lex_identifier_rest(context, identifier)
      continue
    }

    //操作符

    //双字节操作符
    // ==
    if String::starts_with(str, "==") {
      array.push(Equ)
      context.offset += 2
      continue
    }
    // <=
    if String::starts_with(str, "<=") {
      array.push(Le)
      context.offset += 2
      continue
    }
    // ->
    if String::starts_with(str, "->") {
      array.push(Arrow)
      context.offset += 2
      continue
    }

    //单字节操作符
    match str[offset] {
      '+' => {
        array.push(Add)
        context.offset += 1
        continue
      }
      '-' => {
        array.push(Sub)
        context.offset += 1
        continue
      }
      '*' => {
        array.push(Mul)
        context.offset += 1
        continue
      }
      '/' => {
        array.push(Div)
        context.offset += 1
        continue
      }
      '(' => {
        array.push(Lparen)
        context.offset += 1
        continue
      }
      ')' => {
        array.push(Rparen)
        context.offset += 1
        continue
      }
      '.' => {
        array.push(Dot)
        context.offset += 1
        continue
      }
      '=' => {
        array.push(Assign)
        context.offset += 1
        continue
      }
      '[' => {
        array.push(Lbracket)
        context.offset += 1
        continue
      }
      ']' => {
        array.push(Rbracket)
        context.offset += 1
        continue
      }
      '{' => {
        array.push(Lcurlybracket)
        context.offset += 1
        continue
      }
      '}' => {
        array.push(Rcurlybracket)
        context.offset += 1
        continue
      }
      ':' => {
        array.push(Colon)
        context.offset += 1
        continue
      }
      ';' => {
        array.push(Semicolon)
        context.offset += 1
        continue
      }
      ',' => {
        array.push(Comma)
        context.offset += 1
        continue
      }
    }

		//错误处理
  }
}


// 匹配第一个数字之后的数字
fn lex_number_rest(context : Context, number : String) -> Unit {
  let { offset, str, array } = context
  if offset >= str.length() {
    array.push(Number(@strconv.parse_int?(number).unwrap()))
    return
  }
  let ch = str[offset]
	// 下一个字符是数字，继续匹配，否则将已获得的数字（目前以String形式保存）转化为Int并构造Number
  if ch >= '0' && ch <= '9' {
    context.offset += 1
    lex_number_rest(context, number + ch.to_string())
  } else {
    array.push(Number(@strconv.parse_int?(number).unwrap()))
  }
}

//匹配第一个字符之后的字符
fn lex_identifier_rest(context : Context, identifier : String) -> Unit {
  let { offset, str, array } = context
  if offset >= str.length() {
    array.push(Identifier(identifier))
    return
  }
  let ch = str[offset]
	// 下一个字符是字母、数字、下划线，继续匹配，否则将已获得的字符串构造Identifier
  if (ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= '0' && ch <= '9') ||
    ch == '_' {
    context.offset += 1
    lex_identifier_rest(context, identifier + ch.to_string())
  } else {
    array.push(Identifier(identifier))
  }
}

// TODO: 检索Identifier，判断是否为keyword并修改对应的Token

test {
  let array = []
  lex({ str: "-10123 -+ - 523", offset: 0, array })
  inspect!(
    array,
    content="[Sub, Number(10123), Sub, Add, Sub, Number(523), Number(103), LParen, Number(5), RParen, RParen]",
  )
}


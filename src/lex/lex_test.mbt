

test {
    let s = "1234 + 2  -353 * 8 / 9 (136 + 2) {2 * 3453}"
    let context:@lex.Context = {str: s, offset: 0, array: []}
    @lex.lex(context)
    inspect!(
        context.array,
        content="[Number(1234), Add, Number(2), Sub, Number(353), Mul, Number(8), Div, Number(9), Lparen, Number(136), Add, Number(2), Rparen, Lcurlybracket, Number(2), Mul, Number(3453), Rcurlybracket]"
    )
}

test {
    let s = "var1 = 1;"
    let context:@lex.Context = {str: s, offset: 0, array: []}
    @lex.lex(context)
    inspect!(
        context.array,
        content="[Identifier(\"var1\"), Assign, Number(1), Semicolon]"
    )
}

test {
    let s = "var1 = 123 + var2 - 456 * var3 / 789 (var4 + 10) {20 * var5}"
    let context:@lex.Context = {str: s, offset: 0, array: []}
    @lex.lex(context)
    inspect!(
        context.array,
        content="[Identifier(\"var1\"), Assign, Number(123), Add, Identifier(\"var2\"), Sub, Number(456), Mul, Identifier(\"var3\"), Div, Number(789), Lparen, Identifier(\"var4\"), Add, Number(10), Rparen, Lcurlybracket, Number(20), Mul, Identifier(\"var5\"), Rcurlybracket]"
    )
}

test {
    let s = "true false Unit Bool Int Double Array not if else fn let"
    let context:@lex.Context = {str: s, offset: 0, array: []}
    @lex.lex(context)
    inspect!(
        context.array,
        content="[True, False, Unit, Bool, Int, Double, Array, Not, If, Else, Fn, Let]"
    )
}

test {
    let s = "true var1 = 123 + false - 456 * Unit / 789 (Bool + 10) {20 * Int}"
    let context:@lex.Context = {str: s, offset: 0, array: []}
    @lex.lex(context)
    inspect!(
        context.array,
        content="[True, Identifier(\"var1\"), Assign, Number(123), Add, False, Sub, Number(456), Mul, Unit, Div, Number(789), Lparen, Bool, Add, Number(10), Rparen, Lcurlybracket, Number(20), Mul, Int, Rcurlybracket]"
    )
}






test {
    let s = "1 2 3"
    let context:@lex.Context = {str: s, offset: 0, array: []}
    @lex.lex(context)
    inspect!(
        context.array,
        content="[Number(1), Number(2), Number(3)]"
    )
}

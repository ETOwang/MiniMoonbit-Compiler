test {
  let input = @fs.read_file_to_string!(path="test/test_src/sum.mbt")
  let tokens = []
  let context : @lex.Context = { str: input, offset: 0, array: tokens }
  @lex.lex(context)
  let expr = @parser.prog(context)
  inspect!(expr, content="")
}

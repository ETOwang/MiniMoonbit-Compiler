test {
  let input = @fs.read_file_to_string!(path="test/test_src/cls-bug2.mbt")
  let tokens = []
  let context : @lex.Context = { str: input, offset: 0, array: tokens }
  @lex.lex(context)
  let expr = @parser.prog(context)
  inspect!(expr, content="")
}

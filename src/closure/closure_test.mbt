fn externals() -> @immut/hashmap.T[String, @types.Type] {
  @immut/hashmap.T::new()
  .add("read_int", @types.Fun([], Int))
  .add("read_char", @types.Fun([], Int))
  .add("print_int", @types.Fun([Int], Unit))
  .add("print_char", @types.Fun([Int], Unit))
  .add("print_endline", @types.Fun([], Unit))
  .add("create_array", @types.Fun([Int, Int], @types.Type::Array(Int)))
  .add(
    "create_float_array",
    @types.Fun([Int, Double], @types.Type::Array(Double)),
  )
  .add("create_ptr_array", @types.Fun([Int, Ptr], @types.Type::Array(Ptr)))
  .add("truncate", @types.Fun([Double], Int))
  .add("sin", @types.Fun([Double], Double))
  .add("cos", @types.Fun([Double], Double))
  .add("sqrt", @types.Fun([Double], Double))
  .add("abs_float", @types.Fun([Double], Double))
  .add("int_of_float", @types.Fun([Double], Int))
  .add("float_of_int", @types.Fun([Int], Double))
}

test {
  let input = @fs.read_file_to_string!(path="test/test_src/fib.mbt")
  let context = @parser.parse(input)
  let typechecked = @typing.typing!(context)
  let knf_env = @knf.KnfEnv::new(externals())
  let knf = knf_env.to_knf(typechecked)
  println(knf)
  println("---------------")
  let closure_ir = @closure.knf_program_to_closure(
    knf,
    Map::from_iter(externals().iter()),
  )
  println(closure_ir)
}

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
  let input = @fs.read_file_to_string!(path="test/test_src/ack.mbt")
  let context = @parser.parse(input)
  let typechecked = @typing.typing!(context)
  println(typechecked)
  println("---------------")
  let knf_env = @knf.KnfEnv::new(externals())
  let knf = knf_env.to_knf(typechecked)
  let closure_ir = @closure.knf_program_to_closure(
    knf,
    Map::from_iter(externals().iter()),
  )
  println(knf)
  println("---------------")
  println(closure_ir)
  println("---------------")
  let asm = emit(closure_ir)
  println(print_functions(asm))
}
// {fundefs: [{name: Label("minimbt_main"), 
// old_name: minimbt_main, 
// is_closure: true, 
// ty: ClosureFn([], Unit), 
// args: [], formal_free_vars: [(_1, ClosureFn([Int, Int], Int))], 
// body: Let((_206, ClosureFn([Int, Int], ClosureFn([Int, Int], Int))), 
// Let((_204, Int), Int(3), 
// Let((_205, Int), Int(8), 
// CallClosure(_1, [_204, _205]))), 
// CallDirect(Label("minimbt_print_int"), [_206]))}, 
// {name: Label("_1"), 
// old_name: _1,
//  is_closure: true, 
//  ty: ClosureFn([Int, Int], Int), 
//  args: [(_3, Int), (_4, Int)], 
//  formal_free_vars: [], 
//  body: Let((_15, Int), Int(0), 
//  IfLe(_3, _15, Let((_5, Int), Int(1), Add(_4, _5)),
//   Let((_14, Int), Int(0), IfLe(_4, _14, Let((_7, Int), 
//   Let((_6, Int), Int(1), Sub(_3, _6)), 
//   Let((_8, Int), Int(1), 
//   CallClosure(_1, [_7, _8]))), 
//   Let((_10, Int), 
//   Let((_9, Int), Int(1), Sub(_3, _9)), 
//   Let((_13, ClosureFn([Int, Int], 
//   ClosureFn([Int, Int], Int))), 
//   Let((_12, Int), 
//   Let((_11, Int), Int(1), Sub(_4, _11)), 
//   CallClosure(_1, [_3, _12])), 
//   CallClosure(_1, [_10, _13])))))))}],}

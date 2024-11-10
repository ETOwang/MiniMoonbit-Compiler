// fn externals() -> @immut/hashmap.T[String, @types.Type] {
//   @immut/hashmap.T::new()
//   .add("read_int", @types.Fun([], Int))
//   .add("read_char", @types.Fun([], Int))
//   .add("print_int", @types.Fun([Int], Unit))
//   .add("print_char", @types.Fun([Int], Unit))
//   .add("print_endline", @types.Fun([], Unit))
//   .add("create_array", @types.Fun([Int, Int], @types.Type::Array(Int)))
//   .add(
//     "create_float_array",
//     @types.Fun([Int, Double], @types.Type::Array(Double)),
//   )
//   .add("create_ptr_array", @types.Fun([Int, Ptr], @types.Type::Array(Ptr)))
//   .add("truncate", @types.Fun([Double], Int))
//   .add("sin", @types.Fun([Double], Double))
//   .add("cos", @types.Fun([Double], Double))
//   .add("sqrt", @types.Fun([Double], Double))
//   .add("abs_float", @types.Fun([Double], Double))
//   .add("int_of_float", @types.Fun([Double], Int))
//   .add("float_of_int", @types.Fun([Int], Double))
// }

// test {
//   let input = @fs.read_file_to_string!(path="test/test_src/join-stack.mbt")
//   let context = @parser.parse(input)
//   let typechecked = @typing.typing!(context)
//   println(typechecked)
//   println("---------------")
//   let knf_env = @knf.KnfEnv::new(externals())
//   let knf = knf_env.to_knf(typechecked)
//   let closure_ir = @closure.knf_program_to_closure(
//     knf,
//     Map::from_iter(externals().iter()),
//   )
//   println(knf)
//   println("---------------")
//   println(closure_ir)
//   println("---------------")
//   let asm = emit(closure_ir)
//   println(print_functions(asm))
// }
// // fundefs: [{name: Label("minimbt_main"), 
// // old_name: minimbt_main, 
// // is_closure: true, 
// // ty: ClosureFn([], Unit), 
// // args: [], 
// // formal_free_vars: [(_1, ClosureFn([Unit], Int)), (_202, ClosureFn([Unit], Int)), (_403, ClosureFn([Unit], Int))], 
// // body: Let((_607, Int), 
// // Let((_606, Unit), Unit, CallClosure(_1, [_606])), 
// // Let((_609, Int), 
// // Let((_608, Unit), Unit, CallClosure(_202, [_608])), 
// // Let((_617, Int), 
// // Let((_616, Int), 
// // Let((_615, Int), 
// // Let((_613, Int), 
// // Let((_610, Unit), Unit, CallClosure(_403, [_610])), 
// // Let((_614, Int), Int(0),
// //  IfEq(_613, _614, 
// //  Let((_611, Int), Int(1), Add(_607, _611)), 
// //  Let((_612, Int), Int(2), Add(_609, _612))))),
// //   Add(_615, _607)), 
// //   Add(_616, _609)), 
// //   CallDirect(Label("minimbt_print_int"), [_617]))))},
// //    {name: Label("_403"),
// //     old_name: _403, 
// //     is_closure: true, 
// //     ty: ClosureFn([Unit], Int), 
// //     args: [(_405, Unit)], 
// //     formal_free_vars: [], 
// //     body: Int(789)}, 
// //     {name: Label("_202"), 
// //     old_name: _202, 
// //     is_closure: true, 
// //     ty: ClosureFn([Unit], Int),
// //      args: [(_204, Unit)],
// //       formal_free_vars: [],
// //        body: Int(456)}, 
// //        {name: Label("_1"), 
// //        old_name: _1, 
// //        is_closure: true, 
// //        ty: ClosureFn([Unit], Int), 
// //        args: [(_3, Unit)], formal_free_vars: [], body: Int(123)}], 
// // {fundefs: [{name: Label("minimbt_main"), 
// // old_name: minimbt_main, 
// // is_closure: true, 
// // ty: ClosureFn([], Unit), 
// // args: [], 
// // formal_free_vars: [(_202, ClosureFn([Int, Int, Int, Int, Int, Int], Unit))], 
// // body: Let((_405, Int), Int(1), 
// // Let((_406, Int), Int(2), 
// // Let((_407, Int), Int(3), 
// // Let((_408, Int), Int(4), 
// // Let((_409, Int), Int(5), 
// // Let((_410, Int), Int(6), 
// // CallClosure(_202, [_405, _406, _407, _408, _409, _410])))))))}, 
// // {name: Label("_202"), 
// // old_name: _202, 
// // is_closure: true, 
// // ty: ClosureFn([Int, Int, Int, Int, Int, Int], Unit), 
// // args: [(_204, Int), (_205, Int), (_206, Int), (_207, Int), (_208, Int), (_209, Int)], 
// // formal_free_vars: [(_1, ClosureFn([Int, Int, Int, Int, Int, Int], Unit))],
// // body: CallClosure(_1, [_205, _204, _207, _208, _209, _206])},
// //  {name: Label("_1"), 
// //  old_name: _1, 
// //  is_closure: true, 
// //  ty: ClosureFn([Int, Int, Int, Int, Int, Int], Unit), 
// //  args: [(_3, Int), (_4, Int), (_5, Int), (_6, Int), (_7, Int), (_8, Int)], 
// //  formal_free_vars: [], 
// //  body: Let((_9, Unit), CallDirect(Label("minimbt_print_int"), 
// //  [_3, _4, _5, _6, _7, _8]), 
// //  Let((_10, Unit), 
// //  CallDirect(Label("minimbt_print_int"), [_4, _5, _6, _7, _8]),
// //   Let((_11, Unit), CallDirect(Label("minimbt_print_int"), [_5, _6, _7, _8]), Let((_12, Unit), CallDirect(Label("minimbt_print_int"), [_6, _7, _8]), Let((_13, Unit), CallDirect(Label("minimbt_print_int"), [_7, _8]), Let((_14, Unit), CallDirect(Label("minimbt_print_int"), [_8]), Unit))))))}], body: MakeClosure((_1, ClosureFn([Int, Int, Int, Int, Int, Int], Unit)), {name: Label("_1"), actual_free_vars: []}, MakeClosure((_202, ClosureFn([Int, Int, Int, Int, Int, Int], Unit)), {name: Label("_202"), actual_free_vars: [_1]}, MakeClosure((minimbt_main, ClosureFn([], Unit)), {name: Label("minimbt_main"), actual_free_vars: [_202]}, CallClosure(minimbt_main, []))))}
// // {fundefs: [{name: Label("_403"), 
// // old_name: _403, 
// // is_closure: true, 
// // ty: ClosureFn([], Unit), 
// // args: [], 
// // formal_free_vars: [(_202, ClosureFn([Int], ClosureFn([Int], Int)))], 
// // body: Let((_408, Int), 
// // Let((_406, ClosureFn([Int], Int)), 
// // Let((_405, Int), Int(456), 
// // CallClosure(_202, [_405])), 
// // Let((_407, Int), Int(789),
// // CallClosure(_406, [_407]))),
// // CallDirect(Label("minimbt_print_int"), [_408]))}, 
// // {name: Label("_202"), 
// // old_name: _202, 
// // is_closure: true, ty: ClosureFn([Int], ClosureFn([Int], Int)), 
// // args: [(_204, Int)],
// // formal_free_vars: [(_1, ClosureFn([Int], Int))], 
// // body: Var(_1)}, 
// // {name: Label("_1"), 
// // old_name: _1, 
// // is_closure: true, 
// // ty: ClosureFn([Int], Int), 
// // args: [(_3, Int)], 
// // formal_free_vars: [], 
// // body: Let((_4, Int), Int(123), Add(_3, _4))}]}
// // {fundefs: [{name: Label("minimbt_main"), 
// // old_name: minimbt_main, 
// // is_closure: true, 
// // ty: ClosureFn([], Unit), 
// // args: [], 
// // formal_free_vars: [(_1, ClosureFn([Int], ClosureFn([Int], Int)))], 
// // body: Let((_207, ClosureFn([Int], ClosureFn([Int], ClosureFn([Int], Int)))), 
// // Let((_205, ClosureFn([Int], ClosureFn([Int], ClosureFn([Int], Int)))), 
// // Let((_204, Int), Int(3), 
// // CallClosure(_1, [_204])), 
// // Let((_206, Int), Int(7), 
// // CallClosure(_205, [_206]))), 
// // CallDirect(Label("minimbt_print_int"), [_207]))}, 
// // {name: Label("_1"), 
// // old_name: _1, 
// // is_closure: true, 
// // ty: ClosureFn([Int], ClosureFn([Int], Int)), 
// // args: [(_3, Int)], 
// // formal_free_vars: [], 
// // body: MakeClosure((_4, ClosureFn([Int], Int)), 
// // {name: Label("_4"), actual_free_vars: [_3]},
// //  Var(_4))}, 
// //  {name: Label("_4"),
// //   old_name: _4, 
// //   is_closure: true, 
// //   ty: ClosureFn([Int], Int), 
// //   args: [(_6, Int)], 
// //   formal_free_vars: [(_3, Int)], 
// //   body: Add(_3, _6)}]}
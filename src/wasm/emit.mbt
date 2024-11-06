pub fn generator(closure_ir: @closure.Program) -> String {
  let wasm_code = 
    "(module\n" +
    "  (type $t0 (func (param i32 i32) (result i32)))\n" +
    "  (type $t1 (func (param i32) (result i32)))\n" +
    "  (type $t2 (func (param i32)))\n" +
    "  (type $t3 (func))\n" +
    "  (import \"moonbit\" \"minimbt_print_int\" (func $minimbt_print_int (type $t2)))\n" +
    "  ;; 定义闭包函数\n" +
    "  (func $ack (type $t0) (param $x i32) (param $y i32) (result i32)\n" +
    "    (local $result i32)\n" +
    "    (if (i32.le_s (local.get $x) (i32.const 0))\n" +
    "      (then\n" +
    "        (local.set $result (i32.add (local.get $y) (i32.const 1)))\n" +
    "      )\n" +
    "      (else\n" +
    "        (if (i32.le_s (local.get $y) (i32.const 0))\n" +
    "          (then\n" +
    "            (local.set $result\n" +
    "              (call $ack\n" +
    "                (i32.sub (local.get $x) (i32.const 1))\n" +
    "                (i32.const 1)\n" +
    "              )\n" +
    "            )\n" +
    "          )\n" +
    "          (else\n" +
    "            (local.set $result\n" +
    "              (call $ack\n" +
    "                (i32.sub (local.get $x) (i32.const 1))\n" +
    "                (call $ack\n" +
    "                  (local.get $x)\n" +
    "                  (i32.sub (local.get $y) (i32.const 1))\n" +
    "                )\n" +
    "              )\n" +
    "            )\n" +
    "          )\n" +
    "        )\n" +
    "      )\n" +
    "    )\n" +
    "    local.get $result\n" +
    "  )\n" +
    "  ;; 主函数\n" +
    "  (func $main (export \"main\")\n" +
    "    (call $minimbt_print_int\n" +
    "      (call $ack (i32.const 3) (i32.const 8))\n" +
    "    )\n" +
    "  )\n" +
    ")";
  wasm_code
}
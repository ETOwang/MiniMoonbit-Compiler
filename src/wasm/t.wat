(module
  (type $t0 (func (param i32 i32) (result i32)))
  (type $t1 (func (param i32) (result i32)))
  (type $t2 (func (param i32)))
  (type $t3 (func))
  (import "moonbit" "minimbt_print_int" (func $minimbt_print_int (type $t2)))
  
  ;; 定义闭包函数
  (func $ack (type $t0) (param $x i32) (param $y i32) (result i32)
    (local $result i32)
    (if (i32.le_s (local.get $x) (i32.const 0))
      (then
        (local.set $result (i32.add (local.get $y) (i32.const 1)))
      )
      (else
        (if (i32.le_s (local.get $y) (i32.const 0))
          (then
            (local.set $result
              (call $ack
                (i32.sub (local.get $x) (i32.const 1))
                (i32.const 1)
              )
            )
          )
          (else
            (local.set $result
              (call $ack
                (i32.sub (local.get $x) (i32.const 1))
                (call $ack
                  (local.get $x)
                  (i32.sub (local.get $y) (i32.const 1))
                )
              )
            )
          )
        )
      )
    )
    local.get $result
  )
  
  ;; 主函数
  (func $main 
    (call $minimbt_print_int
      (call $ack (i32.const 3) (i32.const 8))
    )
  )
  (export "main" (func $main))
)
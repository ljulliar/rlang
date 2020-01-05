;; Global variables section

  ;; memory implant addresses
  (global $INSTRUCTIONS (mut i32) (i32.const 2432)) ;;instructions definition
  (global $OPCODES (mut i32) (i32.const 8192))  ;; rbx application program 

  (func $wat_sample (param $arg i32) (result i32)
    (i32.add (i32.const 1000) (local.get $arg))
  )
  (export "wat_sample" (func $wat_sample))
// Include file list
// $PROJECT_ROOT/apb_slave.sv
// $PROJECT_ROOT/example_tb.v
// $PROJECT_ROOT/matmul_with_ram_tb.sv
$PROJECT_ROOT/matmul.sv
$PROJECT_ROOT/matmul_tb.sv
// $PROJECT_ROOT/matmul_8x8.sv

// FP8
// + ADD
$PROJECT_ROOT/FP8/fp8_add/fp8_add_prealign.sv
$PROJECT_ROOT/FP8/fp8_add/fp8_add_align.sv
$PROJECT_ROOT/FP8/fp8_add/fp8_add_shift.sv
$PROJECT_ROOT/FP8/fp8_add/fp8_add_execute.sv
$PROJECT_ROOT/FP8/fp8_add/fp8_add_normalize.sv
$PROJECT_ROOT/FP8/fp8_add/fp8_add_round.sv
$PROJECT_ROOT/FP8/fp8_add/fp8_add_exception.sv
$PROJECT_ROOT/FP8/fp8_add/fp8_add.sv
// $PROJECT_ROOT/FP8/fp8_add/tb_fp8_add.sv
// x MUL
$PROJECT_ROOT/FP8/fp8_mul/fp8_mul_prep.sv
$PROJECT_ROOT/FP8/fp8_mul/fp8_mul_execute.sv
$PROJECT_ROOT/FP8/fp8_mul/fp8_mul_round.sv
$PROJECT_ROOT/FP8/fp8_mul/fp8_mul.sv
// $PROJECT_ROOT/FP8/fp8_mul/tb_fp8_mul.sv

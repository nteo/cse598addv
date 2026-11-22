.text
addi $t0, $zero, 1
addi $t1, $zero, 1
add $t2, $t0, $t1
add $t3, $t2, $t1
add $t4, $t3, $t2
add $t5, $t4, $t3
add $t6, $t5, $t4
sub $t7, $t6, $t5
and $t0, $t6, $t7
or $t1, $t0, $t2
slt $t2, $t1, $t6
sw $t6, 8($zero)
sw $t2, 12($zero)
addi $t9, $zero, 3565
sw $t9, 64($zero)
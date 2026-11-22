.text
addi $t0, $zero, 0
addi $t1, $zero, 5
sw $t1, 0($t0)
lw $t2, 0($t0)
add $t2, $t1, $t2
addi $t0, $t0, 4
sw $t2, 0($t0)
lw $t3, 0($t0)
add $t3, $t3, $t2
addi $t0, $t0, 4
sw $t3, 0($t0)
lw $t4, 0($t0)
add $t5, $t4, $t2
sw $t5, 12($zero)
lw $t6, 12($zero)
beq $t6, $t5, equal
addi $t7, $zero, 99
equal:
addi $t7, $zero, 7
addi $t9, $zero, 3565
sw $t9, 64($zero)
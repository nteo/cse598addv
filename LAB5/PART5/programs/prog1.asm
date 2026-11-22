.text
addi $t0, $zero, 4
addi $t1, $zero, 12
addi $t2, $zero, 0
addi $t3, $zero, 0
loop:
slt $t4, $t3, $t0
beq $t4, $zero, done
add $t2, $t2, $t1
addi $t3, $t3, 1
beq $zero, $zero, loop
done:
sw $t2, 0($zero)
addi $t9, $zero, 3565
sw $t9, 64($zero)
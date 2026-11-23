
import re
import sys

# Opcode map for instruction encoding
opcode_map = {
    'add': '000000', 'sub': '000000', 'subu': '000000', 'addu': '000000', 'and': '000000',
    'or': '000000', 'slt': '000000', 'sll': '000000', 'srl': '000000', 'jr': '000000',
    'xor': '000000', 'nor': '000000', 'move': '000000', 'nop': '000000', 'break': '000000',
    'syscall': '000000', 'lw': '100011', 'sw': '101011', 'beq': '000100', 'bne': '000101',
    'addi': '001000', 'slti': '001010', 'andi': '001100', 'ori': '001101', 'xori': '001110',
    'j': '000010', 'jal': '000011'
}

# Function code map for R-type instructions
funct_map = {
    'add': '100000',      # Addition
    'addu': '100001',     # Addition Unsigned
    'sub': '100010',      # Subtraction
    'subu': '100011',     # Subtraction Unsigned
    'mul': '011000',     # Multiply (stores result in hi/lo)
    'mult': '011001',    # Multiply Unsigned (stores result in hi/lo)
    'and': '100100',      # Bitwise AND
    'or': '100101',       # Bitwise OR
    'xor': '100110',      # Bitwise XOR
    'nor': '100111',      # Bitwise NOR
    'slt': '101010',      # Set on Less Than
    'sltu': '101011',     # Set on Less Than Unsigned
    'sll': '000000',      # Shift Left Logical
    'srl': '000010',      # Shift Right Logical
    'sra': '000011',      # Shift Right Arithmetic
    'jr': '001000',       # Jump Register
    'mfhi': '010000',     # Move from HI register
    'mflo': '010010',     # Move from LO register
    'mthi': '010001',     # Move to HI register
    'mtlo': '010011',     # Move to LO register
    'syscall': '001100',  # System call
    'break': '001101'     # Break
}


register_map = {
    '$zero': '00000', '$at': '00001', '$v0': '00010', '$v1': '00011',
    '$a0': '00100', '$a1': '00101', '$a2': '00110', '$a3': '00111',
    '$t0': '01000', '$t1': '01001', '$t2': '01010', '$t3': '01011',
    '$t4': '01100', '$t5': '01101', '$t6': '01110', '$t7': '01111',
    '$s0': '10000', '$s1': '10001', '$s2': '10010', '$s3': '10011',
    '$s4': '10100', '$s5': '10101', '$s6': '10110', '$s7': '10111',
    '$t8': '11000', '$t9': '11001', '$k0': '11010', '$k1': '11011',
    '$gp': '11100', '$sp': '11101', '$fp': '11110', '$ra': '11111'
}

# Memory map to store data section label addresses
memory_map = {}
memory = {}  # Stores actual memory values

# Label map to store addresses of labels in the text section
label_map = {}

# To keep track of the next available memory address
current_data_address = 0x10010000  # Typical start of the data segment
current_instruction_address = 0x00400000  # Typical start of the text segment

def parse_data_section(line):
    """Parse .data section to map variables and strings to addresses."""
    global current_data_address
    if ':' in line:
        label, declaration = line.split(':', 1)
        label = label.strip()
        declaration = declaration.strip()

        if '.word' in declaration:
            # Extract integer values after .word and store them in memory
            values = declaration.replace('.word', '').strip().split(',')
            word_values = [int(value.strip()) for value in values]  # Convert each value to an integer
            memory_map[label] = current_data_address  # Store the starting address of the label

            # Store each word value in memory at consecutive addresses (4 bytes per word)
            for value in word_values:
                memory[current_data_address] = value
                current_data_address += 4  # Move to the next word (4 bytes)

        elif '.asciiz' in declaration:
            # Extract the string from the .asciiz declaration
            string = re.search(r'"(.*?)"', declaration).group(1)
            memory_map[label] = current_data_address  # Store the starting address of the label

            # Store each character of the string in memory (1 byte per character)
            for char in string:
                memory[current_data_address] = ord(char)  # Store ASCII value of the character
                current_data_address += 1

            # Add null terminator for the string (0x00)
            memory[current_data_address] = 0
            current_data_address += 1

def parse_r_type(instruction):
    """Parse R-type instructions, including special case for 'jr'."""
    opcode = '000000'  # R-type instructions always have an opcode of 0
    parts = instruction.replace(',', '').split()
    operation = parts[0]

    if operation == 'jr':
        # For 'jr', only rs is used, and rd and rt are set to 00000
        rs = parts[1]
        rd = '00000'  # Not used in 'jr'
        rt = '00000'  # Not used in 'jr'
        shamt = '00000'  # Shift amount is 0 for 'jr'
        funct = '001000'  # Function code for 'jr'
        return opcode + register_map[rs] + rt + rd + shamt + funct
    elif operation == 'nop':
        # For 'nop', it is represented as sll $0, $0, 0
        rd = '00000'  # Not used
        rs = '00000'  # Not used
        rt = '00000'  # Not used
        shamt = '00000'
        funct = '000000'  # Function code for nop (sll $0, $0, 0)
        return opcode + rs + rt + rd + shamt + funct
    
    elif operation == 'move':
        rd = parts[1]  # Destination register
        rs = parts[2]  # Source register
        rt = '$zero'   # Use $zero as the third operand
        shamt = '00000'  # Shift amount is 0
        funct = '100000'  # Function code for 'add'
        
        # Construct the binary representation
        return opcode + register_map[rs] + register_map[rt] + register_map[rd] + shamt + funct


    elif operation == 'break':
        # For 'break', we may not need to do anything special
        rd = '00000'  # Not used
        rs = '00000'  # Not used
        rt = '00000'  # Not used
        shamt = '00000'
        funct = '001101'  # Function code for break
        return opcode + rs + rt + rd + shamt + funct

    elif operation == 'syscall':
        # For 'syscall', we may not need to do anything special
        rd = '00000'  # Not used
        rs = '00000'  # Not used
        rt = '00000'  # Not used
        shamt = '00000'
        funct = '001100'  # Function code for syscall
        return opcode + rs + rt + rd + shamt + funct
    else:
        # For other R-type instructions
        rd, rs, rt = parts[1], parts[2], parts[3]
        shamt = '00000'  # Shift amount is 0 for most R-type instructions
        funct = funct_map[operation]
        if rt.isdigit():  # If rt is a digit (number)
            rt = format(int(rt), '05b')  # Convert to 5-bit binary
        else:
            rt = register_map[rt]

    return opcode + register_map[rs] + rt + register_map[rd] + shamt + funct

def parse_i_type(instruction, current_address):
    """Parse I-type instructions (e.g., lw, sw, addi, beq)."""
    parts = instruction.replace(',', '').split()
    operation = parts[0]
    opcode = opcode_map[operation]

    if operation in ['lw', 'sw']:
        rt = register_map[parts[1]]  # Get the register for rt

        # Check if the third part contains a base register with an offset (like num($t0))
        if '(' in parts[2]:
            offset, rs = parts[2].split('(')  # Split into offset and base register
            rs = rs.replace(')', '').strip()  # Remove the closing parenthesis and trim spaces
            offset = offset.strip()  # Remove any leading/trailing whitespace
            if not offset:  # If offset is empty
                offset = '0'
            offset_bin = format(int(offset), '016b')  # Convert offset to a 16-bit binary
            return opcode + register_map[rs] + rt + offset_bin

        else:
            # Handle the case where the instruction uses a label directly (like sw $v0, num)
            label = parts[2].strip()  # The label should be the last part of the instruction
            if label in memory_map:  # Check if the label is defined in memory_map
                address = memory_map[label]  # Get the address associated with the label
                offset =current_data_address - address   # Calculate the offset relative to data start
                offset_bin = format(offset, '016b')  # Convert offset to a 16-bit binary
                return opcode + '00000' + rt + offset_bin
            else:
                raise ValueError(f"Undefined label '{label}' in the .data section.")

    elif operation in ['beq', 'bne']:
        rs = register_map[parts[1]]
        rt = register_map[parts[2]]
        label = parts[3]
        if label in label_map:
            # Calculate the branch offset as the difference between target and current instruction address
            offset = (label_map[label] - (current_address + 4)) // 4
            offset_bin = format(offset & 0xFFFF, '016b')  # Ensure a 16-bit binary representation
            return opcode + rs + rt + offset_bin
        else:
            raise ValueError(f"Undefined label '{label}' in the .text section.")

    elif operation in ['addi', 'slti', 'andi', 'ori', 'xori']:
        rt = register_map[parts[1]]
        rs = register_map[parts[2]]
        immediate = format(int(parts[3]), '016b')
        return opcode + rs + rt + immediate

def parse_j_type(instruction):
    """Parse J-type instructions (j, jal)."""
    parts = instruction.split()
    opcode = opcode_map[parts[0]]
    label = parts[1]
    if label in label_map:
        address = label_map[label] // 4
        return opcode + format(address, '026b')
    else:
        raise ValueError(f"Undefined label '{label}' in the .text section.")

def parse_la_instruction(instruction):
    """Parse 'la' instruction to load address into a register."""
    parts = instruction.replace(',', '').split()
    rt = register_map[parts[1]]
    label = parts[2]

    if label in memory_map:
        address = memory_map[label]  # Get the address associated with the label
        offset = current_data_address - address  # Calculate the offset relative to data start
        offset_bin = format(offset, '016b')
        return '001000' + '00000' + rt + offset_bin
    else:
        raise ValueError(f"Undefined label '{label}' in the .data section.")

def parse_li_instruction(instruction):
    """Parse the li (load immediate) instruction."""
    parts = instruction.replace(',', '').split()
    rt = register_map[parts[1]]
    immediate_value = parts[2]

    if immediate_value.isdigit() or (immediate_value.startswith('-') and immediate_value[1:].isdigit()):
        immediate = format(int(immediate_value), '016b')
    else:
        raise ValueError(f"Invalid immediate value '{immediate_value}'.")

    opcode = opcode_map['addi']
    rs = '00000'
    return opcode + rs + rt + immediate

def translate_mips_to_binary(input_file, output_file):
    """Translate MIPS instructions to binary, handling .data and .text sections."""
    global current_instruction_address
    with open(input_file, 'r') as file:
        lines = file.readlines()

    binary_instructions = []
    in_text_section = False

    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        if line.startswith('.data'):
            in_text_section = False
            continue
        elif line.startswith('.text'):
            in_text_section = True
            continue

        if in_text_section:
            if ':' in line:
                label = line.split(':')[0].strip()
                label_map[label] = current_instruction_address
            else:
                current_instruction_address += 4

    current_instruction_address = 0x00400000
    for line in lines:
        line = line.strip()

        if not line or line.startswith('#'):
            continue

        if line.startswith('.data'):
            in_text_section = False
            continue
        elif line.startswith('.text'):
            in_text_section = True
            continue

        if not in_text_section:
            parse_data_section(line)
            continue

        if ':' in line:
            continue

        operation = line.split()[0]
        if operation in funct_map:
            binary_instructions.append(parse_r_type(line))
        elif operation in ['lw', 'sw', 'beq', 'bne', 'addi', 'slti', 'andi', 'ori', 'xori']:
            binary_instructions.append(parse_i_type(line, current_instruction_address))
        elif operation in ['j', 'jal']:
            binary_instructions.append(parse_j_type(line))
        elif operation == 'la':
            binary_instructions.append(parse_la_instruction(line))
        elif operation == 'li':
            binary_instructions.append(parse_li_instruction(line))

        current_instruction_address += 4

    with open(output_file, 'w') as file:
        for binary_instruction in binary_instructions:
            file.write(binary_instruction + '\n')

    current_instruction_address = 0x00400000


class MIPSProcessor:
    def __init__(self, memory_map, memory, label_map, current_data_address, current_instruction_address):
        self.registers = [0] * 32  # 32 MIPS registers initialized to 0
        self.memory = memory  # Use the memory dictionary from the translation phase
        self.memory_map = memory_map  # Use memory_map for resolving data addresses
        self.label_map = label_map  # Use label_map for resolving jump addresses
        self.current_data_address = current_data_address  # Starting point for data section
        self.pc = current_instruction_address  # Start program counter at the start of the text segment

    def load_instructions(self, binary_file):
        """Load binary instructions from a file into memory."""
        with open(binary_file, 'r') as file:
            lines = file.readlines()

        address = self.pc
        for line in lines:
            line = line.strip()
            if line:
                self.memory[address] = line
                address += 4

    def get_register_name(self, reg_code):
        """Convert a 5-bit register code into its corresponding register name."""
        register_names = {v: k for k, v in register_map.items()}
        return register_names.get(reg_code, f'${int(reg_code, 2)}')

    def get_register(self, reg_code):
        """Convert a 5-bit register code into the corresponding register index."""
        return int(reg_code, 2)

    def sign_extend(self, value, bits=16):
        """Sign-extend a binary string to a given number of bits."""
        if value[0] == '1':  # Negative number
            return int(value, 2) - (1 << bits)
        else:
            return int(value, 2)

    def decode_instruction(self, instruction):
        """Decode a 32-bit binary MIPS instruction into its MIPS assembly form."""
        opcode = instruction[:6]

        if opcode == '000000':  # R-type instruction
            rs = self.get_register_name(instruction[6:11])
            rt = self.get_register_name(instruction[11:16])
            rd = self.get_register_name(instruction[16:21])
            shamt = int(instruction[21:26], 2)
            funct = instruction[26:]
            funct_names = {v: k for k, v in funct_map.items()}
            operation = funct_names.get(funct, 'unknown')

            if operation == 'sll' or operation == 'srl':
                return f"{operation} {rd}, {rt}, {shamt}"
            elif operation == 'jr':
                return f"{operation} {rs}"
            else:
                return f"{operation} {rd}, {rs}, {rt}"

        elif opcode in ['100011', '101011', '001000', '000100', '000101', '001010', '001100', '001101', '001110']:
            # I-type instructions: lw, sw, addi, beq, bne, slti, andi, ori, xori
            rs = self.get_register_name(instruction[6:11])
            rt = self.get_register_name(instruction[11:16])
            immediate = self.sign_extend(instruction[16:])
            operation = {
                '100011': 'lw', '101011': 'sw', '001000': 'addi',
                '000100': 'beq', '000101': 'bne', '001010': 'slti',
                '001100': 'andi', '001101': 'ori', '001110': 'xori'
            }[opcode]

            if operation in ['lw', 'sw']:
                return f"{operation} {rt}, {immediate}({rs})"
            elif operation in ['beq', 'bne']:
                # Try to resolve the label from the offset
                target_address = self.pc + (immediate * 4)
                label = next((k for k, v in self.label_map.items() if v == target_address), hex(target_address))
                return f"{operation} {rs}, {rt}, {label}"
            else:
                return f"{operation} {rt}, {rs}, {immediate}"

        elif opcode in ['000010', '000011']:  # J-type instructions: j, jal
            address = int(instruction[6:], 2) << 2
            operation = 'j' if opcode == '000010' else 'jal'
            label = next((k for k, v in self.label_map.items() if v == address), hex(address))
            return f"{operation} {label}"

        return "unknown instruction"
    
    def run(self, trace_file):
        """Run the MIPS processor and print each instruction in hexadecimal."""
        while self.pc in self.memory:
            instruction = self.memory[self.pc]

            # Convert 32-bit binary instruction to 8-digit hexadecimal.
            instruction_hex = format(int(instruction, 2), '08X')

            output = f"Executing at {hex(self.pc)}: {instruction_hex}"
            print(output)
            trace_file.write(output + '\n')

            self.pc += 4
            self.execute_instruction(instruction)

            self.print_registers(trace_file)

    def execute_instruction(self, instruction):
        """Decode and execute a 32-bit binary MIPS instruction."""
        opcode = instruction[:6]

        if opcode == '000000':  # R-type instruction
            rs = self.get_register(instruction[6:11])
            rt = self.get_register(instruction[11:16])
            rd = self.get_register(instruction[16:21])
            shamt = int(instruction[21:26], 2)
            funct = instruction[26:]

            self.execute_r_type(rs, rt, rd, shamt, funct)

        elif opcode in ['100011', '101011', '001000', '000100', '000101', '001010', '001100', '001101', '001110']:
            # I-type instructions: lw, sw, addi, beq, bne, slti, andi, ori, xori
            rs = self.get_register(instruction[6:11])
            rt = self.get_register(instruction[11:16])
            immediate = self.sign_extend(instruction[16:])

            self.execute_i_type(opcode, rs, rt, immediate)

        elif opcode in ['000010', '000011']:  # J-type instructions: j, jal
            address = int(instruction[6:], 2)
            self.execute_j_type(opcode, address)

    def execute_r_type(self, rs, rt, rd, shamt, funct):
        """Execute an R-type instruction."""
        if funct == '100000':  # add
            self.registers[rd] = self.registers[rs] + self.registers[rt]
        elif funct == '100010':  # sub
            self.registers[rd] = self.registers[rs] - self.registers[rt]
        elif funct == '100100':  # and
            self.registers[rd] = self.registers[rs] & self.registers[rt]
        elif funct == '100101':  # or
            self.registers[rd] = self.registers[rs] | self.registers[rt]
        elif funct == '101010':  # slt
            self.registers[rd] = 1 if self.registers[rs] < self.registers[rt] else 0
        elif funct == '000000' and shamt != 0:  # sll
            self.registers[rd] = self.registers[rt] << shamt
        elif funct == '011000':  # mul (multiply)
            self.registers[rd] = self.registers[rs] * self.registers[rt]
        elif funct == '000010':  # srl
            self.registers[rd] = self.registers[rt] >> shamt
        elif funct == '001000':  # jr
            self.pc = self.registers[rs]

    def execute_i_type(self, opcode, rs, rt, immediate):
        """Execute an I-type instruction."""
        if opcode == '100011':  # lw
            address = self.registers[rs] + immediate  # Calculate effective address
            self.registers[rt] = self.memory.get(address, 0)  # Load from memory
        elif opcode == '101011':  # sw
            address = self.registers[rs] + immediate  # Calculate effective address
            self.memory[address] = self.registers[rt]  # Store to memory
        elif opcode == '001000':  # addi
            self.registers[rt] = self.registers[rs] + immediate
        elif opcode == '000100':  # beq
            if self.registers[rs] == self.registers[rt]:
                self.pc += immediate * 4
        elif opcode == '000101':  # bne
            if self.registers[rs] != self.registers[rt]:
                self.pc += immediate * 4
        elif opcode == '001010':  # slti
            self.registers[rt] = 1 if self.registers[rs] < immediate else 0
        elif opcode == '001100':  # andi
            self.registers[rt] = self.registers[rs] & (immediate & 0xFFFF)
        elif opcode == '001101':  # ori
            self.registers[rt] = self.registers[rs] | (immediate & 0xFFFF)
        elif opcode == '001110':  # xori
            self.registers[rt] = self.registers[rs] ^ (immediate & 0xFFFF)

    def execute_j_type(self, opcode, address):
        """Execute a J-type instruction."""
        if opcode == '000010':  # j
            self.pc = (self.pc & 0xF0000000) | (address << 2)
        elif opcode == '000011':  # jal
            self.registers[31] = self.pc  # Store return address in $ra
            self.pc = (self.pc & 0xF0000000) | (address << 2)
    
    def print_registers(self, trace_file):
        """Print the current state of the registers horizontally."""
        print("Register values:")
        trace_file.write("Register values:\n")

        register_values = []
        for i in range(32):
            reg_name = self.get_register_name(format(i, '05b'))
            register_values.append(f"{reg_name}: {self.registers[i]}")

        output = ' | '.join(register_values)

        print(output)
        trace_file.write(output + '\n')

    def print_memory(self, trace_file):
        """Print the current state of memory."""
        print("Memory values:")
        trace_file.write("Memory values:\n")
        for address, value in sorted(self.memory.items()):
            output = f"{hex(address)}: {value}"
            print(output)
            trace_file.write(output + '\n')


if __name__ == "__main__":
    input_file = sys.argv[1] if len(sys.argv) > 1 else 'input.txt'
    output_file = sys.argv[2] if len(sys.argv) > 2 else 'output.txt'
    trace_file_name = sys.argv[3] if len(sys.argv) > 3 else 'iss_trace.txt'

    translate_mips_to_binary(input_file, output_file)

    # Write memory metadata for the RTL testbench.
    with open("iss_metadata.txt", "w") as metadata_file:
        metadata_file.write(f"Memory Map: {memory_map}\n")
        metadata_file.write(f"Label Map: {label_map}\n")
        metadata_file.write(f"Memory: {memory}\n")

    with open(trace_file_name, 'w') as trace_file:
        #output = "Translation complete. Binary instructions written to traces/prog1.bin."
        #print(output)
        #trace_file.write(output)
        
        output = f"Memory Map: {memory_map}"
        print(output)
        trace_file.write(output)

        output = f"Label Map: {label_map}"
        print(output)
        trace_file.write(output)

        output = f"Memory: {memory}"
        print(output)
        trace_file.write(output)

        processor = MIPSProcessor(
            memory_map, memory, label_map,
            current_data_address, current_instruction_address
        )

        processor.load_instructions(output_file)

        processor.run(trace_file)
        processor.print_memory(trace_file)


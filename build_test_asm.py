import itertools
import random
import subprocess
import tempfile
import os
import re
import sys

OP = {"add", "sub", "and", "or", "xor", "sll", "srl", "sra", "slt", "sltu"}
OP_IMM = {"addi", "andi", "ori", "xori", "slli", "srli", "srai", "slti", "sltiu", "nop"}
LOAD = {"lb", "lh", "lw", "lbu", "lhu"}
STORE = {"sb", "sh", "sw"}
BRANCH = {"beq", "bne", "blt", "bge", "bltu", "bgeu"}
LUI_AUIPC = {"lui", "auipc"}
JUMP = {"jal", "jalr"}
MISC = {"fence", "ecall", "ebreak"}

instruction_names = [*OP, *OP_IMM, *LOAD, *STORE, *BRANCH, *LUI_AUIPC, *JUMP, *MISC]

cmp_ops = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}

R_TYPE = 0
I_TYPE = 1
S_TYPE = 2
B_TYPE = 3
U_TYPE = 4
J_TYPE = 5

# nop fill so jump and branch targets are valid
FILL = 1048576

def inst_fmt(inst_name):
    if inst_name in OP:
        return R_TYPE
    if inst_name in {*OP_IMM, *LOAD, *MISC, "jalr"}:
        return I_TYPE
    if inst_name in STORE:
        return S_TYPE
    if inst_name in BRANCH:
        return B_TYPE
    if inst_name in LUI_AUIPC:
        return U_TYPE
    #if inst_name == "jal":
    return J_TYPE

def imm_size(inst_type):
    if inst_type == R_TYPE:
        return 0
    if inst_type in (I_TYPE, S_TYPE):
        return 12
    if inst_type == B_TYPE:
        return 13
    if inst_type == U_TYPE:
        return 20
    #if inst_type == J_TYPE:
    return 21

def build_inst(inst_name, rd, rs1, rs2, imm, decode_outputs=False):
    """
    Build a RISC-V assembly instruction string from operand components.

    This helper is intended for generating instruction test cases for a RISC-V
    implementation. Instruction format is determined from the name. Unused
    arguments can be set to None. The expected immediate output and
    decoder signals can also be returned for decoder testing.

    Parameters
    ----------
    inst_name : str
        The RISC-V instruction mnemonic (e.g. "add", "sub", "lw", "beq").
    rd : int or None
        Destination register index.
    rs1 : int or None
        First source register index.
    rs2 : int or None
        Second source register index.
    imm : int or None
        Immediate value baseline. Use None for a random value.
        This should be a positive number. The actual immediate value is
        determined by right-shifting this number into the appropriate range;
        it is then negated based on a 2's complement interpretation,
        where appropriate.
    decode_outputs : bool, optional
        If True, also returns a tuple of the expected immediate value and
        expected decode output signals. Default is False.

    Returns
    -------
    str or tuple
        If `decode_outputs` is False, returns the RISC-V assembly instruction
        as a string. If `decode_outputs` is True, returns a tuple:
        (instruction_str, (imm_value, *decode_outputs)).

    Examples
    --------
    >>> build_inst("add", 1, 2, 3, None)
    'add x1, x2, x3'

    >>> build_inst("addi", 5, 0, None, 12)
    'addi x5, x0, 12'

    >>> build_inst("beq", None, 1, 2, 16, decode_outputs=True)
    ('beq x1, x2, 16', (16, B_TYPE, ...))
    """

    inst_type = inst_fmt(inst_name)
    isize = imm_size(inst_type)
    if imm is None:
        imm = random.randrange(2**isize)
    while imm >= 2**isize:
        imm >>= 1
    if inst_name == "jal" or inst_name in BRANCH:
        imm &= 0xfffffffe
    if inst_name in {"sll", "srl", "sra", "slli", "srli", "srai"}:
        imm %= 32
    if imm >= 2**(isize-1) and inst_name not in LUI_AUIPC:
        imm -= 2**isize

    args = f"x{rd}"
    if inst_name in LOAD:
        args += f", {imm}(x{rs1})"
        rs2 = None
    elif inst_name in STORE:
        args = f"x{rs2}, {imm}(x{rs1})"
        rd = None
    elif inst_name == "jal":
        args += f", .{imm:+d}"
        rs1 = None
        rs2 = None
    elif inst_name in LUI_AUIPC:
        args += f", {imm}"
        rs1 = None
        rs2 = None
        imm <<= 12
        if imm >= 2**31: imm -= 2**32
    elif inst_type == R_TYPE:
        args += f", x{rs1}, x{rs2}"
        imm = None
    elif inst_name in {"nop", *MISC}:
        args = ""
        rd = 0
        rs1 = None
        rs2 = None
        imm = None
    elif inst_name in BRANCH:
        args = f"x{rs1}, x{rs2}, .{imm:+d}"
        rd = None
    else:
        args += f", x{rs1}, {imm}"
        rs2 = None
    inst = f"{inst_name} {args}"
    if not decode_outputs:
        return inst
    branch = inst_name in BRANCH
    jump = inst_name in JUMP
    compare = inst_name.startswith("slt")
    cmp_imm = compare and inst_name in OP_IMM
    if not compare and inst_name not in BRANCH:
        cmp_imm = None
    if compare:
        cmp_op = cmp_ops["bltu"] if inst_name.endswith('u') else cmp_ops["blt"]
    elif branch:
        cmp_op = cmp_ops[inst_name]
    else:
        cmp_op = None
    alu_imm = inst_type != R_TYPE
    alu_pc = inst_name in {"auipc", "jal", *BRANCH}
    if inst_name in {"add", "addi", *LOAD, *STORE, *BRANCH, *LUI_AUIPC, *JUMP}:
        alu_op = 0
    else: # assume other OP, OP_IMM alu_op are done correctly
        alu_op = None
    mem_read = inst_name in LOAD
    mem_write = inst_name in STORE
    if inst_name in {*LOAD, *STORE}:
        mem_size = "bhw".index(inst_name[1])
        mem_unsigned = inst_name.endswith('u')
    else:
        mem_size = None
        mem_unsigned = None
    if inst_name in {"nop", *MISC}:
        compare = cmp_imm = alu_imm = alu_pc = mem_read = None
    elif inst_name == "srai": # funct7 overlaps with imm for shift immediates
        imm += 1024
    return inst, (imm, inst_type, rs1, rs2, rd, branch, jump, compare, cmp_imm, cmp_op, alu_imm, alu_pc, alu_op, mem_read, mem_write, mem_size, mem_unsigned)

def assemble_riscv(asm_code: str, output_bin: str, march="rv32e", mabi="ilp32e"):
    """Compile RISC-V assembly string to a raw binary file."""
    with tempfile.TemporaryDirectory() as tmpdir:
        asm_file = os.path.join(tmpdir, "prog.s")
        elf_file = os.path.join(tmpdir, "prog.elf")

        # Write the assembly string to a file
        with open(asm_file, "w") as f:
            f.write(asm_code)

        # Assemble + link using RISC-V GCC
        subprocess.run([
            "riscv-none-elf-gcc",
            f"-march={march}",
            f"-mabi={mabi}",
            "-nostdlib",
            "-o", elf_file,
            asm_file
        ], check=True)

        # Convert ELF to raw binary
        subprocess.run([
            "riscv-none-elf-objcopy",
            "-O", "binary",
            elf_file,
            output_bin
        ], check=True)

        # Remove nop filler instructions
        with open(output_bin, "rb") as f:
            bytes = f.read()
        with open(output_bin, "wb") as f:
            f.write(bytes[FILL*4:-FILL*4])

def run_testbench(tb_module: str, instr_bin: str, *dut_files) -> str:
    """Compile and run a SystemVerilog testbench in ModelSim, return stdout as string."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create ModelSim library
        subprocess.run(["vlib", os.path.join(tmpdir, "work")], cwd=tmpdir, check=True)

        # Copy the testbench and instruction binary
        tb_path = os.path.join(tmpdir, f"{tb_module}.sv")
        with open(tb_path, "w") as f:
            f.write(open(f"{tb_module}.sv").read())

        paths = []
        for filename in [instr_bin, *dut_files]:
            file_path = os.path.join(tmpdir, filename)
            subprocess.run(["cp", filename, file_path], check=True)
            if filename in dut_files:
                paths.append(file_path)

        # Compile SystemVerilog files
        subprocess.run([
            "vlog",
            "-sv",
            *paths,
            tb_path
        ], cwd=tmpdir, check=True)

        # Run simulation in batch mode
        result = subprocess.run([
            "vsim",
            "-c",
            "-do",
            "run -all; quit",
            f"work.{tb_module}",
        ], cwd=tmpdir, capture_output=True, text=True, check=True)
        return result.stdout

def main(bin_file, instructions):
    instructions[:] = [".section .text", ".globl _start", "_start:"]+["nop"]*FILL
    expected_outputs = []

    regs2test = [0, 1, 2, 4, 8, 15]
    for inst_name in instruction_names:
        for imm in [0x80000000, 0, 1, 0x7fffffff, 0xffffffff, *random.choices(range(2**32), k=3)]:
            for rs1, rs2, rd in itertools.product(regs2test, repeat=3):
                inst, outputs = build_inst(inst_name, rs1=rs1, rs2=rs2, rd=rd, imm=imm, decode_outputs=True)
                instructions.append(inst)
                expected_outputs.append(outputs)
    instructions.extend(["nop"]*FILL)

    try:
        assemble_riscv("\n".join(instructions), bin_file)
    except:
        return 1
    instructions[:] = instructions[FILL+3:-FILL]
    output = run_testbench("tb_decode", bin_file, "types.sv", "instruction_decoder.sv", "immediate_builder.sv")

    output_names = ("imm", "inst_type", "rs1", "rs2", "rd", "branch", "jump", "compare", "cmp_imm", "cmp_op", "alu_imm", "alu_pc", "alu_op", "mem_read", "mem_write", "mem_size", "mem_unsigned")
    for i, outputs in enumerate(re.findall(r"^#?\s*([0-9a-f]+\s+(?:(?:[xX]|\-?\d+)\s+)+(?:[xX]|\d+))$", output, re.MULTILINE)):
        outputs = outputs.split()
        for j, output in enumerate(expected_outputs[i]):
            if output is not None and str(int(output)) != outputs[j+1]:
                print(f"{outputs[0]} ({i}): {output_names[j]}={outputs[j+1]}, expected {int(output)}")
                return 2
    return 0

if __name__ == "__main__":
    bin_file = "instructions.bin"
    instructions = []
    exit_code = main(bin_file, instructions)
    if exit_code != 0:
        with open("tb_decode.s", 'w') as f:
            f.write("\n".join(instructions))
    else:
        subprocess.run(["rm", bin_file])
    sys.exit(exit_code)

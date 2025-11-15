import itertools
import operator as op
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

def signed(x, bits=32):
    x = x & ((1 << bits) - 1)
    return x if x < 2**(bits-1) else x - 2**bits

def unsigned(x, bits=32):
    x = x & ((1 << bits) - 1)
    return x if x >= 0 else x + 2**bits

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

def build_inst(inst_name, rd=None, rs1=None, rs2=None, imm=None, decode_outputs=False):
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
    try:
        while imm >= 2**isize:
            imm >>= 1
        if inst_name == "jal" or inst_name in BRANCH:
            imm &= 0xfffffffe
        if inst_name in {"sll", "srl", "sra", "slli", "srli", "srai"}:
            imm %= 32
        if imm >= 2**(isize-1) and inst_name not in LUI_AUIPC:
            imm -= 2**isize
    except TypeError: # imm is a string (label)
        pass

    args = f"x{rd}"
    if inst_name in LOAD:
        args += f", {imm}(x{rs1})"
        rs2 = None
    elif inst_name in STORE:
        args = f"x{rs2}, {imm}(x{rs1})"
        rd = None
    elif inst_name == "jal":
        if isinstance(imm, str):
            args += f", .{imm}"
        else:
            args += f", .{imm:+d}"
        rs1 = None
        rs2 = None
    elif inst_name in LUI_AUIPC:
        args += f", {imm}"
        rs1 = None
        rs2 = None
        if not isinstance(imm, str):
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
        if isinstance(imm, str):
            args = f"x{rs1}, x{rs2}, .{imm}"
        else:
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

def lui_offset(rd, imm):
    ui_bits = (imm + 0x800) >> 12
    offset = imm & 0xfff
    if offset >= 0x800:
        offset -= 0x1000
    return build_inst("lui", rd, imm=(ui_bits % 2**20)), offset

def li32(rd, imm):
    """Create lui + addi instructions to load a 32-bit value into a register"""
    lui, offset = lui_offset(rd, imm)
    return [lui, build_inst("addi", rd, rd, imm=offset)]

def ls32(inst_name, rd_rs, addr, rs1=5, label=None):
    if inst_name in LOAD:
        rd = rd_rs
        rs = None
    else:
        rd = None
        rs = rd_rs
    lui, offset = lui_offset(rs1, addr)
    if label:
        lui = f"{label}: " + lui
    return [lui, build_inst(inst_name, rd, rs1, rs2=rs, imm=offset)]

func = {
    "add":  op.add,
    "sub":  op.sub,
    "and":  op.and_,
    "or":   op.or_,
    "xor":  op.xor,
    "sll":  lambda x, y: x << (y & 0x1f),
    "srl":  lambda x, y: unsigned(x) >> (y & 0x1f),
    "sra":  lambda x, y: signed(x) >> (y & 0x1f),
    "slt":  lambda x, y: signed(x) < signed(y),
    "sltu": lambda x, y: unsigned(x) < unsigned(y),
    "beq":  lambda x, y: unsigned(x) == unsigned(y),
    "bne":  lambda x, y: unsigned(x) != unsigned(y),
    "blt":  lambda x, y: signed(x) < signed(y),
    "bge":  lambda x, y: signed(x) >= signed(y),
    "bltu": lambda x, y: unsigned(x) < unsigned(y),
    "bgeu": lambda x, y: unsigned(x) >= unsigned(y)
}

class InstructionTest(object):
    def __init__(self, inst_name, rd, rs1, rs2, v1, v2, out_addr,
                 fill1=[], fill2=[], forward=False, make_loop=False):
        """
        Create an object to help test the given instruciton.

        Calling `self.test_sequence()` on the resulting object will create a
        sequence of instructions to test the given instruction using the given
        values and registers.

        Parameters
        ----------
        inst_name : str
            The RISC-V instruction mnemonic (e.g. "add", "sub", "lw", "beq").
        rd : int
            Destination register index.
        rs1 : int
            First source register index.
        rs2 : int
            Second source register index.
        v1 : int or None
            Effective value loaded into rs1. For load/store instructions,
            v1 is an address above 0xfffff. Use None for a random value.
        v2 : int or None
            Value loaded into rs2. For immediate ops, v2 is used as an
            immediate baseline. Use None for a random value.
        out_addr : int
            Address to store the final result.
        fill1 : list[str] or InstructionTest, optional
            Filler instructions placed after rs1 is loaded before the
            target instruction. For branches, this should be an
            InstructionTest object representing a test sequence for the taken
            branch. Set forward to True for forward branches.
        fill2 : list[str] or InstructionTest, optional
            Filler instructions placed after the target instruction 
            before the final load to out_addr. For branches, this should be an
            InstructionTest object representing a test sequence for the not
            taken branch. fill1 and fill2 should both have the same rd.
            The branch offset is computed based on the sizes of fill1 and fill2.
            For jumps, fill2 is an InstructionTest representing a function body;
            If its test sequence is already generated, then it should contain
            a matching return jump; otherwise, one will be added. If fill2 is
            a list, then it will be placed after the jump instruction and the
            jump instruction will jump past it.
        forward : bool, optional
            Forward branch. Place fill1 after fill2 in this case.
            Default is False.
        make_loop : bool, optional
            If True, add an extra add instruction to fill1 to make a for loop.
            If False, it is assumed fill1 includes all needed instructions.
            The number of total loops should be `abs(v1-v2)` (at least 1).
            It is assumed the branch condition is true for the initial values.
            Default is False.
        """

        if v1 is None:
            v1 = random.randrange(2**32)
        if v2 is None:
            v2 = random.randrange(2**32)
        self.inst_name = inst_name
        self.rd, self.rs1, self.rs2 = rd, rs1, None if inst_name in OP_IMM else rs2
        self.v1, self.v2 = v1, v2
        self.out_addr = out_addr
        self.lui1, self.offset1 = lui_offset(rs1, v1)
        if inst_name in {*LOAD, *STORE}:
            imm = self.offset1
        elif inst_name in BRANCH:
            imm = f"b{out_addr}"
        elif inst_name in JUMP:
            try:
                jlabel = f"l{fill2.out_addr}"
                fill2 += "ret"
                fill2 = []
            except AttributeError:
                jlabel = f"l{self.out_addr}_end"
            # To avoid "dangerous relocation" and "relocation truncated to fit",
            # use call pseudo-op and let GCC generate jal or auipc + jalr
            self.target_inst = f"call .{jlabel}"
            self.imm = jlabel
        else: # OP, OP_IMM, MISC
            imm = v2
        if make_loop:
            if inst_name == "bne":
                rs = rs2 if unsigned(v1) > unsigned(v2) else rs1
            elif inst_name in ("bge", "bgeu"):
                rs = rs2
            else: # blt, bltu
                rs = rs1
            fill1 += build_inst("addi", rs, rs, imm=1)
        if not getattr(self, "target_inst", False):
            self.target_inst, do = build_inst(inst_name, rd, rs1, rs2, imm=imm, decode_outputs=True)
            self.decode_outputs = do
            self.imm = do[0]
        self.fill1 = fill1
        self.fill2 = fill2
        self.forward = forward
        self.extra = []

    def test_sequence(self, store_out=True):
        """
        Create an instruction sequence to test this instruction.

        Parameters
        ----------
        store_out : bool, optional
            Include a final instruction to store rd to out_addr.
            This also determines if an initial label is added.
            Default is True.

        Returns
        -------
        instructions, expected : list[str], int
            Sequence of instructions and expected output
        """

        inst_name, rd, rs1, rs2 = self.inst_name, self.rd, self.rs1, self.rs2
        v1, v2, imm = self.v1, self.v2, self.imm
        fill1, fill2 = self.fill1, self.fill2
        if self.inst_name in {*LOAD, *STORE}:
            waddr = (v1 >> 2) << 2
            offset = v1 - waddr
            bits = {'b': 8, 'h': 16, 'w': 32}[inst_name[1]]
            instructions = ls32("sw", 0, waddr)
        else:
            instructions = []
        sw = lw = []
        addi1 = ""
        expected = 0
        if inst_name in LOAD:
            sw = ls32("sw", rs2, waddr, rs1)
            if inst_name.endswith('u'):
                expected = unsigned(v2 << (offset*8), bits)
            else:
                expected = signed(v2 << (offset*8), bits)
            if not rs2:
                expected = 0
        elif inst_name in STORE:
            lw = ls32("lw", rd, waddr, rs1)
            expected = unsigned(v2, bits) << (offset*8) if rs2 else 0
        elif inst_name in {*OP, *OP_IMM} - {"nop"}:
            addi1 = build_inst("addi", rs1, rs1, imm=self.offset1)
            if rd:
                if rs1 == 0:
                    v1 = 0
                if rs2 == 0:
                    v2 = 0
                if rs1 == rs2:
                    v2 = v1
                expected = signed(int(func[inst_name.replace('i', "")](v1, v2 if rs2 is not None else imm)))
        elif inst_name in BRANCH:
            if rd is None:
                rd = fill2.rd
            fill1, expected1 = fill1.test_sequence(store_out=False)
            fill2, expected2 = fill2.test_sequence(store_out=False)
            fill1[0] = f".b{self.out_addr}: " + fill1[0]
            if self.forward:
                # place fill1 after fill2, where lw would normally go
                fill1, lw = [], fill1
                fill2.append(build_inst("beq", 0, 0, 0, f"l{self.out_addr}_end"))
                expected = expected1 if func[inst_name](v1, v2) else expected2
            else:
                expected = expected2
        elif inst_name in JUMP:
            rs = rs2 if rs2 else rs1
            self.extra.append(f"la x{rs}, .j{self.out_addr}")
            self.extra.append(build_inst("sub", rd=rd, rs1=rd, rs2=rs))
            if fill2:
                fill2[0] = f".j{self.out_addr}: " + fill2[0]
            else:
                self.extra[0] = f".j{self.out_addr}: " + self.extra[0]
            expected = 0
        else: # MISC
            expected = 0
        instructions += [*(li32(rs2, v2) if rs2 else []), *sw, self.lui1, addi1, *fill1, self.target_inst, *fill2, *lw]
        instructions += self.extra
        if store_out:
            instructions.extend(ls32("sw", rd, self.out_addr, label=f".l{self.out_addr}_end"))
            instructions[0] = f".l{self.out_addr}: " + instructions[0]
        elif inst_name in BRANCH:
            instructions.append(f".l{self.out_addr}_end: nop")
        # omit "" from instructions
        return [i for i in instructions if i], signed(expected) if rd else 0

    def __iadd__(self, inst):
        self.extra.append(inst)
        return self

    def __iter__(self):
        return iter(self.test_sequence(store_out=False)[0])

    def __len__(self):
        return len(self.test_sequence(store_out=False)[0])

    def __repr__(self):
        return f"InstructionTest({self.inst_name}, {self.rd}, {self.rs1}, {self.rs2}, {self.v1}, {self.v2}, {self.out_addr}, " \
               f"{self.fill1}, {self.fill2}, {self.forward})"

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

def test_decode(bin_file, instructions, expected_outputs):
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

def main(bin_file, instructions, test_decode=True, test_core=False):
    global FILL
    instructions[:] = [".section .text", ".globl _start", "_start:"]+["nop"]*FILL
    tests = []
    fillers = []
    expected_outputs = []

    test_vals = [0x80000000, 0, 1, 0x7fffffff, 0xffffffff, None]
    regs2test = [0, 2, 4, 15]
    bregs = [7, 9, 11]
    ra, rdb = 1, 3

    for inst_name in instruction_names:
        for v1, v2 in itertools.product(test_vals, repeat=2):
            for rs1, rs2, rd in itertools.product(regs2test, repeat=3):
                inst, outputs = build_inst(inst_name, rs1=rs1, rs2=rs2, rd=rd, imm=v2, decode_outputs=True)
                instructions.append(inst)
                expected_outputs.append(outputs)
                if inst_name in {*BRANCH, *LUI_AUIPC, *JUMP}:
                    continue
                elif inst_name in {*LOAD, *STORE}:
                    if v1 is None:
                        v1 = random.randrange(2**32)
                    v1 |= 0x100000
                    if inst_name[1] == 'h':
                        v1 = (v1 >> 1) << 1
                    elif inst_name[1] == 'w':
                        v1 = (v1 >> 2) << 2
                    if not rs1 or rs1 == rs2:
                        rs1 = random.choice(list(set(regs2test) - {0, rs2}))
                # else
                tests.append(InstructionTest(inst_name, rs1=rs1, rs2=rs2, rd=rd, v1=v1, v2=v2, out_addr=4*(len(tests)+1)))
                fillers.append(InstructionTest(inst_name, rs1=rs1, rs2=rs2, rd=rdb, v1=v1, v2=v2, out_addr=4*(len(tests)+1)))

    instructions.extend(["nop"]*FILL)

    if test_decode:
        exit_code = test_decode(bin_file, instructions, expected_outputs)
        if exit_code != 0:
            return exit_code

    FILL = 1
    instructions[:] = [".section .text", ".globl _start", "_start:", "nop"]
    expected_outputs = {}

    inst_pool = [t.target_inst for t in tests if t.inst_name not in {*LOAD, *STORE}]
    for filler in fillers:
        filler.extra.extend(random.choices(inst_pool, k=3))

    for inst_name in BRANCH:
        for v1, v2 in itertools.product(test_vals, repeat=2):
            for rs1, rs2 in itertools.product(bregs, repeat=2):
                fill1 = random.choice(fillers)
                fill2 = random.choice(fillers)
                tests.append(InstructionTest(inst_name, rs1=rs1, rs2=rs2, rd=rdb, v1=v1, v2=v2, out_addr=4*(len(tests)+1),
                                             fill1=fill1, fill2=fill2, make_loop=True))
                tests.append(InstructionTest(inst_name, rs1=rs1, rs2=rs2, rd=rdb, v1=v1, v2=v2, out_addr=4*(len(tests)+1),
                                             fill1=fill1, fill2=fill2, forward=True))

    for inst_name in JUMP:
        for rs1, rs2 in itertools.product(set(regs2test + bregs)-{0}, repeat=2):
            fill1 = random.choice(fillers)
            idx2 = random.randrange(len(fillers))
            fill2 = fillers[idx2]
            test = InstructionTest(inst_name, rs1=rs1, rs2=rs2, rd=ra, v1=None, v2=None, out_addr=4*(len(tests)+1),
                                   fill1=fill1, fill2=fill2)
            if inst_name == "jal":
                # place close to function body, so call generates JAL
                idx = max(0, 2*idx2 + random.randrange(-2**12, 2**12))
                tests.insert(idx, test)
            else:
                tests.insert(random.randrange(len(tests)), test)
            tests.append(InstructionTest(inst_name, rs1=rs1, rs2=rs2, rd=ra, v1=None, v2=None, out_addr=4*(len(tests)+1),
                                         fill1=fill1, fill2=list(fill2)))

    sequenced = {}

    for test in tests:
        if test.out_addr not in sequenced:
            test_sequence, output = test.test_sequence()
            instructions.extend(test_sequence)
            expected_outputs[test.out_addr] = output
            sequenced[test.out_addr] = test_sequence

    try:
        instructions.append("nop")
        assemble_riscv("\n".join(instructions), bin_file)
    except:
        return 1

    tb_module = "tb_core" if test_core else "tb_top"
    output = run_testbench(tb_module, bin_file, "definitions.vh", "types.sv", "pc_reg.v",
                           "register_file.v", "instruction_decoder.sv", "immediate_builder.sv", "dependency_checker.sv",
                           "compare.sv", "mux_3to1.sv", "alu.sv", "conv33.sv", "dsp.sv", "RV32E.sv", "instruction_cache_controller.sv",
                           "top.sv", "MemorySlave.sv")

    passed = 0

    for i, outputs in enumerate(re.findall(r"^#?\s*(\d+)\s+(\-?\d+)$", output, re.MULTILINE)):
        out_addr, output = map(int, outputs)
        if output != expected_outputs[out_addr]:
            print(f"{out_addr}: {output}!={expected_outputs[out_addr]}")
            return 3
        passed += 1

    print(f"All tests passed ({passed})")
    return 0

if __name__ == "__main__":
    bin_file = "instructions.bin"
    instructions = []
    exit_code = main(bin_file, instructions,
                     test_decode=("-decode" in sys.argv),
                     test_core=("-core" in sys.argv))
    if exit_code == 2:
        with open("tb_decode.s", 'w') as f:
            f.write("\n".join(instructions))
    elif exit_code != 0:
        with open("tb_top.s", "w") as f:
            f.write("\n".join(instructions))
    else:
        subprocess.run(["rm", bin_file])
    sys.exit(exit_code)

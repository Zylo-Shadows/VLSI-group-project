`include "definitions.vh"
import types::*;

module RV32E (
    input logic clk,
    input logic rst_n,
    input logic [31:0] boot_addr
);

    // Pipeline stage signals
    logic [31:0] pc_if, pc_id, pc_ex;
    logic [31:0] pc_plus_4_if, pc_plus_4_id, pc_plus_4_ex, pc_plus_4_mem;

    logic [31:0] instruction_if, instruction_id;
    inst_format_t inst_fmt;

    // Register file pipeline signals
    logic [31:0] rs1_data_id, rs2_data_id;
    logic [31:0] rs1_data_ex, rs2_data_ex;
    logic [31:0] rd_data_mem, rd_data_wb;

    // Immediate
    logic [31:0] immediate_id, immediate_ex;

    // ALU operands/results
    logic [31:0] alu_operand_a, alu_operand_b;
    logic [31:0] alu_result_ex, alu_result_mem;

    // Memory data
    logic [31:0] mem_data;

    // Register addresses
    logic [4:0] rs1_addr, rs2_addr;
    logic [4:0] rd_addr_id, rd_addr_ex, rd_addr_mem;

    // Control signals
    logic mem_read_id, mem_read_ex, mem_read_mem;
    logic mem_write_id, mem_write_ex, mem_write_mem;
    logic branch_id, branch_ex, branch_mem;
    logic jump_id, jump_ex, jump_mem;
    logic mem_unsigned_id, mem_unsigned_ex;
    logic [1:0] mem_size_id, mem_size_ex;
    alu_op_t alu_op_id, alu_op_ex;

    // ALU source control
    logic [1:0] alu_src_a_id, alu_src_b_id;
    logic [1:0] alu_src_a_ex, alu_src_b_ex;
    logic alu_imm_id, alu_imm_ex;
    logic alu_pc_id, alu_pc_ex;

    // Branch compare
    logic cmp_id, cmp_ex, cmp_mem;
    logic cmp_imm;
    cmp_op_t cmp_op;
    logic cmp_result_id, cmp_result_ex, cmp_result_mem;

    // Branch/PC control
    logic branch_taken;
    logic [31:0] pc_target;
    logic pc_load_id, pc_load_ex;
    logic [31:0] pc_next;

    // Pipeline Register Transfers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // ---------------- IF/ID Reset ----------------
            pc_id          <= 32'b0;
            pc_plus_4_id   <= 32'b0;

            // ---------------- ID/EX Reset ----------------
            pc_ex          <= 32'b0;
            pc_plus_4_ex   <= 32'b0;
            pc_load_ex     <= 1'b0;
            rs1_data_ex    <= 32'b0;
            rs2_data_ex    <= 32'b0;
            immediate_ex   <= 32'b0;
            rd_addr_ex     <= 5'b0;
            mem_read_ex    <= 1'b0;
            mem_write_ex   <= 1'b0;
            mem_size_ex    <= 2'b0;
            mem_unsigned_ex<= 1'b0;
            alu_op_ex      <= 4'b0;
            alu_src_a_ex   <= 2'b0;
            alu_src_b_ex   <= 2'b0;
            alu_imm_ex     <= 1'b0;
            alu_pc_ex      <= 1'b0;
            branch_ex      <= 1'b0;
            jump_ex        <= 1'b0;
            cmp_ex         <= 1'b0;
            cmp_result_ex  <= 1'b0;

            // ---------------- EX/MEM Reset ----------------
            pc_plus_4_mem   <= 32'b0;
            alu_result_mem  <= 32'b0;
            rd_addr_mem     <= 5'b0;
            mem_read_mem    <= 1'b0;
            mem_write_mem   <= 1'b0;
            branch_mem      <= 1'b0;
            jump_mem        <= 1'b0;
            cmp_mem         <= 1'b0;
            cmp_result_mem  <= 1'b0;

            // ---------------- MEM/WB Reset ----------------
            rd_data_wb      <= 32'b0;
        end else begin
            // ---------------- IF → ID ----------------
            pc_id          <= pc_if;
            pc_plus_4_id   <= pc_plus_4_if;

            // ---------------- ID → EX ----------------
            pc_ex          <= pc_id;
            pc_plus_4_ex   <= pc_plus_4_id;
            pc_load_ex     <= pc_load_id;
            rs1_data_ex    <= rs1_data_id;
            rs2_data_ex    <= rs2_data_id;
            immediate_ex   <= immediate_id;
            rd_addr_ex     <= rd_addr_id;
            mem_read_ex    <= mem_read_id;
            mem_write_ex   <= mem_write_id;
            mem_size_ex    <= mem_size_id;
            mem_unsigned_ex<= mem_unsigned_id;
            alu_op_ex      <= alu_op_id;
            alu_src_a_ex   <= alu_src_a_id;
            alu_src_b_ex   <= alu_src_b_id;
            alu_imm_ex     <= alu_imm_id;
            alu_pc_ex      <= alu_pc_id;
            branch_ex      <= branch_id;
            jump_ex        <= jump_id;
            cmp_ex         <= cmp_id;
            cmp_result_ex  <= cmp_result_id;

            // ---------------- EX → MEM ----------------
            pc_plus_4_mem   <= pc_plus_4_ex;
            alu_result_mem  <= alu_result_ex;
            rd_addr_mem     <= rd_addr_ex;
            mem_read_mem    <= mem_read_ex;
            mem_write_mem   <= mem_write_ex;
            branch_mem      <= branch_ex;
            jump_mem        <= jump_ex;
            cmp_mem         <= cmp_ex;
            cmp_result_mem  <= cmp_result_ex;

            // ---------------- MEM → WB ----------------
            rd_data_wb      <= rd_data_mem;
        end
    end

    assign branch_taken = cmp_result_id;
    assign pc_target = alu_result_ex;

    // stall two cycles on branches and jumps to fetch the correct instruction
    assign pc_load_id = jump_id || (branch_id && branch_taken);

    always @(posedge clk) begin
        if (pc_load_id || pc_load_ex || !rst_n) instruction_id <= NOP;
        else instruction_id <= instruction_if;
    end

    pc_reg pc (
        .clk(clk),
        .rst_n(rst_n),
        .pc_start(boot_addr),
        .pc_load(pc_load_ex), 
        .pc_in(pc_target),
        .pc_out(pc_if),
        .pc_plus_4(pc_plus_4_if),
        .pc_next(pc_next)
    );

    instruction_memory imem (
        .clk(clk),
        .rst_n(rst_n),
        .boot_addr(boot_addr),
        .addr(pc_next),
        .instruction(instruction_if)
    );

    register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(!branch_mem),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr_mem),
        .rd_data(rd_data_mem),
        .rs1_data(rs1_data_id),
        .rs2_data(rs2_data_id)
    );

    instruction_decoder decoder (
        .instruction(instruction_id),
        .instruction_format(inst_fmt),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr_id),
        .branch(branch_id),
        .jump(jump_id),
        .compare(cmp_id),
        .cmp_imm(cmp_imm),
        .cmp_op(cmp_op),
        .alu_imm(alu_imm_id),
        .alu_pc(alu_pc_id),
        .alu_op(alu_op_id),
        .mem_read(mem_read_id),
        .mem_write(mem_write_id),
        .mem_size(mem_size_id),
        .mem_unsigned(mem_unsigned_id)
    );

    immediate_builder IMMU (
        .inst_fmt(inst_fmt),
        .instruction(instruction_id),
        .immediate(immediate_id)
    );

    dependency_checker dpc (
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd1_addr(rd_addr_ex),
        .rd2_addr(rd_addr_mem),
        .alu_src1(alu_src_a_id),
        .alu_src2(alu_src_b_id)
    );

    compare CMPU (
        .operand_a(rs1_data_id),
        .operand_b(cmp_imm ? immediate_id : rs2_data_id),
        .cmp_op(cmp_op),
        .result(cmp_result_id)
    );

    mux_4to1 #(.WIDTH(32)) alu_mux_a (
        .sel(alu_pc_ex ? 2'd3 : alu_src_a_ex),
        .in0(rs1_data_ex),
        .in1(rd_data_mem),
        .in2(rd_data_wb),
        .in3(pc_ex),
        .out(alu_operand_a)
    );

    mux_4to1 #(.WIDTH(32)) alu_mux_b (
        .sel(alu_imm_ex ? 2'd3 : alu_src_b_ex),
        .in0(rs2_data_ex),
        .in1(rd_data_mem),
        .in2(rd_data_wb),
        .in3(immediate_ex),
        .out(alu_operand_b)
    );

    alu ALU (
        .operand_a(alu_operand_a),
        .operand_b(alu_operand_b),
        .alu_op(alu_op_ex),
        .result(alu_result_ex)
    );

    // TODO DSP module instantiation

    data_memory dmem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(alu_result_ex),
        .write_data(rs2_data_ex),
        .mem_write(mem_write_ex),
        .mem_size(mem_size_ex),
        .mem_unsigned(mem_unsigned_ex),
        .read_data(mem_data)
    );

    always_comb begin
        // SLT
        if (cmp_mem) rd_data_mem = cmp_result_mem;
        // JAL
        else if (jump_mem) rd_data_mem = pc_plus_4_mem;
        // LD
        else if (mem_read_mem) rd_data_mem = mem_data;
        else rd_data_mem = alu_result_mem;
    end

endmodule

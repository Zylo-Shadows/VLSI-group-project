module riscv_pipeline_top (
    input logic clk,
    input logic rst_n,
    input logic [31:0] boot_addr
);

    // Pipeline stage signals
    logic [31:0] pc_if, pc_id, pc_ex, pc_mem, pc_wb;
    logic [31:0] instruction_if, instruction_id;
    logic [31:0] rs1_data, rs2_data, rd_data_wb;
    logic [31:0] alu_result_ex, alu_result_mem;
    logic [31:0] mem_data_mem, mem_data_wb;
    logic [4:0] rs1_addr, rs2_addr, rd_addr_id, rd_addr_ex, rd_addr_mem, rd_addr_wb;
    logic [31:0] immediate_id, immediate_ex;
    logic [31:0] alu_operand_a, alu_operand_b;

    // Control signals
    logic reg_write_id, reg_write_ex, reg_write_mem, reg_write_wb;
    logic mem_read_id, mem_read_ex, mem_read_mem;
    logic mem_write_id, mem_write_ex, mem_write_mem;
    logic branch_id, branch_ex;
    logic jump_id, jump_ex;
    logic alu_src_id, alu_src_ex;
    logic [3:0] alu_op_id, alu_op_ex;
    logic [2:0] mem_size_id, mem_size_ex, mem_size_mem;
    logic mem_unsigned_id, mem_unsigned_ex, mem_unsigned_mem;

    // Forwarding and hazard signals
    logic [1:0] forward_a, forward_b;
    logic stall_if, stall_id, flush_id, flush_ex;
    logic hazard_detected;

    // Branch/Jump signals
    logic branch_taken;
    logic [31:0] pc_target;

    assign branch_taken = cmp_result_id;
    assign pc_target = alu_result_ex;

    // stall two cycles on branches and jumps to fetch the correct instruction
    assign pc_load_id = jump_id || (branch_id && branch_taken);

    always @(posedge clk) begin
        pc_load_ex <= pc_load_id;

        if (pc_load_id || pc_load_ex) instruction_id <= NOP;
        else instruction_id <= instruction_if;
    end

    pc_reg pc (
        .clk(clk),
        .rst_n(rst_n),
        .pc_load(pc_load_ex), 
        .pc_in(pc_target),
        .pc_out(pc_if),
        .pc_plus_4(pc_plus_4_if),
        .pc_next(pc_next)
    );

    instruction_memory imem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(pc_next),
        .instruction(instruction_if)
    );

    register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr_mem),
        .rd_data(rd_data_mem),
        .rd_data_out(rd_data_wb),
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
        .imm_type(inst_fmt)
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
        .result(alu_result_ex),
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
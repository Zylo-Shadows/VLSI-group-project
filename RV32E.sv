`include "definitions.vh"
import types::*;

module RV32E (
    input logic clk,
    input logic rst_n,
    input logic [31:0] boot_addr,

    output logic        pc_load_id,
    output logic        pc_load_ex,
    output logic [31:0] inst_addr,
    input  logic [31:0] instruction,
    input  logic inst_ready,

    output logic sram_cen, sram_wen,
    output logic [ 3:0] sram_ben,
    output logic [31:0] sram_addr,
    output logic [31:0] sram_din,
    input  logic [31:0] sram_dout
);

    // Pipeline stage signals
    logic [31:0] pc_if, pc_id, pc_ex;
    logic [31:0] pc_plus_4_if, pc_plus_4_id, pc_plus_4_ex, pc_plus_4_mem;

    logic [31:0] instruction_if, instruction_id;
    inst_format_t inst_fmt;

    // Register file pipeline signals
    logic [31:0] rs1_data_id, rs2_data_id;
    logic [31:0] rs1_data_csr;
    logic [31:0] rs1_data_ex, rs2_data_ex;
    logic [31:0] rs1_data, rs2_data;
    logic [31:0] rd_data_mem, rd_data_wb;

    // CSR signals
    logic        csr_valid, csr_stall, csr_stalled;
    logic  [2:0] csr_funct3;
    logic [31:0] csr_rdata;

    // Immediate
    logic [31:0] immediate_id, immediate_ex;

    // ALU operands/results
    logic [31:0] alu_result_ex, alu_result_mem;

    // Memory
    logic  [1:0] mem_offset;
    logic [31:0] mem_data;

    // Register addresses
    logic [4:0] rs1_addr, rs2_addr_id, rs2_addr_ex;
    logic [4:0] rd_addr_id, rd_addr_ex, rd_addr_mem;

    // Control signals
    logic mem_read_id, mem_read_ex, mem_read_mem;
    logic mem_write_id, mem_write_ex;
    logic branch_id, branch_ex, branch_mem;
    logic jump_id, jump_ex, jump_mem;
    logic mem_unsigned_id, mem_unsigned_ex, mem_unsigned_mem;
    logic [1:0] mem_size_id, mem_size_ex, mem_size_mem;
    alu_op_t alu_op_id, alu_op_ex;

    // Forwarding
    logic [1:0] src1_id, src2_id;
    logic [1:0] src1_ex, src2_ex;

    // ALU source control
    logic alu_imm_id, alu_imm_ex;
    logic alu_pc_id, alu_pc_ex;

    // DSP
    logic dsp_shift_en;
    logic [1:0] dsp_mode;
    logic [31:0] r16, r17, r18, dsp_out;

    // Branch compare
    logic cmp_id, cmp_ex, cmp_mem;
    logic cmp_imm_id, cmp_imm_ex;
    cmp_op_t cmp_op_id, cmp_op_ex;
    logic cmp_result_ex, cmp_result_mem;

    // Branch/PC control
    logic branch_taken;
    logic pc_load;
    logic [31:0] pc_target;
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
            immediate_ex   <= 32'b0;
            rs2_addr_ex    <= 5'b0;
            rd_addr_ex     <= 5'b0;
            mem_read_ex    <= 1'b0;
            mem_write_ex   <= 1'b0;
            mem_size_ex    <= 2'b0;
            mem_unsigned_ex<= 1'b0;
            alu_op_ex      <= alu_op_t'(4'b0);
            src1_ex   <= 2'b0;
            src2_ex   <= 2'b0;
            alu_imm_ex     <= 1'b0;
            alu_pc_ex      <= 1'b0;
            branch_ex      <= 1'b0;
            jump_ex        <= 1'b0;
            cmp_ex         <= 1'b0;
            cmp_imm_ex     <= 1'b0;
            cmp_op_ex      <= cmp_op_t'(3'b0);

            // ---------------- EX/MEM Reset ----------------
            pc_plus_4_mem   <= 32'b0;
            alu_result_mem  <= 32'b0;
            rd_addr_mem     <= 5'b0;
            mem_read_mem    <= 1'b0;
            mem_size_mem    <= 2'b0;
            mem_unsigned_mem<= 1'b0;
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
            immediate_ex   <= immediate_id;
            rs2_addr_ex    <= rs2_addr_id;
            rd_addr_ex     <= rd_addr_id;
            mem_read_ex    <= mem_read_id;
            mem_write_ex   <= mem_write_id;
            mem_size_ex    <= mem_size_id;
            mem_unsigned_ex<= mem_unsigned_id;
            alu_op_ex      <= alu_op_id;
            src1_ex   <= src1_id;
            src2_ex   <= src2_id;
            alu_imm_ex     <= alu_imm_id;
            alu_pc_ex      <= alu_pc_id;
            branch_ex      <= branch_id;
            jump_ex        <= jump_id;
            cmp_ex         <= cmp_id;
            cmp_imm_ex     <= cmp_imm_id;
            cmp_op_ex      <= cmp_op_id;

            // ---------------- EX → MEM ----------------
            pc_plus_4_mem   <= pc_plus_4_ex;
            alu_result_mem  <= alu_result_ex;
            rd_addr_mem     <= rd_addr_ex;
            mem_read_mem    <= mem_read_ex;
            mem_size_mem    <= mem_size_ex;
            mem_unsigned_mem<= mem_unsigned_ex;
            branch_mem      <= branch_ex;
            jump_mem        <= jump_ex;
            cmp_mem         <= cmp_ex;
            cmp_result_mem  <= cmp_result_ex;

            // ---------------- MEM → WB ----------------
            rd_data_wb      <= rd_data_mem;
        end
    end

    assign branch_taken = cmp_result_ex;

    // stall two cycles on branches and jumps to fetch the correct instruction
    assign pc_load_id = jump_id || branch_id;
    assign pc_load_ex = jump_ex || (branch_ex && branch_taken);

    always @(posedge clk) begin
        if (!rst_n)
            pc_load <= 1'b1;
        else
            pc_load <= (pc_load_ex || (pc_load && !inst_ready));
    end

    always @(posedge clk) begin
        if (!rst_n)
            pc_target <= boot_addr;
        else if (pc_load_ex)
            pc_target <= alu_result_ex;
    end

    // stall one cycle so CSR forwarding from memory stage works correctly
    assign csr_stall = (opcode_t'(instruction_if[6:0]) == OP_SYSTEM);

    always @(posedge clk) begin
        if (csr_stalled)
            csr_stalled <= 1'b0;
        else
            csr_stalled <= csr_stall;
    end

    always @(posedge clk) begin
        if (!inst_ready || (csr_stall && !csr_stalled) || pc_load_id || pc_load_ex || pc_load || !rst_n)
            instruction_id <= NOP;
        else instruction_id <= instruction_if;
    end

    pc_reg pc (
        .clk(clk),
        .rst_n(rst_n),
        .pc_en(inst_ready && (!csr_stall || csr_stalled) && !pc_load_id),
        .pc_start(boot_addr),
        .pc_load(pc_load_ex || pc_load),
        .pc_in(pc_load_ex ? alu_result_ex : pc_target),
        .pc_out(pc_if),
        .pc_plus_4(pc_plus_4_if),
        .pc_next(pc_next)
    );

    assign inst_addr = pc_next;
    assign instruction_if = instruction;

    register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr_id),
        .rd_addr(rd_addr_mem),
        .rd_data(rd_data_mem),
        .rs1_data(rs1_data_id),
        .rs2_data(rs2_data_id),
        .r16(r16),
        .r17(r17),
        .r18(r18)
    );

    assign dsp_shift_en = (rd_addr_mem == 5'd16);

    instruction_decoder decoder (
        .instruction(instruction_id),
        .instruction_format(inst_fmt),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr_id),
        .rd_addr(rd_addr_id),
        .branch(branch_id),
        .jump(jump_id),
        .compare(cmp_id),
        .cmp_imm(cmp_imm_id),
        .cmp_op(cmp_op_id),
        .alu_imm(alu_imm_id),
        .alu_pc(alu_pc_id),
        .alu_op(alu_op_id),
        .mem_read(mem_read_id),
        .mem_write(mem_write_id),
        .mem_size(mem_size_id),
        .mem_unsigned(mem_unsigned_id),
        .funct3(csr_funct3),
        .csr_valid(csr_valid)
    );

    immediate_builder IMMU (
        .inst_fmt(inst_fmt),
        .instruction(instruction_id),
        .immediate(immediate_id)
    );

    dependency_checker dpc (
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr_id),
        .rd1_addr(rd_addr_ex),
        .rd2_addr(rd_addr_mem),
        .src1(src1_id),
        .src2(src2_id)
    );

    mux_3to1 #(.WIDTH(32)) rs1_csr_mux (
        .sel(src1_id),
        .in0(rs1_data_id),
        .in1(alu_result_ex),
        .in2(rd_data_mem),
        .out(rs1_data_csr)
    );

    csr_file csr (
        .clk(clk),
        .rst_n(rst_n),
        .csr_valid(csr_valid),
        .csr_addr(immediate_id[11:0]),
        .csr_funct3(csr_funct3),
        .csr_rs1(rs1_addr),
        .csr_rd(rd_addr_id),
        .csr_wdata(rs1_data_csr),
        .csr_zimm(rs1_addr),
        .csr_rdata(csr_rdata),
        .dsp_mode(dsp_mode)
    );

    always @(posedge clk) begin
        if (csr_valid) begin
            rs1_data_ex <= csr_rdata;
            rs2_data_ex <= '0;
        end
        else begin
            rs1_data_ex <= rs1_data_id;
            rs2_data_ex <= rs2_data_id;
        end
    end

    mux_3to1 #(.WIDTH(32)) rs1_data_mux (
        .sel(src1_ex),
        .in0(rs1_data_ex),
        .in1(rd_data_mem),
        .in2(rd_data_wb),
        .out(rs1_data)
    );

    mux_3to1 #(.WIDTH(32)) rs2_data_mux (
        .sel(src2_ex),
        .in0(rs2_data_ex),
        .in1(rd_data_mem),
        .in2(rd_data_wb),
        .out(rs2_data)
    );

    compare CMPU (
        .operand_a(rs1_data),
        .operand_b(cmp_imm_ex ? immediate_ex : rs2_data),
        .cmp_op(cmp_op_ex),
        .result(cmp_result_ex)
    );

    alu ALU (
        .operand_a(alu_pc_ex ? pc_ex : rs1_data),
        .operand_b(alu_imm_ex ? immediate_ex : rs2_data),
        .alu_op(alu_op_ex),
        .result(alu_result_ex)
    );

    dsp dsp (
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(dsp_shift_en),
        .mode(dsp_mode),
        .top_pix(r16),
        .mid_pix(r17),
        .bot_pix(rd_addr_mem == 5'd18 ? rd_data_mem : r18),
        .pixel_out(dsp_out)
    );

    assign sram_cen  = !rst_n;
    assign sram_addr = alu_result_ex;
    assign sram_din  = (rs2_addr_ex == 5'd19 ? dsp_out : rs2_data) << (8 * sram_addr[1:0]);
    assign sram_wen  = !mem_write_ex;

    // Generate byte enables based on access size and address offset
    always_comb begin
        unique case (mem_size_ex)
            2'b00: begin // byte
                sram_ben = 4'b1111;
                sram_ben[sram_addr[1:0]] = 1'b0;  // one byte active (active low)
            end
            2'b01: begin // halfword
                case (sram_addr[1])
                    1'b0: sram_ben = 4'b1100; // lower halfword
                    1'b1: sram_ben = 4'b0011; // upper halfword
                endcase
            end
            2'b10: sram_ben = 4'b0000; // full word
            default: sram_ben = 4'b1111;
        endcase
    end

    always_ff @(posedge clk) begin
        mem_offset <= sram_addr[1:0];
    end

    always_comb begin
        mem_data = sram_dout >> (8 * mem_offset);
        case (mem_size_mem)
            2'b00: // byte
                mem_data[31:8] = mem_unsigned_mem ? 24'b0 : {24{mem_data[7]}};
            2'b01: // halfword
                mem_data[31:16] = mem_unsigned_mem ? 16'b0 : {16{mem_data[15]}};
            default:;
        endcase
    end

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

`timescale 1ns/1ps

module top (
    input  logic clk,
    input  logic rst_n,

    output logic [1:0] dsp_mode,

    output logic vga_clk, vga_blank_n, vga_vs, vga_hs,
    output logic [7:0] r, g, b
);

    logic [7:0] a;

    logic [31:0] boot_addr;
    assign boot_addr = 32'h00000000;

    localparam RAM_SIZE = 96 * 1024;

    logic        pc_load_id;
    logic        pc_load_ex;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;

    logic        sram_cen;
    logic        sram_wen;
    logic  [3:0] sram_ben;
    logic [31:0] sram_addr;
    logic [31:0] sram_din;
    logic [31:0] sram_dout;

    logic  [7:0] cidx_top, cidx_mid, cidx_bot;
    logic [31:0] color_rgba_top, color_rgba_mid, color_rgba_bot;
    logic  [9:0] x, y;

    vga256 vga (
        .clk(clk),
        .rst_n(rst_n),
        .cidx_top(cidx_top),
        .cidx_mid(cidx_mid),
        .cidx_bot(cidx_bot),
        .vga_clk(vga_clk),
        .vga_blank_n(vga_blank_n),
        .vga_vs(vga_vs),
        .vga_hs(vga_hs),
        .x(x), .y(y),
        .color_rgba_top(color_rgba_top),
        .color_rgba_mid(color_rgba_mid),
        .color_rgba_bot(color_rgba_bot)
    );

    SRAM2 #(
        .DEPTH(RAM_SIZE)
    ) RAM (
        .clk(clk),
        .cen(sram_cen),
        .wen(sram_addr[31] ? 1'b0 : sram_wen),
        .ben(sram_ben),
        .addr1(imem_addr[$clog2(RAM_SIZE)+1:2]),
        .addr2(sram_addr[$clog2(RAM_SIZE)+1:2]),
        .din(sram_din),
        .dout1(imem_rdata),
        .dout2(sram_addr[31] ? (sram_addr[30] ? {vga_hs, vga_vs, 4'b0, y, 6'b0, x} : 32'b0) : sram_dout)
    );

    RV32E core (
        .clk         (clk),
        .rst_n       (rst_n),
        .boot_addr   (boot_addr),

        // Instruction side
        .pc_load_id  (pc_load_id),
        .pc_load_ex  (pc_load_ex),
        .inst_addr   (imem_addr),
        .instruction (imem_rdata),
        .inst_ready  (1'b1),

        .r16(cidx_top),
        .r17(cidx_mid),
        .r18(cidx_bot),

        .top_pix(color_rgba_top),
        .mid_pix(color_rgba_mid),
        .bot_pix(color_rgba_bot),
        .dsp_mode(dsp_mode),
        .dsp_out({a,b,g,r}),

        // Data side (connected to TCM)

        .sram_cen    (sram_cen),
        .sram_wen    (sram_wen),
        .sram_ben    (sram_ben),
        .sram_addr   (sram_addr),
        .sram_din    (sram_din),
        .sram_dout   (sram_dout)
    );

endmodule

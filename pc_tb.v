`timescale 1ns/1ps

module tb_pc_reg;
    reg         clk;
    reg         rst_n;
    reg  [31:0] pc_start;
    reg         pc_load;
    reg  [31:0] pc_in;
    wire [31:0] pc_out;
    wire [31:0] pc_plus_4;
    wire [31:0] pc_next;

    pc_reg dut (
        .clk(clk),
        .rst_n(rst_n),
        .pc_start(pc_start),
        .pc_load(pc_load),
        .pc_in(pc_in),
        .pc_out(pc_out),
        .pc_plus_4(pc_plus_4),
        .pc_next(pc_next)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        pc_start = 32'h0000_1000;
        pc_load = 0;
        pc_in = 32'h0;

        #10 rst_n = 1;

        repeat (3) @(posedge clk);

        pc_load = 1;
        pc_in = 32'h0000_2000;
        @(posedge clk);
        pc_load = 0;

        repeat (3) @(posedge clk);

        pc_load = 1;
        pc_in = 32'h0000_3000;
        @(posedge clk);
        pc_load = 0;
        repeat (2) @(posedge clk);
        $finish;
    end
endmodule

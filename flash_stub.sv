module flash_wrapper (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        cs_n,
    input  logic        we_n,
    input  logic        oe_n,
    input  logic [23:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        ready
);

    // insert flash macro here

    // Ready signal generation (typical for flash timing)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else begin
            ready <= ~cs_n & ~oe_n;
        end
    end

endmodule

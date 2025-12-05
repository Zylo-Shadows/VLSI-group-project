module flash_stub (
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

    logic [31:0] mem [0:15];

    // imitate basic flash logic
    always_ff @(posedge clk) begin
        if (!cs_n) begin
            if (!we_n) begin
                mem[addr[3:0]] <= wdata;
            end
            if (!oe_n) begin
                rdata <= mem[addr[3:0]];
            end
        end
    end

    // Ready signal generation (typical for flash timing)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else begin
            ready <= ~cs_n & ~oe_n;
        end
    end

endmodule

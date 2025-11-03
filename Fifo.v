module fifo #(
    parameter DATA_WIDTH = 32, //32 Dat Bus
    parameter DEPTH      = 16
)(
    input  wire  clk,
    input  wire  rst,  // synchronous active-high reset
    input  wire [DATA_WIDTH-1:0] din,
    input  wire   wr_en,
    input  wire   rd_en,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire empty,
    output wire full,
    output wire [$clog2(DEPTH):0] count
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    reg [$clog2(DEPTH):0] cnt;

    assign count = cnt;
    assign full  = (cnt == DEPTH);
    assign empty = (cnt == 0);

    always @(posedge clk) begin
        if (rst) begin
            // synchronous reset
            wr_ptr <= 0;
            rd_ptr <= 0;
            cnt    <= 0;
            dout   <= {DATA_WIDTH{1'b0}};
        end else begin
            // Write operation
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr <= wr_ptr + 1'b1;
            end
            // Read operation
            if (rd_en && !empty) begin
                dout <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1'b1;
            end
            // Update count
            case ({wr_en && !full, rd_en && !empty})
                2'b10: cnt <= cnt + 1'b1;  // write only
                2'b01: cnt <= cnt - 1'b1;  // read only
                default: cnt <= cnt;       // both or none
            endcase
        end
    end

endmodule

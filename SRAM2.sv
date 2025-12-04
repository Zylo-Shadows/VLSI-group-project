module SRAM2 #(
    parameter DEPTH = 2**16,
    parameter DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  cen,     // active low
    input  logic                  wen,     // active low
    input  logic [3:0]            ben,     // active low per byte
    input  logic [$clog2(DEPTH)-1:0] addr1,
    input  logic [$clog2(DEPTH)-1:0] addr2,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout1,
    output logic [DATA_WIDTH-1:0] dout2
);

    logic [3:0][7:0] mem [0:DEPTH-1];

    initial begin
        $readmemh("ms.hex", mem);
    end

    always_ff @(posedge clk) begin
        if (!cen) begin
            // Write
            if (!wen) begin
                if (!ben[0]) mem[addr2][0] <= din[7:0];
                if (!ben[1]) mem[addr2][1] <= din[15:8];
                if (!ben[2]) mem[addr2][2] <= din[23:16];
                if (!ben[3]) mem[addr2][3] <= din[31:24];
            end

            // Read
            dout1 <= {mem[addr1][3], mem[addr1][2], mem[addr1][1], mem[addr1][0]};
            dout2 <= {mem[addr2][3], mem[addr2][2], mem[addr2][1], mem[addr2][0]};
        end else begin
            dout1 <= '0;
            dout2 <= '0;
        end
    end

endmodule

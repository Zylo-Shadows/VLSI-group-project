module SRAM #(
    parameter DEPTH = 2**16
)(
    input  logic clk, sram_cen, sram_wen,
    input  logic [ 3:0] sram_ben,
    input  logic [31:0] sram_addr,
    input  logic [31:0] sram_din,
    output logic [31:0] sram_dout
);

    logic [3:0][7:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH)-1:0] addr;
    assign addr = sram_addr[$clog2(DEPTH)+1:2];

    always_ff @(posedge clk) begin
        if (!sram_cen) begin
            // Write
            if (!sram_wen) begin
                if (!sram_ben[0]) mem[addr][0] <= sram_din[7:0];
                if (!sram_ben[1]) mem[addr][1] <= sram_din[15:8];
                if (!sram_ben[2]) mem[addr][2] <= sram_din[23:16];
                if (!sram_ben[3]) mem[addr][3] <= sram_din[31:24];
            end

            // Read
            sram_dout <= {mem[addr][3], mem[addr][2], mem[addr][1], mem[addr][0]};
        end else begin
            sram_dout <= '0;
        end
    end

endmodule

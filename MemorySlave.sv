`timescale 1ns/1ps

module MemorySlave #(
    parameter MEM_SIZE = 256,
    parameter LATENCY  = 2
)(
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic [31:0] HADDR,
    input  logic  [1:0] HTRANS,
    input  logic        HWRITE,
    input  logic  [2:0] HSIZE,  // should be 3 bits for AHB
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic [1:0]  HRESP,
    input  logic        HSEL
);

    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        BUSY     = 2'b01,
        NONSEQ   = 2'b10,
        SEQ      = 2'b11
    } htrans_t;

    logic [31:0] mem [0:MEM_SIZE-1];

    logic [$clog2(LATENCY+1)-1:0] latency_cnt;
    logic        busy;
    logic        first_access;

    logic [31:0] addr_reg;
    logic        write_reg;
    logic [31:0] wdata_reg;

    wire transfer_logic = HSEL && (HTRANS == NONSEQ || HTRANS == SEQ);

    always_ff @(posedge HCLK) begin
    if (!HRESETn) begin
        // internal counting
        busy          <= 0;
        first_access  <= 0;
        latency_cnt   <= 0;
        addr_reg      <= 0;
        write_reg     <= 0;
        wdata_reg     <= 0;
    end else begin
        if (transfer_logic && !busy) begin
            busy         <= 1;
            first_access <= (HTRANS == NONSEQ);
            latency_cnt  <= (HTRANS == NONSEQ) ? LATENCY-1 : 0;

            // capture request
            addr_reg  <= HADDR;
            write_reg <= HWRITE;
            wdata_reg <= HWDATA;

        end else if (busy) begin
            if (latency_cnt > 0)
                latency_cnt <= latency_cnt - 1;
            else begin
                // Complete transfer
                if (write_reg)
                    mem[addr_reg[9:2]] <= wdata_reg;
                // For SEQ, increment address
                if (!write_reg && HTRANS == SEQ)
                    addr_reg <= addr_reg + 4;
                busy <= 0;
            end
        end
    end
end


always_comb begin
        logic [31:0] word = mem[addr_reg[$clog2(MEM_SIZE)+1:2]];
        case (HSIZE)
		  // word based addressing (help from GPT)
            3'b000: case (addr_reg[1:0])
            2'b00: HRDATA = {24'b0, word[7:0]};
            2'b01: HRDATA = {24'b0, word[15:8]};
            2'b10: HRDATA = {24'b0, word[23:16]};
            2'b11: HRDATA = {24'b0, word[31:24]};
                    endcase
            3'b001: HRDATA = addr_reg[1] ? {16'b0, word[31:16]} : {16'b0, word[15:0]};
            default: HRDATA = word;
        endcase
    end
    assign HREADY = !busy;
	 
    assign HRESP  = 2'b00;

endmodule

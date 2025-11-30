`timescale 1ns/1ps

// MARKER_ABCDEFG
module MemorySlave #(
    parameter MEM_SIZE = 256,
    parameter LATENCY  = 2
)(
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic [31:0] HADDR,
    input  logic  [1:0] HTRANS,
    input  logic        HWRITE,
    input  logic  [2:0] HSIZE,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
<<<<<<< Updated upstream
    output logic [1:0]  HRESP,
    input  logic        HSEL
=======
    output logic  [1:0] HRESP,
    input  logic        HSEL,
    output integer      num_instr,
    output logic        inst_loaded
>>>>>>> Stashed changes
);

    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        BUSY   = 2'b01,
        NONSEQ = 2'b10,
        SEQ    = 2'b11
    } htrans_t;

<<<<<<< Updated upstream
    logic [31:0] mem [0:MEM_SIZE-1];
=======
    // Memory declaration
    logic [31:0] mem [0:MEM_SIZE/4-1];

    integer fd;

    // Load instructions from binary file
    initial begin
        inst_loaded = 0;
        fd = $fopen("instructions.bin","rb");
        num_instr = $fread(mem, fd);
        $fclose(fd);

        for (int i = 0; i < MEM_SIZE/4; i++) begin
            if (i < num_instr)
                mem[i] = {mem[i][7:0], mem[i][15:8], mem[i][23:16], mem[i][31:24]};
            else
                mem[i] = NOP;
        end

        inst_loaded = 1;
        $display("Instruction memory loaded");
    end
>>>>>>> Stashed changes

    logic [$clog2(LATENCY+1)-1:0] latency_cnt;
    logic        busy;
    logic        first_access;

    logic [31:0] addr_reg;
    logic        write_reg;
    logic [31:0] wdata_reg;

    wire transfer_logic = HSEL && (HTRANS == NONSEQ || HTRANS == SEQ);

    // Synchronous read/write logic
    always_ff @(posedge HCLK) begin
        if (!HRESETn) begin
            busy         <= 0;
            first_access <= 0;
            latency_cnt  <= 0;
            addr_reg     <= 0;
            write_reg    <= 0;
            wdata_reg    <= 0;
            HRDATA       <= 0;
			end else begin
             // BUSY: countdown latency
             if (latency_cnt != 0) begin
                    latency_cnt <= latency_cnt - 1;
             end else begin
				      // Transfer completes now
                  if (write_reg)
                      mem[addr_reg[9:2]] <= wdata_reg;

<<<<<<< Updated upstream
            // capture request
            addr_reg  <= HADDR;
            write_reg <= HWRITE;
            wdata_reg <= HWDATA;
        end 
		  
		  else if (busy) begin
            
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
=======
                  busy <= 0;  // Now we deassert busy, meaning HREADY=1 next cycle
                end
>>>>>>> Stashed changes
            end
        end
    end

    logic [31:0] word = mem[addr_reg[$clog2(MEM_SIZE)-1:2]];

<<<<<<< Updated upstream
always_comb begin 
automatic logic [31:0] word = mem[addr_reg[$clog2(MEM_SIZE)-1:2]];
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
	 
=======
    always_comb begin
        case (HSIZE)
            3'b000: begin
                case (addr_reg[1:0])
                    2'b00: HRDATA = {24'b0, word[7:0]};
                    2'b01: HRDATA = {24'b0, word[15:8]};
                    2'b10: HRDATA = {24'b0, word[23:16]};
                    2'b11: HRDATA = {24'b0, word[31:24]};
                endcase
            end
            3'b001: begin
                HRDATA = addr_reg[1] ? {16'b0, word[31:16]} :{16'b0, word[15:0]};
            end
            default: HRDATA = word;
        endcase
    end

    assign HREADY = !busy;
>>>>>>> Stashed changes
    assign HRESP  = 2'b00;

endmodule

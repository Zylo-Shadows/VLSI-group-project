`timescale 1ns/1ps

module top (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic [31:0] boot_addr,
	 input  logic [31:0] HRDATA,
    input  logic        HREADY,
    input  logic [1:0]  HRESP,
	 
	 //outputs
    output logic [31:0] HADDR,
    output logic  [1:0] HTRANS,
    output logic        HWRITE,
    output logic  [1:0] HSIZE,
    output logic [31:0] HWDATA,
    output logic  [1:0] HMASTLOCK,
    output logic        sram_cen,
    output logic        sram_wen,
    output logic [3:0]  sram_ben,
    output logic [31:0] sram_addr,
    output logic [31:0] sram_din,
	 output logic        HSEL,   // select the slave
    output logic [3:0]  HPROT   // protection 
	
    input  logic [31:0] sram_dout
);

    // Local signals for instruction and Dmem
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_req;
    logic        imem_ready;

    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [31:0] dmem_rdata;
    logic        dmem_read;
    logic        dmem_write;
    logic [1:0]  dmem_size;
    logic        dmem_ready;

    // Instantiate RV32E core and connect SRAM signals
    RV32E core (
        .clk        (HCLK),
        .rst_n      (HRESETn),
        .boot_addr  (boot_addr),
        .inst_addr  (imem_addr),
        .instruction(imem_rdata),
        .inst_ready (imem_ready),
        .sram_cen   (sram_cen),
        .sram_wen   (sram_wen),
        .sram_ben   (sram_ben),
        .sram_addr  (sram_addr),
        .sram_din   (sram_din),
        .sram_dout  (sram_dout)
    );

    // WE get to choose between data memory or instruction fetch
    logic select_data;
    always_comb begin
        if (dmem_read || dmem_write)
            select_data = 1;
        else if (imem_req)
            select_data = 0;
        else
            select_data = 1'b0;
    end

    //Hardcoded signals based on selected request
    always_comb begin
        HTRANS    = 2'b00;
        HADDR     = 32'h0;
        HWRITE    = 1'b0;
        HSIZE     = 3'b10;
        HWDATA    = 32'h0;
        HMASTLOCK = 2'b00;
		  HSEL  = 1'b1;      // always select our single slave
		  HPROT = 4'b1011; //fixed hardcoded

		  //signal locks
        if (select_data) begin
            if (dmem_read || dmem_write) begin
                HTRANS    = 2'b10;
                HADDR     = dmem_addr;
                HWRITE    = dmem_write;
                HSIZE     = 3'b010;
                HWDATA    = dmem_wdata;
                HMASTLOCK = 2'b00;
            end
        end else if (imem_req) begin
            HTRANS    = 2'b10;
            HADDR     = imem_addr;
            HWRITE    = 1'b0;
            HSIZE     = 3'b10;
            HWDATA    = 32'h0;
            HMASTLOCK = 2'b00;
        end
    end

    // signal ready to begin mem transfer
    always_comb begin
        dmem_rdata = 32'h0;
        dmem_ready = 1'b0;
        imem_rdata = 32'h0;
        imem_ready = 1'b0;

        if (HREADY) begin
            if (select_data && (dmem_read || dmem_write)) begin
                dmem_rdata = HRDATA;
                dmem_ready = 1'b1;
            end else if (!select_data && imem_req) begin
                imem_rdata = HRDATA;
                imem_ready = 1'b1;
            end
        end
    end

    // SRAM byte-enable generator based on access size and address alignment
  always_comb begin
    sram_ben = 4'b1111; // always enable all 4 bytes for word access
end
    // Fake memory slaving, adding synchronous write and combinational read
    logic [31:0] Memory [0:255];
    always_ff @(posedge HCLK) begin
        if (HWRITE && HTRANS==2'b10) begin
          Memory[HADDR[9:2]] <= HWDATA;
        end
    end

    assign HRDATA = Memory[HADDR[9:2]];
    assign HREADY = 1'b1;
    assign HRESP  = 2'b00; //always ready

endmodule

`timescale 1ns/1ps

module ahb3lite_mem_subsystem #(
    parameter HADDR_SIZE = 32,
    parameter HDATA_SIZE = 32,
    parameter SRAM_ADDR_BASE = 32'h0000_0000,
    parameter SRAM_ADDR_MASK = 32'hFFFF_0000,
    parameter FLASH_ADDR_BASE = 32'h1000_0000,
    parameter FLASH_ADDR_MASK = 32'hF000_0000
)(
    input  HCLK,
    input  HRESETn,

    // Master Side
    input  HSEL,
    input [HADDR_SIZE-1:0] HADDR,
    input [HDATA_SIZE-1:0] HWDATA,
    input  HWRITE,
    input  [2:0] HSIZE,
    input  [2:0] HBURST,
    input [3:0] HPROT,
    input [1:0] HTRANS,

    output reg HRESP,
    output reg HREADYOUT,
    output reg [HDATA_SIZE-1:0] HRDATA,

    // Ext SRAM Interface
    output       sram_hsel,
    output [15:0] sram_haddr,
    output       sram_hwrite,
    output [1:0] sram_htrans,
    output [HDATA_SIZE-1:0] sram_hwdata,
    input  [HDATA_SIZE-1:0] sram_hrdata,
    input        sram_hready,
    input        sram_hresp,

    // Ext Flassh
    output       flash_hsel,
    output [19:0] flash_haddr,
    output       flash_hwrite,
    output [1:0] flash_htrans,
    output [HDATA_SIZE-1:0] flash_hwdata,
    input  [HDATA_SIZE-1:0] flash_hrdata,
    input        flash_hready,
    input        flash_hresp
);


    // Address decode
    wire sram_sel  = ((HADDR & SRAM_ADDR_MASK) == SRAM_ADDR_BASE);
    wire flash_sel = ((HADDR & FLASH_ADDR_MASK) == FLASH_ADDR_BASE);

    // Drive slave select out
    assign sram_hsel   = sram_sel;
    assign flash_hsel  = flash_sel;

  // Forward control/address/data to slaves (usually forwarded to all slaves;
   // inactive slaves will be ignored
    assign sram_haddr  = HADDR[15:0];
    assign flash_haddr = HADDR[19:0];
    assign sram_hwrite  = HWRITE;
    assign flash_hwrite = HWRITE;
    assign sram_htrans  = HTRANS;
    assign flash_htrans = HTRANS;
    assign sram_hwdata  = HWDATA;
    assign flash_hwdata = HWDATA;
//send all to data
  // Mux slave responses back to the master (combinational)
    always @(*) begin
        if (sram_sel) begin
         HRDATA    = sram_hrdata;
         HREADYOUT = sram_hready;
         HRESP     = sram_hresp;
        end else if (flash_sel) begin
            HRDATA    = flash_hrdata;
            HREADYOUT = flash_hready;
            HRESP     = flash_hresp;
        end else begin
           // Default safe values for unmapped access:
            HRDATA    = {HDATA_SIZE{1'b0}};
            HREADYOUT = 1'b1;  // immediately ready (or could be forced error)
            HRESP     = 1'b0;  // OKAY response
        end
    end
endmodule

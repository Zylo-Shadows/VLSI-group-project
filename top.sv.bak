`include "definitions.vh"
import types::*;

module top (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic [31:0] boot_addr,

//AHB-Lite instruction bus
    output logic [31:0] HADDR_I,
    output logic  [1:0] HTRANS_I,
    output logic        HWRITE_I,
    output logic  [2:0] HSIZE_I,
    output logic [31:0] HWDATA_I,
    input  logic [31:0] HRDATA_I,
    input  logic        HREADY_I,
    input  logic        HRESP_I,

//AHB-Lite Data Bus
 output logic [31:0] HADDR_D,
    output logic  [1:0] HTRANS_D,
   output logic        HWRITE_D,
   output logic  [2:0] HSIZE_D,
    output logic [31:0] HWDATA_D,
   input  logic [31:0] HRDATA_D,
    input  logic        HREADY_D,
   input  logic        HRESP_D
);


    // Internal CPU → Memory Interface
    // ===============================
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;

    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [31:0] dmem_rdata;
    logic dmem_write;
    logic dmem_read;
    logic  [1:0] dmem_size;

    // Instantiate the RV32E Core only 3 signals
    RV32E core (
        .clk(HCLK),
        .rst_n(HRESETn),
        .boot_addr(boot_addr)
    );


    // Instruction Fetch (Read-only)

    assign HADDR_I  = imem_addr;
    assign HWRITE_I = 1'b0;
    assign HSIZE_I  = 3'b010;         // word access
    assign HTRANS_I = (HRESETn) ? 2'b10 : 2'b00; // NONSEQ when active
    assign HWDATA_I = 32'b0; 

    // Feed instruction data back
    assign imem_rdata = HRDATA_I;


    // Data Memory Access

    assign HADDR_D   = dmem_addr;
    assign HWRITE_D  = dmem_write;
    assign HSIZE_D   = {1'b0, dmem_size};  // convert 2-bit to 3-bit AHB size
  // AHB transfer type:
    //  (2’b10) when a read or write occurs, else IDLE (2’b00)   
	assign HTRANS_D  = (dmem_read || dmem_write) ? 2'b10 : 2'b00;
    assign HWDATA_D  = dmem_wdata;

    assign dmem_rdata = HRDATA_D;

endmodule

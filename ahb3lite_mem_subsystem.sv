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

    // AHB-Lite master interface
    input  HSEL,
    input  [HADDR_SIZE-1:0] HADDR,
    input  [HDATA_SIZE-1:0] HWDATA,
    input  HWRITE,
    input  [2:0] HSIZE,
    input  [2:0] HBURST,
    input  [3:0] HPROT,
    input  [1:0] HTRANS,
    input  HREADY,

    output reg HRESP,
    output reg HREADYOUT,
    output reg [HDATA_SIZE-1:0] HRDATA
);

    // --------------------------------------------------
    // Address decode
    // --------------------------------------------------
    wire sram_sel  = ((HADDR & SRAM_ADDR_MASK) == SRAM_ADDR_BASE);
    wire flash_sel = ((HADDR & FLASH_ADDR_MASK) == FLASH_ADDR_BASE);

    // --------------------------------------------------
    // SRAM slave wires
    // --------------------------------------------------
    wire [HDATA_SIZE-1:0] sram_rdata;
    wire sram_hready, sram_hresp;

    // Flash slave wires
    wire [HDATA_SIZE-1:0] flash_rdata;
    wire flash_hready, flash_hresp;

    // --------------------------------------------------
    // SRAM instantiation
    // --------------------------------------------------
    sram_ahb #(16, HDATA_SIZE) u_sram (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HSEL(HSEL & sram_sel),
        .HWRITE(HWRITE),
        .HTRANS(HTRANS),
        .HADDR(HADDR[15:0]),
        .HWDATA(HWDATA),
        .HRDATA(sram_rdata),
        .HREADYOUT(sram_hready),
        .HRESP(sram_hresp)
    );

    // --------------------------------------------------
    // Flash instantiation
    // --------------------------------------------------
    flash_ahb #(20, HDATA_SIZE) u_flash (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HSEL(HSEL & flash_sel),
        .HTRANS(HTRANS),
        .HADDR(HADDR[19:0]),
        .HRDATA(flash_rdata),
        .HREADYOUT(flash_hready),
        .HRESP(flash_hresp)
    );

    // --------------------------------------------------
    // Mux responses
    // --------------------------------------------------
    always @(*) begin
        if (sram_sel) begin
            HRDATA    = sram_rdata;
            HREADYOUT = sram_hready;
            HRESP     = sram_hresp;
        end else if (flash_sel) begin
            HRDATA    = flash_rdata;
            HREADYOUT = flash_hready;
            HRESP     = flash_hresp;
        end else begin
            HRDATA    = 32'b0;   // safe default
            HREADYOUT = 1'b1;
            HRESP     = 1'b0;
        end
    end

endmodule


// ===================================================
// Simple SRAM AHB-Lite Slave (synthesizable)
// ===================================================
module sram_ahb #(parameter ADDR_WIDTH=16, DATA_WIDTH=32) (
    input HCLK,
    input HRESETn,
    input HSEL,
    input HWRITE,
    input [1:0] HTRANS,
    input [ADDR_WIDTH-1:0] HADDR,
    input [DATA_WIDTH-1:0] HWDATA,
    output reg [DATA_WIDTH-1:0] HRDATA,
    output reg HREADYOUT,
    output reg HRESP
);
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always @(posedge HCLK) begin
        if (!HRESETn) begin
            HRDATA    <= 0;
            HREADYOUT <= 1;
            HRESP     <= 0;
        end else if (HSEL && HTRANS[1]) begin
            HREADYOUT <= 1;
            HRESP     <= 0;
            if (HWRITE)
                mem[HADDR] <= HWDATA;
            else
                HRDATA <= mem[HADDR];
        end
    end
endmodule


// ===================================================
// Flash ROM AHB-Lite Slave (Read-only)
// ===================================================
module flash_ahb #(parameter ADDR_WIDTH=20, DATA_WIDTH=32) (
    input HCLK,
    input HRESETn,
    input HSEL,
    input [1:0] HTRANS,
    input [ADDR_WIDTH-1:0] HADDR,
    output reg [DATA_WIDTH-1:0] HRDATA,
    output reg HREADYOUT,
    output reg HRESP
);
    reg [DATA_WIDTH-1:0] rom [0:(1<<ADDR_WIDTH)-1];

    initial $readmemh("flash.hex", rom);

    always @(posedge HCLK) begin
        HREADYOUT <= 1;
        HRESP     <= 0;
        if (HSEL && HTRANS[1])
            HRDATA <= rom[HADDR];
    end
endmodule

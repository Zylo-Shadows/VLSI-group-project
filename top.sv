
module top (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic [31:0] boot_addr,

//AHB-Lite instruction bus
    output logic [31:0] HADDR,
    output logic  [1:0] HTRANS,
    output logic        HWRITE,
    output logic  [2:0] HSIZE,
    output logic [31:0] HWDATA,
    input  logic [31:0] HRDATA,
    input  logic        HREADY,
    input  logic [1:0]    HRESP
);
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic     imem_req;    // core requests instruction fetch
    logic     imem_ready;  // instruction available

    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [31:0] dmem_rdata;
    logic        dmem_read; // just our core Memory
    logic       dmem_write;
    logic  [1:0]dmem_size;
    logic      dmem_ready;

    RV32E core (
        .clk(HCLK),
        .rst_n(HRESETn),
        .boot_addr(boot_addr)
       
    );

    // For now, instruction fetches is from external buss
  
    logic        ifetch_req;
    logic [31:0] ifetch_addr;
    logic [31:0] ifetch_rdata;
    logic        ifetch_ready;

    // External Bus
    assign ifetch_req   = imem_req;
    assign ifetch_addr  = imem_addr;
    assign imem_rdata   = ifetch_rdata;
    assign imem_ready   = ifetch_ready;

    logic select_data; // 1 -> data master owns bus, 0 -> ifetch owns bus (when requested)
    always_comb begin
        if (dmem_read || dmem_write) select_data = 1;
        else if (ifetch_req) select_data = 0;
        else select_data = 1'bx; // no request idles
    end

    // Drive common bus signals from the selected master
    
   function logic [2:0] size_to_hsize(input logic [1:0] s);
       case (s)
         2'd0: size_to_hsize = 3'b000; // byte
         2'd1: size_to_hsize = 3'b001; // halfword
            default: size_to_hsize = 3'b010; // word
        endcase
    endfunction

    // Default: idle
    assign HTRANS = 2'b00;
    assign HADDR  = 32'h0;
    assign HWRITE = 1'b0;
    assign HSIZE  = 3'b010;
    assign HWDATA = 32'h0;

    //  when a master requests
    always_comb begin
      // default idle
     // If data master requests -> route data master
        if (dmem_read || dmem_write) begin
           HTRANS = 2'b10; // NONSEQ
           HADDR  = dmem_addr;
         HWRITE = dmem_write;
         HSIZE  = size_to_hsize(dmem_size);
          HWDATA = dmem_wdata;
        end
        // Else if ifetch requests -> route ifetch
        else if (ifetch_req) begin
           HTRANS = 2'b10; // NONSEQ
          HADDR  = ifetch_addr;
          HWRITE = 1'b0;
          HSIZE  = 3'b010; // word fetch
          HWDATA = 32'h0;
        end
        // else keep idle
    end

    always_comb begin
        // default outputs
        dmem_rdata   = 32'h0;
        dmem_ready   = 1'b0;
        ifetch_rdata = 32'h0;
        ifetch_ready = 1'b0;

        if (HREADY) begin
            // If data was sel and was requesting, return data to core
            if (dmem_read || dmem_write) begin
              dmem_rdata = HRDATA;
              dmem_ready = 1'b1;
            end
            // else if ifetch was requesting, return that
            else if (ifetch_req) begin
               ifetch_rdata = HRDATA;
              ifetch_ready = 1'b1;
            end
        end
    end

endmodule
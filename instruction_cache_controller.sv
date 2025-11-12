module instruction_cache_controller #(
    parameter CACHE_SIZE = 1024,
    parameter BLOCK_SIZE = 64,
    parameter PREFETCH   = 8
)(
    // AHB-Lite Clock and Reset
    input  logic        HCLK,
    input  logic        HRESETn,

    // AHB-Lite Master Interface (to memory)
    output logic [31:0] HADDR,
    output logic  [1:0] HTRANS,
    output logic  [2:0] HBURST,
    output logic  [2:0] HSIZE,
    input  logic [31:0] HRDATA,
    input  logic        HREADY,
    // HRESP is currently unused, as many fetch errors would be fatal anyway
    input  logic        HRESP,

    // CPU Interface
    input  logic [31:0] cpu_addr,
    output logic [31:0] cpu_data,
    output logic        cpu_ready,

    // Cache Control
    input  logic        cache_enable,
    output logic        cache_hit
);

    localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;
    localparam BLOCK_OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam INDEX_BITS = $clog2(NUM_BLOCKS);
    localparam TAG_BITS = 32 - INDEX_BITS - BLOCK_OFFSET_BITS;

    // AHB-Lite Transaction Types
    localparam [1:0] HTRANS_IDLE   = 2'b00;
    localparam [1:0] HTRANS_BUSY   = 2'b01;
    localparam [1:0] HTRANS_NONSEQ = 2'b10;
    localparam [1:0] HTRANS_SEQ    = 2'b11;

    // Cache Memory Arrays
    logic [TAG_BITS-1:0]           tag_array   [NUM_BLOCKS-1:0];
    logic [BLOCK_SIZE/4-1:0][31:0] data_array  [NUM_BLOCKS-1:0];
    logic [BLOCK_SIZE/4-1:0]       valid_array [NUM_BLOCKS-1:0];

    // Address currently being fetched from the bus
    logic [31:0] fetch_addr;

    // Address Parsing
    logic            [TAG_BITS-1:0] req_tag;
    logic          [INDEX_BITS-1:0] req_index;
    logic [BLOCK_OFFSET_BITS-1-2:0] req_word;

    assign {req_tag, req_index, req_word} = cpu_addr[31:2];

    logic            [TAG_BITS-1:0] fetch_tag;
    logic          [INDEX_BITS-1:0] fetch_index;
    logic [BLOCK_OFFSET_BITS-1-2:0] fetch_word;

    assign {fetch_tag, fetch_index, fetch_word} = fetch_addr[31:2];

    // Cache Lookup
    logic tag_match;
    logic cache_valid;

    assign tag_match = (tag_array[req_index] == req_tag);
    assign cache_valid = valid_array[req_index][req_word];
    assign cache_hit = cache_enable && cache_valid && tag_match;

    logic [31:0] data;
    logic        data_ready;

    always_ff @(posedge HCLK) begin
        data <= data_array[req_index][req_word];
        data_ready <= cache_hit;
    end

    always_comb begin
        if (data_ready) begin
            cpu_data = data;
            cpu_ready = 1'b1;
        end
        else begin
            cpu_data = HRDATA;
            cpu_ready = (fetch_addr == cpu_addr) && HREADY;
        end
    end

    // AHB-Lite Master Outputs

    assign HSIZE = 3'b010; // 32-bit transfers
    assign HBURST = 3'b011; // INCR4

    logic [31:0] haddr4;
    assign haddr4 = HADDR + 4;

    always_ff @(posedge HCLK) begin
        if (!HRESETn) begin
            fetch_addr <= '0;
            HADDR  <= '0;
            HTRANS <= HTRANS_IDLE;
        end
        else if (HREADY) begin
            if (!cache_hit) begin
                fetch_addr <= HADDR;
                HADDR  <= cpu_addr;
                HTRANS <= HTRANS_NONSEQ;
            end
            else begin
                if (HTRANS != HTRANS_BUSY) begin
                    fetch_addr <= HADDR;
                    HADDR  <= haddr4;
                end
                if (haddr4 - cpu_addr < 4*PREFETCH)
                    HTRANS <= HTRANS_SEQ;
                else
                    HTRANS <= HTRANS_BUSY;
            end
        end
    end

    //Cache Update Logic

    logic fetch_tag_match;
    logic [BLOCK_SIZE/4-1:0] valid_line;

    assign fetch_tag_match = (tag_array[fetch_index] == fetch_tag);

    always_comb begin
        valid_line = valid_array[fetch_index];
        if (!fetch_tag_match)
            valid_line = '0;
        valid_line[fetch_word] = 1'b1;
    end

    always_ff @(posedge HCLK) begin
        if (!HRESETn) begin
            // Initialize cache arrays
            for (int i = 0; i < NUM_BLOCKS; i++) begin
                valid_array[i] <= '0;
                tag_array[i] <= '0;
                data_array[i] <= '0;
            end
        end
        else if (HREADY && fetch_addr != '0) begin
            if (!fetch_tag_match) begin
                tag_array[fetch_index] <= fetch_tag;
            end
            valid_array[fetch_index] <= valid_line;
            data_array[fetch_index][fetch_word] <= HRDATA;
        end
    end

endmodule

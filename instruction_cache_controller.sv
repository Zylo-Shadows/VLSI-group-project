module instruction_cache_controller #(
    parameter CACHE_SIZE = 1024,
    parameter BLOCK_SIZE = 16
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
    input  logic        HRESP
    
    // CPU Interface
    input  logic [31:0] cpu_addr,
    input  logic        cpu_req,
    output logic [31:0] cpu_data,
    output logic        cpu_ready,

    // Cache Control
    input  logic        cache_enable,
    input  logic        cache_flush,
    output logic        cache_hit,
    output logic        cache_miss
);

    localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;
    localparam BLOCK_OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam INDEX_BITS = $clog2(NUM_BLOCKS);
    localparam TAG_BITS = 32 - INDEX_BITS - BLOCK_OFFSET_BITS;

    // AHB-Lite Transaction Types
    localparam [1:0] HTRANS_IDLE   = 2'b00;
    localparam [1:0] HTRANS_NONSEQ = 2'b10;
    localparam [1:0] HTRANS_SEQ    = 2'b11;

    // Cache States
    typedef enum logic [2:0] {
        IDLE,
        TAG_CHECK,
        FETCH_SINGLE,
        FLUSH_CACHE
    } cache_state_t;

    cache_state_t current_state, next_state;

    // Cache Memory Arrays
    logic           [TAG_BITS-1:0] tag_array   [NUM_BLOCKS-1:0];
    logic [BLOCK_SIZE/4-1:0][31:0] data_array  [NUM_BLOCKS-1:0];
    logic                          valid_array [NUM_BLOCKS-1:0];

    // Address Parsing
    logic [TAG_BITS-1:0]    req_tag;
    logic [INDEX_BITS-1:0]  req_index;
    logic [BLOCK_OFFSET_BITS-1:0] req_offset;
    logic [1:0]             word_select;

    assign {req_tag, req_index, req_offset} = cpu_addr;
    assign word_select = req_offset[BLOCK_OFFSET_BITS-1:2];

    // Cache Lookup
    logic tag_match;
    logic cache_valid;

    assign tag_match = (tag_array[req_index] == req_tag);
    assign cache_valid = valid_array[req_index];

    // Hit/Miss Logic
    assign cache_hit = cache_enable && cache_valid && tag_match && (current_state == TAG_CHECK);
    assign cache_miss = cache_enable && (!cache_valid || !tag_match) && (current_state == TAG_CHECK);

    assign cpu_data = data_array[req_index][word_select];

    logic [31:0] prev_addr;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            prev_addr <= 32'h0;
        end else if (current_state == FETCH_SINGLE && HREADY) begin
            prev_addr <= cpu_addr;
        end
    end

    //Sequential Transaction Detection
    logic is_sequential;
    assign is_sequential = (cpu_addr == prev_addr + 4) && (current_state == FETCH_SINGLE) && (prev_addr != 32'h0);

    //State Machine
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (cache_flush)
                    next_state = FLUSH_CACHE;
                else if (cpu_req && cache_enable)
                    next_state = TAG_CHECK;
            end
            
            TAG_CHECK: begin
                if (cache_hit)
                    next_state = IDLE;
                else if (cache_miss)
                    next_state = FETCH_SINGLE;
                else
                    next_state = IDLE;
            end
            
            FETCH_SINGLE: begin
                if (HREADY)
                    next_state = IDLE;
            end
            
            FLUSH_CACHE: begin
                next_state = IDLE;
            end

        endcase
    end

    // AHB-Lite Master Outputs
    always_comb begin
        // Default values
        HADDR = cpu_addr;
        HTRANS = HTRANS_IDLE;
        HSIZE = 3'b010; // 32-bit transfers
        HBURST = 3'b011; // INCR4
        
        if (current_state == FETCH_SINGLE) begin
            if (is_sequential) begin
                HTRANS = HTRANS_SEQ; //Sequential transaction
            end else begin
                HTRANS = HTRANS_NONSEQ; //Non-sequential transaction
            end
        end
    end

    // CPU Ready Signal
    always_comb begin
        cpu_ready = 1'b0;
        
        case (current_state)
            IDLE: begin
                cpu_ready = !cpu_req || !cache_enable;
            end
            
            TAG_CHECK: begin
                cpu_ready = cache_hit;
            end
            
            FETCH_SINGLE: begin
                cpu_ready = HREADY;
            end

            FLUSH_CACHE: begin
                cpu_ready = HREADY;
            end
        endcase
    end

    //Cache Update Logic
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            // Initialize cache arrays
            for (int i = 0; i < NUM_BLOCKS; i++) begin
                valid_array[i] <= 1'b0;
                tag_array[i] <= '0;
                data_array[i] <= '0;
            end
        end else begin
            // Handle cache flush
            if (current_state == FLUSH_CACHE) begin
                for (int i = 0; i < NUM_BLOCKS; i++) begin
                    valid_array[i] <= 1'b0;
                end
            end
            
            // Update cache on fetch completion
            if (current_state == FETCH_SINGLE && HREADY) begin
                tag_array[req_index] <= req_tag;
                data_array[req_index][word_select] <= HRDATA;
                valid_array[req_index] <= 1'b1;
            end
        end
    end

endmodule

module instruction_cache_controller (
    // AHB-Lite Clock and Reset
    input  logic        HCLK,
    input  logic        HRESETn,
    
    // AHB-Lite Master Interface (to memory)
    output logic [31:0] HADDR,
    input  logic [31:0] HRDATA,
    output logic [1:0]  HTRANS,
    input  logic        HREADY,
    output logic [2:0]  HSIZE,
    
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

    // Cache Parameters
    localparam CACHE_SIZE = 1024;      // 1KB cache
    localparam BLOCK_SIZE = 16;        // 16 bytes per block
    localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;  // 64 blocks
    localparam BLOCK_OFFSET_BITS = 4;  // log2(16)
    localparam INDEX_BITS = 6;         // log2(64)
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
    logic [TAG_BITS-1:0]    tag_array [NUM_BLOCKS-1:0];
    logic [127:0]           data_array [NUM_BLOCKS-1:0];  // 16 bytes per block
    logic                   valid_array [NUM_BLOCKS-1:0];

    // Address Parsing
    logic [TAG_BITS-1:0]    req_tag;
    logic [INDEX_BITS-1:0]  req_index;
    logic [BLOCK_OFFSET_BITS-1:0] req_offset;
    logic [1:0]             word_select;

    assign {req_tag, req_index, req_offset} = cpu_addr;
    assign word_select = req_offset[3:2];

    // Cache Lookup
    logic tag_match;
    logic cache_valid;
    logic [127:0] cache_block_data;

    assign tag_match = (tag_array[req_index] == req_tag);
    assign cache_valid = valid_array[req_index];
    assign cache_block_data = data_array[req_index];

    // Hit/Miss Logic
    assign cache_hit = cache_enable && cache_valid && tag_match && (current_state == TAG_CHECK);
    assign cache_miss = cache_enable && (!cache_valid || !tag_match) && (current_state == TAG_CHECK);

    // Output Data Mux
    always_comb begin
        case (word_select)
            2'b00: cpu_data = cache_block_data[31:0];
            2'b01: cpu_data = cache_block_data[63:32];
            2'b10: cpu_data = cache_block_data[95:64];
            2'b11: cpu_data = cache_block_data[127:96];
        endcase
    end

    //Sequential Transaction Detection
    logic [31:0] prev_addr;
    logic is_sequential;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            prev_addr <= 32'h0;
        end else if (current_state == FETCH_SINGLE && HREADY) begin
            prev_addr <= cpu_addr;
        end
    end

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
                data_array[req_index] <= HRDATA;
                valid_array[req_index] <= 1'b1;
            end
        end
    end

endmodule

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
    localparam [1:0] HTRANS_BUSY   = 2'b01;
    localparam [1:0] HTRANS_NONSEQ = 2'b10;
    localparam [1:0] HTRANS_SEQ    = 2'b11;

    // Cache States
    typedef enum logic [2:0] {
        IDLE,
        TAG_CHECK,
        FETCH_ADDR,
        FETCH_DATA,
        UPDATE_CACHE,
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

    // Fetch Counter for burst reads
    logic [1:0] fetch_count;
    logic [31:0] fetch_addr;

    // State Machine
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            current_state <= IDLE;
            fetch_count <= 2'b00;
            fetch_addr <= 32'h0;
        end else begin
            current_state <= next_state;
            
            if (current_state == FETCH_ADDR) begin
                fetch_addr <= {cpu_addr[31:4], 4'b0000};  // Align to 16-byte boundary
                fetch_count <= 2'b00;
            end else if (current_state == FETCH_DATA && HREADY) begin
                fetch_count <= fetch_count + 1;
            end
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
                    next_state = FETCH_ADDR;
                else
                    next_state = IDLE;
            end
            
            FETCH_ADDR: begin
                next_state = FETCH_DATA;
            end
            
            FETCH_DATA: begin
                if (HREADY && fetch_count == 2'b11)
                    next_state = UPDATE_CACHE;
            end
            
            UPDATE_CACHE: begin
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
        HADDR = 32'h0;
        HTRANS = HTRANS_IDLE;
        HSIZE = 3'b010; // 32-bit transfers
        
        case (current_state)
            FETCH_ADDR: begin
                HADDR = fetch_addr;
                HTRANS = HTRANS_NONSEQ;
            end
            
            FETCH_DATA: begin
                HADDR = fetch_addr + (fetch_count << 2);
                if (fetch_count == 2'b00)
                    HTRANS = HTRANS_NONSEQ;
                else
                    HTRANS = HTRANS_SEQ;
            end
            
            default: begin
                HTRANS = HTRANS_IDLE;
            end
        endcase
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
            
            UPDATE_CACHE: begin
                cpu_ready = 1'b1;
            end
        endcase
    end

    // Cache Update Logic
    logic [127:0] fetch_buffer;
    
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            // Initialize cache arrays
            for (int i = 0; i < NUM_BLOCKS; i++) begin
                valid_array[i] <= 1'b0;
                tag_array[i] <= '0;
                data_array[i] <= '0;
            end
            fetch_buffer <= '0;
        end else begin
            // Handle cache flush
            if (current_state == FLUSH_CACHE) begin
                for (int i = 0; i < NUM_BLOCKS; i++) begin
                    valid_array[i] <= 1'b0;
                end
            end
            
            // Collect fetched data
            if (current_state == FETCH_DATA && HREADY) begin
                case (fetch_count)
                    2'b00: fetch_buffer[31:0] <= HRDATA;
                    2'b01: fetch_buffer[63:32] <= HRDATA;
                    2'b10: fetch_buffer[95:64] <= HRDATA;
                    2'b11: fetch_buffer[127:96] <= HRDATA;
                endcase
            end
            
            // Update cache on fetch completion
            if (current_state == UPDATE_CACHE) begin
                tag_array[req_index] <= req_tag;
                data_array[req_index] <= fetch_buffer;
                valid_array[req_index] <= 1'b1;
            end
        end
    end

    // Debug/Status outputs (optional)
    `ifdef DEBUG
    always_ff @(posedge HCLK) begin
        if (cache_hit)
            $display("Cache HIT: addr=0x%08h, data=0x%08h", cpu_addr, cpu_data);
        if (cache_miss)
            $display("Cache MISS: addr=0x%08h", cpu_addr);
    end
    `endif

endmodule

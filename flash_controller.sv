// RapidGPT-generated
module flash_controller (
    // Clock and Reset
    input  logic        clk,
    input  logic        rst_n,
    
    // AHB-Lite Interface
    input  logic [31:0] haddr,
    input  logic [2:0]  hburst,
    input  logic        hmastlock,
    input  logic [3:0]  hprot,
    input  logic [2:0]  hsize,
    input  logic [1:0]  htrans,
    input  logic [31:0] hwdata,
    input  logic        hwrite,
    input  logic        hsel,
    input  logic        hready,
    output logic [31:0] hrdata,
    output logic        hreadyout,
    output logic [1:0]  hresp,
    
    // I2C Interface
    input  logic        scl,
    inout  logic        sda,
    
    // Flash Memory Interface
    output logic [23:0] flash_addr,
    output logic [31:0] flash_wdata,
    input  logic [31:0] flash_rdata,
    output logic        flash_we,
    output logic        flash_oe,
    output logic        flash_ce,
    input  logic        flash_ready
);

    // Internal signals
    logic [31:0] addr_reg;
    logic [31:0] data_reg;
    logic        write_reg;
    logic        ahb_active;
    logic        flash_busy;
    
    // I2C Controller signals
    logic        i2c_start;
    logic        i2c_stop;
    logic        i2c_ack;
    logic [7:0]  i2c_data_rx;
    logic [7:0]  i2c_data_tx;
    logic        i2c_data_valid;
    logic        i2c_write_enable;
    logic [23:0] i2c_flash_addr;
    logic [31:0] i2c_flash_data;
    logic        i2c_mode;
    
    // State machine for AHB transactions
    typedef enum logic [2:0] {
        IDLE,
        ADDR_PHASE,
        DATA_PHASE,
        WAIT_FLASH,
        ERROR
    } ahb_state_t;
    
    ahb_state_t ahb_state, ahb_next_state;
    
    // AHB State Machine
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ahb_state <= IDLE;
        end else begin
            ahb_state <= ahb_next_state;
        end
    end
    
    always_comb begin
        ahb_next_state = ahb_state;
        case (ahb_state)
            IDLE: begin
                if (hsel && hready && (htrans == 2'b10 || htrans == 2'b11)) begin
                    ahb_next_state = ADDR_PHASE;
                end
            end
            ADDR_PHASE: begin
                ahb_next_state = DATA_PHASE;
            end
            DATA_PHASE: begin
                if (flash_ready) begin
                    ahb_next_state = IDLE;
                end else begin
                    ahb_next_state = WAIT_FLASH;
                end
            end
            WAIT_FLASH: begin
                if (flash_ready) begin
                    ahb_next_state = IDLE;
                end
            end
            ERROR: begin
                ahb_next_state = IDLE;
            end
        endcase
    end
    
    // Address and control capture
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            addr_reg <= 32'h0;
            write_reg <= 1'b0;
            ahb_active <= 1'b0;
        end else begin
            if (ahb_state == ADDR_PHASE) begin
                addr_reg <= haddr;
                write_reg <= hwrite;
                ahb_active <= 1'b1;
            end else if (ahb_state == IDLE) begin
                ahb_active <= 1'b0;
            end
        end
    end
    
    // Data capture for writes
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            data_reg <= 32'h0;
        end else begin
            if (ahb_state == DATA_PHASE && write_reg) begin
                data_reg <= hwdata;
            end
        end
    end
    
    // Flash interface control
    assign flash_addr = i2c_mode ? i2c_flash_addr : addr_reg[23:0];
    assign flash_wdata = i2c_mode ? i2c_flash_data : data_reg;
    assign flash_we = i2c_mode ? i2c_write_enable : (ahb_state == DATA_PHASE && write_reg && !i2c_mode);
    assign flash_oe = i2c_mode ? 1'b0 : (ahb_state == DATA_PHASE && !write_reg);
    assign flash_ce = i2c_mode ? i2c_write_enable : ahb_active;
    
    // AHB response generation
    assign hreadyout = (ahb_state == IDLE) || (ahb_state == DATA_PHASE && flash_ready) || (ahb_state == WAIT_FLASH && flash_ready);
    assign hresp = 2'b00; // OKAY response
    assign hrdata = flash_rdata;
    
    // I2C Controller Instance
    i2c_flash_loader i2c_loader (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .flash_addr(i2c_flash_addr),
        .flash_data(i2c_flash_data),
        .flash_write_enable(i2c_write_enable),
        .i2c_mode(i2c_mode)
    );

endmodule

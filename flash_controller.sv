// RapidGPT-generated
module flash_controller #(
    parameter FLASH_SIZE = 32'h100000, // 1MB flash
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQ = 50000000
)(
    // Clock and Reset
    input  logic        clk,
    input  logic        rst_n,
    
    // Serial Interface (Bootloading)
    input  logic        serial_rx,
    output logic        serial_tx,
    input  logic        boot_mode,
    
    // AHB-Lite Interface
    input  logic        hsel,
    input  logic [31:0] haddr,
    input  logic [2:0]  hsize,
    input  logic [1:0]  htrans,
    input  logic        hwrite,
    input  logic [31:0] hwdata,
    input  logic        hready_in,
    output logic        hready_out,
    output logic [31:0] hrdata,
    output logic        hresp,
    
    // Flash Memory Interface
    output logic        flash_cs_n,
    output logic        flash_sck,
    output logic        flash_mosi,
    input  logic        flash_miso,
    output logic        flash_wp_n,
    output logic        flash_hold_n
);
    
    // Flash SPI Commands
    parameter CMD_READ      = 8'h03;
    parameter CMD_WRITE     = 8'h02;
    parameter CMD_WREN      = 8'h06;
    parameter CMD_WRDI      = 8'h04;
    parameter CMD_RDSR      = 8'h05;
    parameter CMD_WRSR      = 8'h01;
    parameter CMD_ERASE_4K  = 8'h20;
    parameter CMD_ERASE_64K = 8'h52;
    parameter CMD_CHIP_ERASE = 8'hC7;
    
    // State machines
    typedef enum logic [3:0] {
        IDLE,
        READ_CMD,
        WRITE_ENABLE,
        WRITE_CMD,
        ERASE_CMD,
        STATUS_CHECK,
        COMPLETE
    } flash_state_t;
    
    typedef enum logic [2:0] {
        SERIAL_IDLE,
        SERIAL_CMD,
        SERIAL_ADDR,
        SERIAL_DATA,
        SERIAL_RESP
    } serial_state_t;
    
    // Internal signals
    flash_state_t flash_state, flash_next_state;
    serial_state_t serial_state, serial_next_state;
    
    logic [31:0] flash_addr;
    logic [31:0] flash_data_in;
    logic [31:0] flash_data_out;
    logic flash_start;
    logic flash_write_en;
    logic flash_erase_en;
    logic flash_busy;
    logic flash_done;
    
    // AHB-Lite signals
    logic ahb_active;
    logic [31:0] ahb_addr_reg;
    logic ahb_write_reg;
    logic [31:0] ahb_wdata_reg;
    logic ahb_phase;
    
    // Serial interface signals
    logic [7:0] serial_rx_data;
    logic [7:0] serial_tx_data;
    logic serial_rx_valid;
    logic serial_tx_ready;
    logic serial_tx_valid;
    
    // SPI controller signals
    logic [7:0] spi_tx_data;
    logic [7:0] spi_rx_data;
    logic spi_start;
    logic spi_busy;
    logic spi_done;
    logic [5:0] bit_counter;
    logic [2:0] byte_counter;
    
    // Flash control registers
    logic [7:0] flash_status;
    logic write_in_progress;
    
    // UART for serial communication
    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx(serial_rx),
        .data(serial_rx_data),
        .valid(serial_rx_valid)
    );
    
    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx(serial_tx),
        .data(serial_tx_data),
        .valid(serial_tx_valid),
        .ready(serial_tx_ready)
    );
    
    // AHB-Lite Interface Logic
    assign ahb_active = hsel && htrans[1] && hready_in;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ahb_phase <= 1'b0;
            ahb_addr_reg <= 32'h0;
            ahb_write_reg <= 1'b0;
            ahb_wdata_reg <= 32'h0;
        end else begin
            if (ahb_active && !ahb_phase) begin
                ahb_phase <= 1'b1;
                ahb_addr_reg <= haddr;
                ahb_write_reg <= hwrite;
            end else if (ahb_phase && hready_out) begin
                ahb_phase <= 1'b0;
                if (ahb_write_reg)
                    ahb_wdata_reg <= hwdata;
            end
        end
    end
    
    // Flash operation control
    always_comb begin
        if (boot_mode) begin
            // Serial bootloading mode
            flash_addr = 32'h0; // Will be set by serial protocol
            flash_data_in = 32'h0; // Will be set by serial protocol
            flash_start = 1'b0; // Controlled by serial state machine
            flash_write_en = 1'b0;
            flash_erase_en = 1'b0;
        end else begin
            // AHB-Lite mode
            flash_addr = ahb_addr_reg;
            flash_data_in = ahb_wdata_reg;
            flash_start = ahb_phase && !flash_busy;
            flash_write_en = ahb_write_reg;
            flash_erase_en = 1'b0; // Erase controlled separately
        end
    end
    
    // AHB-Lite response
    assign hready_out = !boot_mode ? (!ahb_phase || flash_done) : 1'b1;
    assign hrdata = flash_data_out;
    assign hresp = 1'b0; // OKAY response
    
    // Flash SPI Controller
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            flash_state <= IDLE;
            flash_cs_n <= 1'b1;
            flash_sck <= 1'b0;
            flash_mosi <= 1'b0;
            flash_wp_n <= 1'b1;
            flash_hold_n <= 1'b1;
            spi_busy <= 1'b0;
            bit_counter <= 6'h0;
            byte_counter <= 3'h0;
            flash_done <= 1'b0;
            flash_data_out <= 32'h0;
        end else begin
            flash_state <= flash_next_state;
            
            case (flash_state)
                IDLE: begin
                    flash_cs_n <= 1'b1;
                    flash_sck <= 1'b0;
                    spi_busy <= 1'b0;
                    flash_done <= 1'b0;
                    bit_counter <= 6'h0;
                    byte_counter <= 3'h0;
                end
                
                READ_CMD: begin
                    flash_cs_n <= 1'b0;
                    spi_busy <= 1'b1;
                    // Send read command and address
                    if (byte_counter == 0) spi_tx_data <= CMD_READ;
                    else if (byte_counter == 1) spi_tx_data <= flash_addr[23:16];
                    else if (byte_counter == 2) spi_tx_data <= flash_addr[15:8];
                    else if (byte_counter == 3) spi_tx_data <= flash_addr[7:0];
                    else flash_data_out[31:24] <= spi_rx_data;
                end
                
                WRITE_ENABLE: begin
                    flash_cs_n <= 1'b0;
                    spi_tx_data <= CMD_WREN;
                end
                
                WRITE_CMD: begin
                    flash_cs_n <= 1'b0;
                    if (byte_counter == 0) spi_tx_data <= CMD_WRITE;
                    else if (byte_counter == 1) spi_tx_data <= flash_addr[23:16];
                    else if (byte_counter == 2) spi_tx_data <= flash_addr[15:8];
                    else if (byte_counter == 3) spi_tx_data <= flash_addr[7:0];
                    else if (byte_counter == 4) spi_tx_data <= flash_data_in[31:24];
                    else if (byte_counter == 5) spi_tx_data <= flash_data_in[23:16];
                    else if (byte_counter == 6) spi_tx_data <= flash_data_in[15:8];
                    else if (byte_counter == 7) spi_tx_data <= flash_data_in[7:0];
                end
                
                STATUS_CHECK: begin
                    flash_cs_n <= 1'b0;
                    if (byte_counter == 0) spi_tx_data <= CMD_RDSR;
                    else flash_status <= spi_rx_data;
                end
                
                COMPLETE: begin
                    flash_cs_n <= 1'b1;
                    flash_done <= 1'b1;
                    spi_busy <= 1'b0;
                end
            endcase
            
            // SPI bit-level control
            if (spi_busy) begin
                if (bit_counter < 8) begin
                    flash_sck <= ~flash_sck;
                    if (flash_sck) begin
                        flash_mosi <= spi_tx_data[7-bit_counter];
                        bit_counter <= bit_counter + 1;
                    end else begin
                        spi_rx_data[7-bit_counter] <= flash_miso;
                    end
                end else begin
                    bit_counter <= 0;
                    byte_counter <= byte_counter + 1;
                end
            end
        end
    end
    
    // Flash state machine
    always_comb begin
        flash_next_state = flash_state;
        
        case (flash_state)
            IDLE: begin
                if (flash_start) begin
                    if (flash_write_en)
                        flash_next_state = WRITE_ENABLE;
                    else
                        flash_next_state = READ_CMD;
                end
            end
            
            READ_CMD: begin
                if (byte_counter >= 8)
                    flash_next_state = COMPLETE;
            end
            
            WRITE_ENABLE: begin
                if (byte_counter >= 1)
                    flash_next_state = WRITE_CMD;
            end
            
            WRITE_CMD: begin
                if (byte_counter >= 8)
                    flash_next_state = STATUS_CHECK;
            end
            
            STATUS_CHECK: begin
                if (byte_counter >= 2) begin
                    if (flash_status[0]) // Write in progress
                        flash_next_state = STATUS_CHECK;
                    else
                        flash_next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                flash_next_state = IDLE;
            end
        endcase
    end
    
    // Serial bootloader state machine (simplified)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            serial_state <= SERIAL_IDLE;
            serial_tx_valid <= 1'b0;
            serial_tx_data <= 8'h0;
        end else if (boot_mode) begin
            case (serial_state)
                SERIAL_IDLE: begin
                    if (serial_rx_valid) begin
                        serial_state <= SERIAL_CMD;
                        // Process received command
                    end
                end
                
                SERIAL_CMD: begin
                    // Handle bootloader commands
                    serial_tx_data <= 8'hAA; // ACK
                    serial_tx_valid <= 1'b1;
                    serial_state <= SERIAL_RESP;
                end
                
                SERIAL_RESP: begin
                    if (serial_tx_ready) begin
                        serial_tx_valid <= 1'b0;
                        serial_state <= SERIAL_IDLE;
                    end
                end
            endcase
        end
    end

endmodule

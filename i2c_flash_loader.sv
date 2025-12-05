// RapidGPT-generated
module i2c_flash_loader (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        scl,
    inout  logic        sda,
    output logic [23:0] flash_addr,
    output logic [31:0] flash_data,
    output logic        flash_write_enable,
    output logic        i2c_mode
);

    // I2C signals
    logic sda_in, sda_out, sda_oe;
    logic scl_sync, sda_sync;
    logic start_det, stop_det;
    logic [7:0] shift_reg;
    logic [3:0] bit_count;
    logic ack_bit;
    
    // Protocol state machine
    typedef enum logic [3:0] {
        I2C_IDLE,
        I2C_ADDR,
        I2C_ACK_ADDR,
        I2C_CMD,
        I2C_ACK_CMD,
        I2C_ADDR_HIGH,
        I2C_ACK_ADDR_HIGH,
        I2C_ADDR_MID,
        I2C_ACK_ADDR_MID,
        I2C_ADDR_LOW,
        I2C_ACK_ADDR_LOW,
        I2C_DATA,
        I2C_ACK_DATA,
        I2C_WRITE_FLASH
    } i2c_state_t;
    
    i2c_state_t i2c_state, i2c_next_state;
    
    // Flash programming registers
    logic [23:0] target_addr;
    logic [31:0] write_data;
    logic [1:0]  byte_count;
    logic        programming_mode;
    
    // SDA bidirectional control
    assign sda = sda_oe ? sda_out : 1'bz;
    assign sda_in = sda;
    
    // Synchronizers for I2C signals
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            scl_sync <= 1'b1;
            sda_sync <= 1'b1;
        end else begin
            scl_sync <= scl;
            sda_sync <= sda_in;
        end
    end
    
    // Start and stop detection
    logic scl_sync_d, sda_sync_d;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            scl_sync_d <= 1'b1;
            sda_sync_d <= 1'b1;
        end else begin
            scl_sync_d <= scl_sync;
            sda_sync_d <= sda_sync;
        end
    end
    
    assign start_det = scl_sync && scl_sync_d && sda_sync_d && !sda_sync;
    assign stop_det = scl_sync && scl_sync_d && !sda_sync_d && sda_sync;
    
    // I2C state machine
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            i2c_state <= I2C_IDLE;
        end else begin
            i2c_state <= i2c_next_state;
        end
    end
    
    always_comb begin
        i2c_next_state = i2c_state;
        case (i2c_state)
            I2C_IDLE: begin
                if (start_det) begin
                    i2c_next_state = I2C_ADDR;
                end
            end
            I2C_ADDR: begin
                if (bit_count == 4'd8) begin
                    i2c_next_state = I2C_ACK_ADDR;
                end
            end
            I2C_ACK_ADDR: begin
                if (shift_reg[7:1] == 7'h50) begin // I2C address for flash programming
                    i2c_next_state = I2C_CMD;
                end else begin
                    i2c_next_state = I2C_IDLE;
                end
            end
            I2C_CMD: begin
                if (bit_count == 4'd8) begin
                    i2c_next_state = I2C_ACK_CMD;
                end
            end
            I2C_ACK_CMD: begin
                i2c_next_state = I2C_ADDR_HIGH;
            end
            I2C_ADDR_HIGH: begin
                if (bit_count == 4'd8) begin
                    i2c_next_state = I2C_ACK_ADDR_HIGH;
                end
            end
            I2C_ACK_ADDR_HIGH: begin
                i2c_next_state = I2C_ADDR_MID;
            end
            I2C_ADDR_MID: begin
                if (bit_count == 4'd8) begin
                    i2c_next_state = I2C_ACK_ADDR_MID;
                end
            end
            I2C_ACK_ADDR_MID: begin
                i2c_next_state = I2C_ADDR_LOW;
            end
            I2C_ADDR_LOW: begin
                if (bit_count == 4'd8) begin
                    i2c_next_state = I2C_ACK_ADDR_LOW;
                end
            end
            I2C_ACK_ADDR_LOW: begin
                i2c_next_state = I2C_DATA;
            end
            I2C_DATA: begin
                if (bit_count == 4'd8) begin
                    i2c_next_state = I2C_ACK_DATA;
                end
            end
            I2C_ACK_DATA: begin
                if (byte_count == 2'd3) begin
                    i2c_next_state = I2C_WRITE_FLASH;
                end else begin
                    i2c_next_state = I2C_DATA;
                end
            end
            I2C_WRITE_FLASH: begin
                i2c_next_state = I2C_DATA;
            end
        endcase
        
        if (stop_det) begin
            i2c_next_state = I2C_IDLE;
        end
    end
    
    // Bit counter and shift register
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 4'd0;
            shift_reg <= 8'h00;
        end else begin
            if (start_det || stop_det) begin
                bit_count <= 4'd0;
                shift_reg <= 8'h00;
            end else if (scl_sync && !scl_sync_d) begin // Rising edge of SCL
                if (i2c_state == I2C_ADDR || i2c_state == I2C_CMD || 
                    i2c_state == I2C_ADDR_HIGH || i2c_state == I2C_ADDR_MID || 
                    i2c_state == I2C_ADDR_LOW || i2c_state == I2C_DATA) begin
                    shift_reg <= {shift_reg[6:0], sda_sync};
                    bit_count <= bit_count + 1;
                end
            end else if (!scl_sync && scl_sync_d) begin // Falling edge of SCL
                if (i2c_state == I2C_ACK_ADDR || i2c_state == I2C_ACK_CMD || 
                    i2c_state == I2C_ACK_ADDR_HIGH || i2c_state == I2C_ACK_ADDR_MID || 
                    i2c_state == I2C_ACK_ADDR_LOW || i2c_state == I2C_ACK_DATA) begin
                    bit_count <= 4'd0;
                end
            end
        end
    end
    
    // Address and data capture
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            target_addr <= 24'h000000;
            write_data <= 32'h00000000;
            byte_count <= 2'd0;
            programming_mode <= 1'b0;
        end else begin
            case (i2c_state)
                I2C_ACK_CMD: begin
                    programming_mode <= (shift_reg == 8'h02); // Program command
                end
                I2C_ACK_ADDR_HIGH: begin
                    target_addr[23:16] <= shift_reg;
                end
                I2C_ACK_ADDR_MID: begin
                    target_addr[15:8] <= shift_reg;
                end
                I2C_ACK_ADDR_LOW: begin
                    target_addr[7:0] <= shift_reg;
                    byte_count <= 2'd0;
                end
                I2C_ACK_DATA: begin
                    case (byte_count)
                        2'd0: write_data[31:24] <= shift_reg;
                        2'd1: write_data[23:16] <= shift_reg;
                        2'd2: write_data[15:8] <= shift_reg;
                        2'd3: write_data[7:0] <= shift_reg;
                    endcase
                    byte_count <= byte_count + 1;
                end
                I2C_WRITE_FLASH: begin
                    target_addr <= target_addr + 24'd4; // Auto-increment for next word
                    byte_count <= 2'd0;
                end
            endcase
            
            if (stop_det) begin
                programming_mode <= 1'b0;
            end
        end
    end
    
    // SDA output control
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sda_out <= 1'b1;
            sda_oe <= 1'b0;
        end else begin
            case (i2c_state)
                I2C_ACK_ADDR, I2C_ACK_CMD, I2C_ACK_ADDR_HIGH, 
                I2C_ACK_ADDR_MID, I2C_ACK_ADDR_LOW, I2C_ACK_DATA: begin
                    sda_out <= 1'b0; // ACK
                    sda_oe <= 1'b1;
                end
                default: begin
                    sda_oe <= 1'b0;
                end
            endcase
        end
    end
    
    // Output assignments
    assign flash_addr = target_addr;
    assign flash_data = write_data;
    assign flash_write_enable = (i2c_state == I2C_WRITE_FLASH) && programming_mode;
    assign i2c_mode = programming_mode;

endmodule

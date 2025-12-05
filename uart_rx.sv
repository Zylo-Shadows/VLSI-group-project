// RapidGPT-generated
module uart_rx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    output logic [7:0] data,
    output logic       valid
);
    
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    
    logic [15:0] baud_counter;
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;
    logic rx_sync, rx_prev;
    
    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } rx_state_t;
    
    rx_state_t rx_state;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            baud_counter <= 16'h0;
            bit_counter <= 4'h0;
            shift_reg <= 8'h0;
            data <= 8'h0;
            valid <= 1'b0;
            rx_sync <= 1'b1;
            rx_prev <= 1'b1;
        end else begin
            rx_sync <= rx;
            rx_prev <= rx_sync;
            valid <= 1'b0;
            
            case (rx_state)
                RX_IDLE: begin
                    if (rx_prev && !rx_sync) begin // Start bit detected
                        rx_state <= RX_START;
                        baud_counter <= BAUD_DIV / 2;
                    end
                end
                
                RX_START: begin
                    if (baud_counter == 0) begin
                        rx_state <= RX_DATA;
                        baud_counter <= BAUD_DIV;
                        bit_counter <= 4'h0;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                RX_DATA: begin
                    if (baud_counter == 0) begin
                        shift_reg <= {rx_sync, shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                        baud_counter <= BAUD_DIV;
                        if (bit_counter == 7)
                            rx_state <= RX_STOP;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                RX_STOP: begin
                    if (baud_counter == 0) begin
                        data <= shift_reg;
                        valid <= 1'b1;
                        rx_state <= RX_IDLE;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
            endcase
        end
    end
    
endmodule

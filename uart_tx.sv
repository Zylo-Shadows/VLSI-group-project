// RapidGPT-generated
module uart_tx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  logic       clk,
    input  logic       rst_n,
    output logic       tx,
    input  logic [7:0] data,
    input  logic       valid,
    output logic       ready
);
    
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    
    logic [15:0] baud_counter;
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;
    
    typedef enum logic [1:0] {
        TX_IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_t;
    
    tx_state_t tx_state;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx <= 1'b1;
            baud_counter <= 16'h0;
            bit_counter <= 4'h0;
            shift_reg <= 8'h0;
            ready <= 1'b1;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx <= 1'b1;
                    ready <= 1'b1;
                    if (valid) begin
                        shift_reg <= data;
                        tx_state <= TX_START;
                        baud_counter <= BAUD_DIV;
                        ready <= 1'b0;
                    end
                end
                
                TX_START: begin
                    tx <= 1'b0; // Start bit
                    if (baud_counter == 0) begin
                        tx_state <= TX_DATA;
                        baud_counter <= BAUD_DIV;
                        bit_counter <= 4'h0;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                TX_DATA: begin
                    tx <= shift_reg[0];
                    if (baud_counter == 0) begin
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                        baud_counter <= BAUD_DIV;
                        if (bit_counter == 7)
                            tx_state <= TX_STOP;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                TX_STOP: begin
                    tx <= 1'b1; // Stop bit
                    if (baud_counter == 0) begin
                        tx_state <= TX_IDLE;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
            endcase
        end
    end
    
endmodule

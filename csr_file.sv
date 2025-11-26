module csr_file (
    input logic clk,
    input logic rst_n,

    //CSR instruction interface
    input logic csr_valid,
    input logic [11:0] csr_addr,
    input logic [2:0] csr_funct3,
    input logic [4:0] csr_rs1,
    input logic [4:0] csr_rd,
    input logic [31:0] csr_wdata,
    input logic [4:0] csr_zimm,

    output logic [31:0] csr_rdata,
    output logic  [1:0] dsp_mode
);

    logic [63:0] cycle_count;

    //CSR Address Definitions
    localparam RDCYCLE =    12'hC00; //Cycle counter lower 32 bits
    localparam RDCYCLEH =   12'hC80; //Cycle counter upper 32 bits
    localparam DSPMODE  =   12'h800; //DSP mode

    //CSR Func3 codes
    localparam CSRRW  = 3'b001;
    localparam CSRRS  = 3'b010;
    localparam CSRRC  = 3'b011;
    localparam CSRRWI = 3'b101;
    localparam CSRRSI = 3'b110;
    localparam CSRRCI = 3'b111;

    //CSR operation decode
    logic csr_write_en;
    logic csr_read_en;
    logic [31:0] csr_write_data;
    logic [31:0] csr_current_value;

    //CSR read data mux
    always_comb begin
        csr_current_value = 32'hC0;
        if (csr_valid) begin
            case (csr_addr)
                RDCYCLE:    csr_current_value = cycle_count[31:0];
                RDCYCLEH:   csr_current_value = cycle_count[63:32];
                DSPMODE:    csr_current_value = {30'b0, dsp_mode};
                default:    csr_current_value = 32'h0;
            endcase
        end
    end

    //CSR operation decode and write data and write data generation
    always_comb begin
        csr_write_en   = 1'b0;
        csr_read_en    = 1'b0;
        csr_write_data = 32'h0;

        case (csr_funct3)
            CSRRW: begin
                csr_read_en    = (csr_rd != 5'b0);
                csr_write_en   = 1'b1;
                csr_write_data = csr_wdata;
            end

            CSRRS: begin
                csr_read_en    = 1'b1;
                csr_write_en   = (csr_rs1 != 5'b0);
                csr_write_data = csr_current_value | csr_wdata;
            end

            CSRRC: begin
                csr_read_en    = 1'b1;
                csr_write_en   = (csr_rs1 != 5'b0);
                csr_write_data = csr_current_value & ~csr_wdata;
            end

            CSRRWI: begin
                csr_read_en    = (csr_rd != 5'b0);
                csr_write_en   = 1'b1;
                csr_write_data = {27'b0, csr_zimm};
            end

            CSRRSI: begin
                csr_read_en    = 1'b1;
                csr_write_en   = (csr_zimm != 5'b0);
                csr_write_data = csr_current_value | {27'b0, csr_zimm};
            end

            CSRRCI: begin
                csr_read_en    = 1'b1;
                csr_write_en   = (csr_zimm != 5'b0);
                csr_write_data = csr_current_value & ~{27'b0, csr_zimm};
            end

            default:;
        endcase

        if (!csr_valid) begin
            csr_write_en   = 1'b0;
            csr_read_en    = 1'b0;
        end
    end

    //CSR read data output
    assign csr_rdata = csr_read_en ? csr_current_value : 32'h0;

    //Counter updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)begin
            cycle_count   <= 64'h0;
        end else begin
            //Cycle counter increments every clock cycle
            cycle_count <= cycle_count + 64'h1;

            //Handle CSR writes
            if (csr_write_en) begin
                case (csr_addr)
                    DSPMODE: begin
                        dsp_mode <= csr_write_data[1:0];
                    end
                endcase
            end
        end
    end
                
endmodule
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
    output logic        csr_exception,

    //Counter inputs
    input logic         retire_inst, //Instruction retire signal
    input logic [63:0]  wall_time,   //Wall-clock time from external source

    //Debug/Performance
    output logic [63:0] cycle_count,    //Counts clock cycles
    output logic [63:0] instret_count,  //Counts number of retired instructions
    output logic [63:0] time_count      //Counts wall-clock real time (How long a process takes)
);

    //CSR Address Definitions
    localparam RDCYCLE =    12'hC00; //Cycle counter lower 32 bits
    localparam RDCYCLEH =   12'hC80; //Cycle counter upper 32 bits
    localparam RDTIME =     12'hC01; //Timer lower 32 bits
    localparam RDTIMEH =    12'hC81; //Timer upper 32 bits
    localparam RDINSTRET =  12'hC02; //Number of instructions retired lower 32 bits
    localparam RDINSTRETH = 12'hC82; //Numer of instructions retired upper 32 bits

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
    logic csr_addr_valid;

    //Address validation
    always_comb begin
        case (csr_addr)
            RDCYCLE, RDCYCLEH, RDTIME, RDTIMEH,
            RDINSTRET, RDINSTRETH: csr_addr_valid = 1'b1;
            default: csr_addr_valid = 1'b0;
        endcase 
    end

    //CSR read data mux
    always_comb begin
        csr_current_value = 32'hC0;
        case (csr_addr)
            RDCYCLE:    csr_current_value = cycle_count[31:0];
            RDCYCLEH:   csr_current_value = cycle_count[63:32];
            RDTIME:     csr_current_value = wall_time[31:0];
            RDTIMEH:    csr_current_value = wall_time[63:32];
            RDINSTRET:  csr_current_value = instret_count[31:0];
            RDINSTRETH: csr_current_value = instret_count[63:32];
            default: csr_current_value = 32'h0;
        endcase
    end

    //CSR operation decode and write data and write data generation
    always_comb begin
        csr_write_en   = 1'b0;
        csr_read_en    = 1'b0;
        csr_write_data = 32'h0;
        csr_exception  = 1'b0;

        if (csr_valid) begin
            if(!csr_addr_valid) begin
                csr_exception = 1'b1;
                end else begin
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

                        default: begin
                            csr_exception  = 1'b1;
                        end
                    endcase

                    //Check for writes to read-only CSRs
                    if(csr_write_en) begin
                        case(csr_addr)
                            RDTIME, RDTIMEH: begin
                                csr_exception = 1'b1;
                            end
                        endcase
                    end
                end
            end
        end

    //CSR read data output
    assign csr_rdata = csr_read_en ? csr_current_value : 32'h0;

    //Counter updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)begin
            cycle_count   <= 64'h0;
            instret_count <= 64'h0;
        end else begin
            //Cycle counter increments every clock cycle
            cycle_count <= cycle_count + 64'h1;

            //Instruction retirement counter
            if(retire_inst) begin
                instret_count <= instret_count + 64'h1;
            end

            //Handle CSR writes
            if ( csr_valid && csr_write_en && !csr_exception) begin
                case (csr_addr)
                    RDCYCLE: begin
                        cycle_count[31:0]  <= csr_write_data;
                    end

                    RDCYCLEH: begin
                        cycle_count[63:32] <= csr_write_data;
                    end

                    RDINSTRET: begin
                        instret_count[31:0]  <= csr_write_data;
                    end

                    RDINSTRETH: begin
                        instret_count[63:32] <= csr_write_data;
                    end
                endcase
            end
        end
    end

    //Time counter is just a pass-through
    assign time_count = wall_time;
                
endmodule
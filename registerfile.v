module register_file (
    input  wire        clk,
    input  wire        rst,  
    input  wire [4:0]  rs1_addr,  
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    output reg [31:0] rs1_data, 
    output reg [31:0] rs2_data
);

    // 32 regist
    reg [31:0] regfile [0:31];
    integer i;

 
  // Synchronous
 
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
             regfile[i] <= 32'd0;
        end else begin
          // Write on positive edge of clock if rd_addr != 0
            if (rd_addr != 5'd0)
              regfile[rd_addr] <= rd_data;
        end
    end

    
//logic
 
    always @(*) begin
        // rs1_data
        if (rs1_addr == 5'd0)
            rs1_data = 32'd0;
        else
            rs1_data = regfile[rs1_addr];

        // rs2_data
        if (rs2_addr == 5'd0)
            rs2_data = 32'd0;
        else
            rs2_data = regfile[rs2_addr];
    end

endmodule

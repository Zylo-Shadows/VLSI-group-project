
`timescale 1ns/1ps

module conv33_tb;
  localparam int W_in  = 252; // width at input
  localparam int W_out = 250; // width at output
  localparam int N  = W_in * W_in; // number of pixels in array

  // DUT IO
  logic clk, rst_n, shift_en;
  logic signed [7:0] pix_top, pix_mid, pix_bot;
  logic [1:0] mode;
  logic [7:0] pixel_out;

  // Memories
  logic [7:0] p     [0:N-1];  // input hex file
  logic [7:0] outm  [0:W_out * W_out-1]; // output hex file

  // DUT
  conv33 #(.PIXEL_WIDTH(8)) dut (
    .clk(clk), .rst_n(rst_n),
    .shift_en(shift_en),
    .pix_top(pix_top), .pix_mid(pix_mid), .pix_bot(pix_bot),
    .mode(mode),
    .pixel_out(pixel_out)
  );

  // clock
  initial clk = 0;
  always #5 clk = ~clk;

  // driver
  int i, out_idx;
  int c; // column index


  initial begin
    $readmemh("p_input_252x252.hex", p);
    rst_n    = 0;
    shift_en = 0;
    mode     = 2'b01; // 0=pass, 1=sharpen, 2=gaussian blur, 3 = edge detect 
    pix_top  = 0; pix_mid = 0; pix_bot = 0;
    repeat (4) @(posedge clk);
    rst_n = 1;


    // Stream the image, one pixel position at a time
    for (i = 0; i < N-1 - 2*W_in; i++)

      c = i % W_in; // this indexes the column so we are reading correct window

      // cycle 1: present the three rows for this column; hold window (no shift)
      @(posedge clk);
      pix_top  <= p[i];
      pix_mid  <= p[i+W_in];
      pix_bot  <= p[i+2*W_in];
      shift_en <= 0;
      rst_n <= 1;

     // Cycle 2: Capture the output
     @(posedge clk);
     if (c >= 2) begin                // ignore the first two columns in every row
       outm[out_idx] <= pixel_out;    // store only when we expect a full window
       out_idx++;
     end
     shift_en <= 1;

      

      // End Row cycle: clear the modules registers at the last column of the row
      if (c == W_in-1) begin
        @(posedge clk);
        shift_en  <= 0;     // don't shift during clear
        rst_n <= 0;     // clears the 6 regs inside DUT
        @(posedge clk);
        rst_n <= 1;     // ready for the next row col=0
      end
    end

    // finish and dump output
    $writememh("conv_out_250x250.hex", outm);
    $display("Wrote conv_out_250x250.hex");
    $finish;
  end

endmodule


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
  logic [7:0] p     [0:N-1];
  logic [7:0] outm  [0:W_out * W_out-1];

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
  int r, c; // row and column indices


  initial begin
    $readmemh("p_input_252x252.hex", p);
    rst_n    = 0;
    shift_en = 0;
    mode     = 2'b01; // 0=pass, 1=sharpen, 2=gaussian blur, 3 = edge detect 
    pix_top  = 0; pix_mid = 0; pix_bot = 0;
    repeat (4) @(posedge clk);
    rst_n = 1;
    row_reset = 1;

    // Stream the image, one pixel position at a time
    for (i = 0; i < N-1 - 2*W_in; i++)

      r = i / W_in; // row
      c = i % W_in; // col
      // cycle 1: present the three rows for this column; hold window (no shift)
      @(posedge clk);
      pix_top  <= p[i];
      pix_mid  <= p[i+W_in];
      pix_bot  <= p[i+2*W_in];
      shift_en <= 0;
      row_reset <= 1;

      // cycle 2: sample output from previous window and then shift
      @(posedge clk);
      if (x >= 2) begin
        out_idx = y*OW + (x-2);
        outm[out_idx] <= pixel_out;
      end
      shift_en <= 1;
      

      // if this was the LAST column of the row, insert a boundary clear cycle
      if (col(i) == W_in-1) begin
        @(posedge clk);
        shift_en  <= 0;     // don't shift during clear
        row_reset <= 0;     // clears the 6 regs inside DUT
        @(posedge clk);
        row_reset <= 1;     // ready for the next row col=0
      end
    end

    // finish and dump output
    $writememh("conv_out_250x250.hex", outm);
    $display("Wrote conv_out_250x250.hex");
    $finish;
  end

endmodule

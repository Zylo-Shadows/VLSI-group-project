This subdirectory contains the files used in testing the functionality of conv33. It also contains
the inputs and outputs therein. The python Pillow library was used for the miscellaneous image 
processing tasks. 

-----File Name----------------Purpose----------------------------------------------------------------
     duck.png                 Original grayscale image that we plan on processing
     pad_to_hex.py            Script that 0-pads image edges and flattens pixel data to 1D .hex file
     padded_preview.png       Original image with 0 padding at the edges
     p_input_252x252.hex      .hex file output by the pad_to_hex script
     conv_out_250x250.hex     .hex file dumped by the testbench after processing completed
     out_to_image.py          Script that reads the output .hex file and rebuilds the image from that
     convolved.png            Output of the script, in this case the sharpened version of our input

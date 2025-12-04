import os
import math

# ================= CONFIGURATION =================
INPUT_FILE  = 'ms.bin'
OUTPUT_FILE = 'ms.hex'

# How many bytes per word? 
# 1 = 8-bit, 2 = 16-bit, 4 = 32-bit (Standard for RISC-V/Microblaze)
WORD_BYTES  = 4 

# Set to True if your binary is Little Endian (like x86/RISC-V) 
# but you need Big Endian hex strings for Verilog.
SWAP_ENDIAN = True 
# =================================================

def main():
    try:
        # 1. Read the binary file
        with open(INPUT_FILE, 'rb') as f:
            bin_data = f.read()
            
        print(f"Read {len(bin_data)} bytes from {INPUT_FILE}")

        # 2. Pad the data with zeros if it doesn't align with word width
        remainder = len(bin_data) % WORD_BYTES
        if remainder != 0:
            padding = WORD_BYTES - remainder
            bin_data += b'\x00' * padding
            print(f"Padded file with {padding} bytes to align to {WORD_BYTES}-byte width.")

        # 3. Convert and Write
        with open(OUTPUT_FILE, 'w') as out:
            # Process the file in chunks of WORD_BYTES
            for i in range(0, len(bin_data), WORD_BYTES):
                chunk = bin_data[i : i + WORD_BYTES]
                
                if SWAP_ENDIAN:
                    # Reverse bytes for Little Endian -> Big Endian conversion
                    chunk = chunk[::-1]
                
                # Convert to hex string
                hex_str = chunk.hex()
                
                # Write to file (Verilog readmemh expects one word per line)
                out.write(f"{hex_str}\n")

        print(f"Success! Converted to {OUTPUT_FILE}")
        print(f"Format: {WORD_BYTES*8}-bit wide hex strings.")

    except FileNotFoundError:
        print(f"Error: Could not find {INPUT_FILE}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()

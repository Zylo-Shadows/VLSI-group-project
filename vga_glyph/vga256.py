def generate_vga_palette(filename="vga256.hex"):
    palette = []

    # Helper to scale 6-bit VGA color (0-63) to 8-bit (0-255)
    def scale(v):
        return min(255, round((v * 255) / 63))

    # ---------------------------------------------------------
    # 1. Standard 16 Colors (CGA/EGA compatibility)
    # ---------------------------------------------------------
    # Standard VGA color definitions (R, G, B in 0-63 range)
    std_16 = [
        (0,0,0), (0,0,42), (0,42,0), (0,42,42),       # 0-3
        (42,0,0), (42,0,42), (42,21,0), (42,42,42),   # 4-7
        (21,21,21), (21,21,63), (21,63,21), (21,63,63), # 8-11
        (63,21,21), (63,21,63), (63,63,21), (63,63,63)  # 12-15
    ]
    for r,g,b in std_16:
        palette.extend([0,b,g,r])

    # ---------------------------------------------------------
    # 2. Grey Scale Ramp (Indices 16-31)
    # ---------------------------------------------------------
    for i in range(16):
        val = int((i / 15.0) * 63)
        palette.extend([0,val,val,val])

    # ---------------------------------------------------------
    # 3. Color Ramps (Indices 32-247)
    # ---------------------------------------------------------
    # The default VGA palette has 3 groups of 72 colors.
    # Each group cycles Hue with different Saturation/Value.
    # Group 1: High Saturation
    # Group 2: Med Saturation
    # Group 3: Low Saturation

    # 3 groups, 72 colors each
    # Each group consists of 24 hues * 3 brightness levels

    # This loop logic mimics the hardware default generation
    for sat in range(3): # 3 saturation groups
        for hue in range(24): # 24 base hues
            for val in range(3): # 3 intensity levels per hue

                # These are roughly the steps used in standard VGA BIOS
                v = int((val + 1) * 21) # Intensity: 21, 42, 63

                # Cycle RGB based on hue phase
                # This is a simplified procedural generation of the 
                # standard "rainbow" often found in Mode 13h
                if hue < 8:
                    r = v if hue >= 4 else v // 2
                    g = v if hue < 4 else v // 2
                    b = 0
                elif hue < 16:
                    r = 0
                    g = v if hue >= 12 else v // 2
                    b = v if hue < 12 else v // 2
                else:
                    r = v if hue >= 20 else v // 2
                    g = 0
                    b = v if hue < 20 else v // 2
                
                # Adjust for saturation groups (simplified)
                if sat == 1: # Medium saturation
                    r = (r + 21) if r < 63 else 63
                    g = (g + 21) if g < 63 else 63
                    b = (b + 21) if b < 63 else 63
                elif sat == 2: # Low saturation (pastel)
                    r = (r + 42) if r < 63 else 63
                    g = (g + 42) if g < 63 else 63
                    b = (b + 42) if b < 63 else 63

                palette.extend([0,b,g,r])

    # ---------------------------------------------------------
    # 4. Fill Remainder (248-255)
    # ---------------------------------------------------------
    # Usually unused or black in standard VGA
    while len(palette)//4 < 256:
        palette.extend([0,0,0,0])

    for i in range(len(palette)):
        palette[i] = scale(palette[i])

    # ---------------------------------------------------------
    # Write to File
    # ---------------------------------------------------------
    with open(filename, 'w') as f:
        for i, p in enumerate(palette):
            f.write(f"{p:02x}")
            if i % 4 == 3:
                f.write("\n")

if __name__ == "__main__":
    generate_vga_palette()

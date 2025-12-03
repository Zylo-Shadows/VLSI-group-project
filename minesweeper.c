/*
 * BARE METAL MINESWEEPER
 * Target: Embedded Core (32-bit recommended, e.g., RISC-V or ARM)
 * Constraints: < 400KB Memory, MMIO VGA, MMIO Mouse, Race-the-Beam Rendering
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

/* =========================================================================
 * HARDWARE ABSTRACTION LAYER (MMIO MAP)
 * ========================================================================= */

#define MMIO_BASE           0x80000000

// 32-bit Register Layout:
// [31]    : PS/2 Data Ready (1 = Valid Packet Available)
// [30:25] : Unused
// [24]    : VGA VSYNC
// [23:16] : PS/2 Byte 2 (Delta Y)
// [15:8]  : PS/2 Byte 1 (Delta X)
// [7:0]   : PS/2 Byte 0 (Buttons/Signs/Overflow)
#define MMIO_REG            (*(volatile uint32_t*)MMIO_BASE)
#define MOUSE_PORT          MMIO_REG
#define VGA_VSYNC_REG       MMIO_REG
#define MOUSE_READY_MASK    (1 << 31)
#define VGA_VSYNC_MASK      (1 << 24)

#define VGA_WIDTH           320
#define VGA_HEIGHT          200

static uint8_t VGA_BUFFER[VGA_WIDTH * VGA_HEIGHT];

/* =========================================================================
 * GAME CONSTANTS
 * ========================================================================= */

#define TILE_SIZE       16
#define BOARD_COLS      16
#define BOARD_ROWS      16
#define MINES_COUNT     40

#define BOARD_OFFSET_X  ((VGA_WIDTH - (BOARD_COLS * TILE_SIZE)) / 2)
#define BOARD_OFFSET_Y  ((VGA_HEIGHT - (BOARD_ROWS * TILE_SIZE)) / 2)

// Colors (VGA 256 palette approximation)
#define COL_BLACK       0x00
#define COL_BLUE        0x01
#define COL_GREEN       0x02
#define COL_CYAN        0x03
#define COL_RED         0x04
#define COL_MAGENTA     0x05
#define COL_BROWN       0x06 // Used for number 8 usually, or dark yellow
#define COL_WHITE       0x0F
#define COL_GRAY_LIGHT  0x07 // Main tile face
#define COL_GRAY_DARK   0x08 // Shadow
#define COL_GRAY_BRIGHT 0x0F // Highlight
#define COL_YELLOW      0x2C

// Cell State Bitmask
// Bits 0-3: Neighbor Count (0-8) or MINE (9)
#define MASK_VALUE      0x0F
#define VAL_MINE        0x09
#define VAL_EMPTY       0x00

// Bits 4-7: Flags
#define FLAG_REVEALED   (1 << 4)
#define FLAG_MARKED     (1 << 5)
#define FLAG_QUESTION   (1 << 6)

/* =========================================================================
 * ASSETS (.rodata)
 * Minimal 5x7 font bitmaps for numbers and symbols
 * ========================================================================= */

// 0-8 are numbers, 9 is Mine, 10 is Flag
const uint8_t GLYPHS[12][5] = {
    {0x00, 0x00, 0x00, 0x00, 0x00}, // 0 (Draw nothing)
    {0x00, 0x42, 0x7F, 0x40, 0x00}, // 1
    {0x42, 0x61, 0x51, 0x49, 0x46}, // 2
    {0x21, 0x41, 0x45, 0x4B, 0x31}, // 3
    {0x18, 0x14, 0x12, 0x7F, 0x10}, // 4
    {0x27, 0x45, 0x45, 0x45, 0x39}, // 5
    {0x3C, 0x4A, 0x49, 0x49, 0x30}, // 6
    {0x01, 0x71, 0x09, 0x05, 0x03}, // 7
    {0x36, 0x49, 0x49, 0x49, 0x36}, // 8
    {0x44, 0x28, 0x10, 0x28, 0x44}, // 9 (Mine)
    {0x7F, 0x05, 0x09, 0x1F, 0x08}, // 10 (Flag)
    {0x08, 0x2A, 0x1C, 0x2A, 0x08}  // 11 (Explosion)
};

const uint8_t NUMBER_COLORS[] = {
    COL_BLACK, COL_BLUE, COL_GREEN, COL_RED, 
    COL_MAGENTA, COL_BROWN, COL_CYAN, COL_BLACK, COL_GRAY_DARK
};

/* =========================================================================
 * GRAPHICS DRIVER (Direct VRAM)
 * ========================================================================= */

void put_pixel(int x, int y, uint8_t color) {
    if (x < 0 || x >= VGA_WIDTH || y < 0 || y >= VGA_HEIGHT) return;
    VGA_BUFFER[y * VGA_WIDTH + x] = color;
}

void draw_rect_filled(int x, int y, int w, int h, uint8_t color) {
    for (int j = y; j < y + h; j++) {
        for (int i = x; i < x + w; i++) {
            put_pixel(i, j, color);
        }
    }
}

// Draws a 5x7 glyph scaled to 2x (making it 10x14 approx) centered in tile
void draw_glyph(int x, int y, int glyph_idx, uint8_t color) {
    const uint8_t* glyph = GLYPHS[glyph_idx];
    int start_x = x + 4; // Center in 16x16
    int start_y = y + 2; 
    
    for (int col = 0; col < 5; col++) {
        uint8_t line = glyph[col];
        for (int row = 0; row < 7; row++) {
            if ((line >> row) & 1) {
                // simple 2x scale
                put_pixel(start_x + (col*2), start_y + (6-row)*2, color);
                put_pixel(start_x + (col*2)+1, start_y + (6-row)*2, color);
                put_pixel(start_x + (col*2), start_y + (6-row)*2+1, color);
                put_pixel(start_x + (col*2)+1, start_y + (6-row)*2+1, color);
            }
        }
    }
}

// Draws the Windows 95 style 3D button
void draw_tile_3d(int x, int y, bool pressed) {
    uint8_t tl = pressed ? COL_GRAY_DARK : COL_WHITE;     // Top/Left
    uint8_t br = pressed ? COL_WHITE : COL_GRAY_DARK;     // Bottom/Right
    uint8_t face = COL_GRAY_LIGHT;

    draw_rect_filled(x, y, TILE_SIZE, TILE_SIZE, face);

    // Bevels
    for(int i=0; i<2; i++) { // 2 pixel width border
        // Top
        draw_rect_filled(x+i, y+i, TILE_SIZE-2*i, 1, tl);
        // Left
        draw_rect_filled(x+i, y+i, 1, TILE_SIZE-2*i, tl);
        // Bottom
        draw_rect_filled(x+i, y+TILE_SIZE-1-i, TILE_SIZE-2*i, 1, br);
        // Right
        draw_rect_filled(x+TILE_SIZE-1-i, y+i, 1, TILE_SIZE-2*i, br);
    }
}

void wait_vsync() {
    // Wait for signal to go HIGH (Start of Sync Pulse)
    while (!(VGA_VSYNC_REG & VGA_VSYNC_MASK));
    // Wait for signal to go LOW (End of Sync Pulse -> Start of Active/Back Porch)
    // This aligns our start time exactly when the "beam" resets to top.
    while (VGA_VSYNC_REG & VGA_VSYNC_MASK);
}

/* =========================================================================
 * INPUT DRIVER
 * ========================================================================= */

typedef struct {
    int x, y;
    bool left_btn;
    bool right_btn;
} MouseState;

MouseState mouse = {VGA_WIDTH / 2, VGA_HEIGHT / 2, false, false};

void poll_mouse() {
    uint32_t packet = MOUSE_PORT;

    if (packet & MOUSE_READY_MASK) {
        uint8_t b0 = packet & 0xFF; // Buttons & Signs
        
        // Basic sync check (Bit 3 of Byte 0 must be 1)
        if (!(b0 & 0x08)) return; 

        bool btn_l = b0 & 0x01;
        bool btn_r = b0 & 0x02;
        
        // Extract 9-bit signed values
        int16_t rel_x = (packet >> 8) & 0xFF;
        int16_t rel_y = (packet >> 16) & 0xFF;

        // Apply Sign Bits from Byte 0
        if (b0 & 0x10) rel_x |= 0xFF00;
        if (b0 & 0x20) rel_y |= 0xFF00;

        mouse.x += rel_x;
        mouse.y -= rel_y; // PS/2 Y is bottom-to-top usually
        
        if (mouse.x < 0) mouse.x = 0;
        if (mouse.x >= VGA_WIDTH) mouse.x = VGA_WIDTH - 1;
        if (mouse.y < 0) mouse.y = 0;
        if (mouse.y >= VGA_HEIGHT) mouse.y = VGA_HEIGHT - 1;

        mouse.left_btn = btn_l;
        mouse.right_btn = btn_r;
    }
}

void draw_cursor() {
    // Simple crosshair, XOR color to always be visible
    int mx = mouse.x;
    int my = mouse.y;
    
    for(int i=-4; i<=4; i++) {
        int px = mx + i;
        int py = my;
        if(px >=0 && px < VGA_WIDTH) VGA_BUFFER[py*VGA_WIDTH + px] ^= 0xFF;
        
        px = mx;
        py = my + i;
        if(py >=0 && py < VGA_HEIGHT) VGA_BUFFER[py*VGA_WIDTH + px] ^= 0xFF;
    }
}

/* =========================================================================
 * GAME LOGIC
 * ========================================================================= */

uint8_t board[BOARD_ROWS][BOARD_COLS];
bool game_over = false;
bool victory = false;

void render_tile(int r, int c) {
    int screen_x = BOARD_OFFSET_X + (c * TILE_SIZE);
    int screen_y = BOARD_OFFSET_Y + (r * TILE_SIZE);
    uint8_t cell = board[r][c];
    
    bool revealed = cell & FLAG_REVEALED;
    bool marked = cell & FLAG_MARKED;
    uint8_t val = cell & MASK_VALUE;

    if (!revealed) {
        draw_tile_3d(screen_x, screen_y, false); // Raised button
        if (marked) {
            draw_glyph(screen_x, screen_y, 10, COL_RED); // Flag
        }
    } else {
        // Revealed
        draw_tile_3d(screen_x, screen_y, true); // Sunken button
        if (val == VAL_MINE) {
            draw_rect_filled(screen_x+2, screen_y+2, TILE_SIZE-4, TILE_SIZE-4, COL_RED);
            draw_glyph(screen_x, screen_y, 9, COL_BLACK); // Mine
        } else if (val > 0 && val < 9) {
            draw_glyph(screen_x, screen_y, val, NUMBER_COLORS[val]);
        }
    }
}

void render_board() {
    for (int r = 0; r < BOARD_ROWS; r++) {
        for (int c = 0; c < BOARD_COLS; c++) {
            render_tile(r, c);
        }
    }
}

void reveal(int r, int c); // Forward decl

void init_game() {
    memset(board, 0, sizeof(board));
    game_over = false;
    victory = false;
    
    // Seed RNG (Hack: use uninitialized memory or a timer if available)
    // Here we rely on user input timing later, or a fixed seed
    
    int mines_placed = 0;
    while (mines_placed < MINES_COUNT) {
        int r = rand() % BOARD_ROWS;
        int c = rand() % BOARD_COLS;
        
        if ((board[r][c] & MASK_VALUE) != VAL_MINE) {
            board[r][c] |= VAL_MINE;
            mines_placed++;
            
            // Update neighbors
            for (int dr = -1; dr <= 1; dr++) {
                for (int dc = -1; dc <= 1; dc++) {
                    int nr = r + dr;
                    int nc = c + dc;
                    if (nr >= 0 && nr < BOARD_ROWS && nc >= 0 && nc < BOARD_COLS) {
                        if ((board[nr][nc] & MASK_VALUE) != VAL_MINE) {
                            board[nr][nc]++;
                        }
                    }
                }
            }
        }
    }
}

void reveal(int r, int c) {
    if (r < 0 || r >= BOARD_ROWS || c < 0 || c >= BOARD_COLS) return;
    if ((board[r][c] & FLAG_REVEALED) || (board[r][c] & FLAG_MARKED)) return;

    board[r][c] |= FLAG_REVEALED;

    if ((board[r][c] & MASK_VALUE) == VAL_MINE) {
        game_over = true;
        // Reveal all mines
        for(int rr=0; rr<BOARD_ROWS; rr++) {
            for(int cc=0; cc<BOARD_COLS; cc++) {
                if((board[rr][cc] & MASK_VALUE) == VAL_MINE) {
                    board[rr][cc] |= FLAG_REVEALED;
                }
            }
        }
        return;
    }

    if ((board[r][c] & MASK_VALUE) == 0) {
        // Flood fill
        for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
                reveal(r + dr, c + dc);
            }
        }
    }
}

void toggle_flag(int r, int c) {
    if (r < 0 || r >= BOARD_ROWS || c < 0 || c >= BOARD_COLS) return;
    if (board[r][c] & FLAG_REVEALED) return;

    board[r][c] ^= FLAG_MARKED;
}

/* =========================================================================
 * KERNEL ENTRY POINT
 * ========================================================================= */

void kernel_main(void) {
    // 1. Hardware Init
    // (In a real scenario, you might send reset commands to the mouse here)
    srand(123); // Initial seed
    
    // Clear screen to background color
    draw_rect_filled(0, 0, VGA_WIDTH, VGA_HEIGHT, COL_CYAN);

    // 2. Game Init
    init_game();
    render_board();
    
    // Draw initial cursor so the loop's first "erase" works correctly
    draw_cursor();

    bool prev_l = false;
    bool prev_r = false;

    // 3. Event Loop
    while (1) {
        // 1. Wait for Start of Frame (VSync Falling Edge)
        wait_vsync(); 
        
        // 2. Erase Cursor (Immediate VRAM Update)
        draw_cursor(); 

        // 3. Input & Game Logic
        poll_mouse();
        
        int grid_c = (mouse.x - BOARD_OFFSET_X) / TILE_SIZE;
        int grid_r = (mouse.y - BOARD_OFFSET_Y) / TILE_SIZE;
        bool in_grid = (grid_c >= 0 && grid_c < BOARD_COLS && 
                        grid_r >= 0 && grid_r < BOARD_ROWS);

        if (game_over) {
            if (mouse.left_btn && !prev_l) {
                init_game();
                draw_rect_filled(0, 0, VGA_WIDTH, VGA_HEIGHT, COL_CYAN);
                render_board();
            }
        } else if (in_grid) {
            if (mouse.left_btn && !prev_l) {
                srand(rand() + mouse.x + mouse.y); 
                reveal(grid_r, grid_c);
                render_board(); // Naive full redraw (robust)
            }
            if (mouse.right_btn && !prev_r) {
                toggle_flag(grid_r, grid_c);
                render_tile(grid_r, grid_c); // Optimized single redraw
            }
        }

        prev_l = mouse.left_btn;
        prev_r = mouse.right_btn;
    }
}

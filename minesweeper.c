/*
 * BARE METAL MINESWEEPER
 * Target: Embedded Core (32-bit recommended, e.g., RISC-V or ARM)
 * Constraints: < 400KB Memory, MMIO VGA, MMIO Mouse
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

/* =========================================================================
 * HARDWARE ABSTRACTION LAYER (MMIO MAP)
 * Adjust these addresses to match your specific FPGA/Board implementation.
 * ========================================================================= */

// VGA MMIO
#define VGA_BASE_ADDR       0xB0000000
#define VGA_WIDTH           320
#define VGA_HEIGHT          200
// Assuming linear framebuffer at a specific address (or MMIO window)
volatile uint8_t* const VGA_BUFFER = (uint8_t*)0xA0000000; 

// PS/2 MOUSE MMIO
#define MOUSE_BASE          0xC0000000
#define MOUSE_STATUS        (*(volatile uint32_t*)(MOUSE_BASE + 0x00))
#define MOUSE_DATA          (*(volatile uint32_t*)(MOUSE_BASE + 0x04))
#define MOUSE_CMD           (*(volatile uint32_t*)(MOUSE_BASE + 0x08))
#define MOUSE_STATUS_RX_RDY (1 << 0)

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
#define FLAG_QUESTION   (1 << 6) // Optional

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
    {0x44, 0x28, 0x10, 0x28, 0x44}, // 9 (Mine - simple X or spike)
    {0x7F, 0x05, 0x09, 0x1F, 0x08}, // 10 (Flag - P shape)
    {0x08, 0x2A, 0x1C, 0x2A, 0x08}  // 11 (Explosion)
};

const uint8_t NUMBER_COLORS[] = {
    COL_BLACK, COL_BLUE, COL_GREEN, COL_RED, 
    COL_MAGENTA, COL_BROWN, COL_CYAN, COL_BLACK, COL_GRAY_DARK
};

/* =========================================================================
 * GRAPHICS DRIVER
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

/* =========================================================================
 * INPUT DRIVER
 * ========================================================================= */

typedef struct {
    int x, y;
    bool left_btn;
    bool right_btn;
} MouseState;

MouseState mouse = {VGA_WIDTH / 2, VGA_HEIGHT / 2, false, false};
uint8_t mouse_cycle = 0;
uint8_t mouse_bytes[3];

void poll_mouse() {
    // Simple polling state machine for standard PS/2 packet (3 bytes)
    // Byte 0: Yov Xov Ysgn Xsgn 1 M R L
    // Byte 1: X movement
    // Byte 2: Y movement
    
    while (MOUSE_STATUS & MOUSE_STATUS_RX_RDY) {
        uint8_t byte = MOUSE_DATA & 0xFF;
        mouse_bytes[mouse_cycle++] = byte;

        if (mouse_cycle == 3) {
            mouse_cycle = 0;
            
            // Check sync bit (bit 3 of byte 0 should be 1)
            if (!(mouse_bytes[0] & 0x08)) return; 

            bool btn_l = mouse_bytes[0] & 0x01;
            bool btn_r = mouse_bytes[0] & 0x02;
            int16_t rel_x = mouse_bytes[1];
            int16_t rel_y = mouse_bytes[2];

            // Sign extension for 9-bit values
            if (mouse_bytes[0] & 0x10) rel_x |= 0xFF00;
            if (mouse_bytes[0] & 0x20) rel_y |= 0xFF00;

            mouse.x += rel_x;
            mouse.y -= rel_y; // PS/2 Y is bottom-to-top usually
            
            // Clamp
            if (mouse.x < 0) mouse.x = 0;
            if (mouse.x >= VGA_WIDTH) mouse.x = VGA_WIDTH - 1;
            if (mouse.y < 0) mouse.y = 0;
            if (mouse.y >= VGA_HEIGHT) mouse.y = VGA_HEIGHT - 1;

            mouse.left_btn = btn_l;
            mouse.right_btn = btn_r;
        }
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
    
    bool prev_l = false;
    bool prev_r = false;

    // 3. Event Loop
    while (1) {
        // Remove cursor before drawing
        draw_cursor(); // XOR again to erase
        
        // Input
        poll_mouse();
        
        // Logic
        int grid_c = (mouse.x - BOARD_OFFSET_X) / TILE_SIZE;
        int grid_r = (mouse.y - BOARD_OFFSET_Y) / TILE_SIZE;
        bool in_grid = (grid_c >= 0 && grid_c < BOARD_COLS && 
                        grid_r >= 0 && grid_r < BOARD_ROWS);

        if (game_over) {
            if (mouse.left_btn && !prev_l) {
                // Reset on click
                init_game();
                draw_rect_filled(0, 0, VGA_WIDTH, VGA_HEIGHT, COL_CYAN);
                render_board();
            }
        } else if (in_grid) {
            // Handle Left Click (Reveal)
            if (mouse.left_btn && !prev_l) {
                // Seed RNG with human reaction time on first click for better randomness
                srand(rand() + mouse.x + mouse.y); 
                reveal(grid_r, grid_c);
                render_board(); // Naive full redraw (robust)
            }
            // Handle Right Click (Flag)
            if (mouse.right_btn && !prev_r) {
                toggle_flag(grid_r, grid_c);
                render_tile(grid_r, grid_c); // Optimized single redraw
            }
        }

        prev_l = mouse.left_btn;
        prev_r = mouse.right_btn;

        // Draw cursor
        draw_cursor(); // XOR to draw

        // Busy wait delay (mocking ~60fps)
        // Adjust this loop count based on your core's clock speed
        for(volatile int i=0; i<50000; i++); 
    }
}

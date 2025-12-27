//
//  cpm_support.h
//  CP/M Support Functions
//
//  Provides I/O and BDOS emulation for running CP/M programs
//

#ifndef cpm_support_h
#define cpm_support_h

#include <stdio.h>

// Forward declaration
struct i8080;

// Console I/O state
typedef struct {
    char input_buffer[256];
    int input_read_pos;
    int input_write_pos;
    char output_buffer[1024];
    int output_pos;
} console_state;

extern console_state cpm_console;

// Disk emulation state
typedef struct {
    unsigned char current_disk;     // 0=A:, 1=B:, etc.
    unsigned char current_track;
    unsigned char current_sector;
    unsigned int dma_address;       // DMA transfer address
    unsigned char disk_a[77 * 26 * 128];  // 256KB disk image
    unsigned char disk_b[77 * 26 * 128];
} disk_state;

extern disk_state cpm_disk;

// Console I/O functions
void cpm_console_init(void);
int cpm_console_status(void);           // Returns 0xFF if char ready
unsigned char cpm_console_input(void);  // Read character (blocking)
void cpm_console_output(unsigned char ch);
void cpm_put_char(unsigned char ch);    // Called from Swift
unsigned char cpm_get_char(void);       // Called from Swift

// Disk I/O functions
void cpm_disk_init(void);
void cpm_select_disk(unsigned char disk);
void cpm_set_track(unsigned char track);
void cpm_set_sector(unsigned char sector);
void cpm_set_dma(unsigned int address);
int cpm_read_sector(void);   // Returns 0 on success
int cpm_write_sector(void);  // Returns 0 on success
void cpm_home_disk(void);    // Move to track 0

// Disk image persistence
int cpm_load_disk_image(unsigned char disk, const char* filename);
int cpm_save_disk_image(unsigned char disk, const char* filename);

// BDOS call emulation
void cpm_bdos_call(struct i8080* cpu);

// CP/M initialization
void cpm_init(void);
void cpm_load_system(void);

#endif /* cpm_support_h */

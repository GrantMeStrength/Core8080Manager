//
//  cpm_support.c
//  CP/M Support Implementation
//

#include "cpm_support.h"
#include "8080.h"
#include <string.h>

// Global state
console_state cpm_console;
disk_state cpm_disk;

// External reference to memory
extern unsigned char mem[];
extern struct i8080 cpu;

// ============================================================================
// CONSOLE I/O
// ============================================================================

void cpm_console_init(void) {
    memset(&cpm_console, 0, sizeof(console_state));
}

int cpm_console_status(void) {
    // Returns 0xFF if character available, 0x00 otherwise
    return (cpm_console.input_read_pos != cpm_console.input_write_pos) ? 0xFF : 0x00;
}

unsigned char cpm_console_input(void) {
    // Wait for character (blocking)
    while (cpm_console.input_read_pos == cpm_console.input_write_pos) {
        // In real implementation, this would yield or wait
        // For now, return 0 if no input
        return 0;
    }

    unsigned char ch = cpm_console.input_buffer[cpm_console.input_read_pos];
    cpm_console.input_read_pos = (cpm_console.input_read_pos + 1) % 256;
    return ch;
}

void cpm_console_output(unsigned char ch) {
    // Add to output buffer
    if (cpm_console.output_pos < 1024) {
        cpm_console.output_buffer[cpm_console.output_pos++] = ch;
    }
}

// Called from Swift to add input character
void cpm_put_char(unsigned char ch) {
    cpm_console.input_buffer[cpm_console.input_write_pos] = ch;
    cpm_console.input_write_pos = (cpm_console.input_write_pos + 1) % 256;
}

// Called from Swift to get output character
unsigned char cpm_get_char(void) {
    if (cpm_console.output_pos == 0) {
        return 0;
    }

    // Get first character and shift buffer
    unsigned char ch = cpm_console.output_buffer[0];
    cpm_console.output_pos--;
    memmove(cpm_console.output_buffer, cpm_console.output_buffer + 1, cpm_console.output_pos);
    return ch;
}

// ============================================================================
// DISK I/O
// ============================================================================

void cpm_disk_init(void) {
    memset(&cpm_disk, 0, sizeof(disk_state));
    cpm_disk.dma_address = 0x0080; // Default DMA address
}

void cpm_select_disk(unsigned char disk) {
    cpm_disk.current_disk = disk;
}

void cpm_set_track(unsigned char track) {
    cpm_disk.current_track = track;
}

void cpm_set_sector(unsigned char sector) {
    cpm_disk.current_sector = sector;
}

void cpm_set_dma(unsigned int address) {
    cpm_disk.dma_address = address;
}

void cpm_home_disk(void) {
    cpm_disk.current_track = 0;
}

int cpm_read_sector(void) {
    // Calculate offset in disk image
    // CP/M sectors are numbered 1-26
    if (cpm_disk.current_sector < 1 || cpm_disk.current_sector > 26) {
        return 1; // Error
    }

    int offset = (cpm_disk.current_track * 26 + (cpm_disk.current_sector - 1)) * 128;

    // Select disk image
    unsigned char *disk = (cpm_disk.current_disk == 0) ? cpm_disk.disk_a : cpm_disk.disk_b;

    // Copy sector to DMA address
    for (int i = 0; i < 128; i++) {
        mem[cpm_disk.dma_address + i] = disk[offset + i];
    }

    return 0; // Success
}

int cpm_write_sector(void) {
    // Calculate offset in disk image
    if (cpm_disk.current_sector < 1 || cpm_disk.current_sector > 26) {
        return 1; // Error
    }

    int offset = (cpm_disk.current_track * 26 + (cpm_disk.current_sector - 1)) * 128;

    // Select disk image
    unsigned char *disk = (cpm_disk.current_disk == 0) ? cpm_disk.disk_a : cpm_disk.disk_b;

    // Copy from DMA address to sector
    for (int i = 0; i < 128; i++) {
        disk[offset + i] = mem[cpm_disk.dma_address + i];
    }

    return 0; // Success
}

int cpm_load_disk_image(unsigned char disk, const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) return -1;

    unsigned char* disk_ptr = (disk == 0) ? cpm_disk.disk_a : cpm_disk.disk_b;
    size_t bytes_read = fread(disk_ptr, 1, 77 * 26 * 128, f);
    fclose(f);

    return (bytes_read == 77 * 26 * 128) ? 0 : -1;
}

int cpm_save_disk_image(unsigned char disk, const char* filename) {
    FILE* f = fopen(filename, "wb");
    if (!f) return -1;

    unsigned char* disk_ptr = (disk == 0) ? cpm_disk.disk_a : cpm_disk.disk_b;
    size_t bytes_written = fwrite(disk_ptr, 1, 77 * 26 * 128, f);
    fclose(f);

    return (bytes_written == 77 * 26 * 128) ? 0 : -1;
}

// ============================================================================
// BDOS CALL EMULATION
// ============================================================================

void cpm_bdos_call(struct i8080* cpu) {
    unsigned char function = (cpu->reg)[C];
    unsigned char param_e = (cpu->reg)[E];
    unsigned int param_de = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];

    switch (function) {
        case 0: // System Reset
            // Reset system (not implemented)
            break;

        case 1: // Console Input
            (cpu->reg)[A] = cpm_console_input();
            break;

        case 2: // Console Output
            cpm_console_output(param_e);
            break;

        case 6: // Direct Console I/O
            if (param_e == 0xFF) {
                // Status check
                (cpu->reg)[A] = cpm_console_status();
            } else if (param_e == 0xFE) {
                // Input without echo
                (cpu->reg)[A] = cpm_console_input();
            } else {
                // Output
                cpm_console_output(param_e);
            }
            break;

        case 9: // Print String (terminated by $)
            while (mem[param_de] != '$') {
                cpm_console_output(mem[param_de++]);
            }
            break;

        case 11: // Get Console Status
            (cpu->reg)[A] = cpm_console_status();
            break;

        case 13: // Reset Disk System
            cpm_disk_init();
            break;

        case 14: // Select Disk
            cpm_select_disk(param_e);
            (cpu->reg)[A] = 0; // Success
            break;

        case 25: // Get Current Disk
            (cpu->reg)[A] = cpm_disk.current_disk;
            break;

        case 26: // Set DMA Address
            cpm_set_dma(param_de);
            break;

        // File operations would go here (15-24)
        // For now, return error for unimplemented functions
        default:
            (cpu->reg)[A] = 0xFF; // Error
            break;
    }
}

// ============================================================================
// CP/M INITIALIZATION
// ============================================================================

void cpm_init(void) {
    cpm_console_init();
    cpm_disk_init();
}

void cpm_load_system(void) {
    // Set up jump vectors at bottom of memory
    // 0x0000: JMP WBOOT (warm boot)
    mem[0x0000] = 0xC3; // JMP instruction
    mem[0x0001] = 0x00; // Low byte of address
    mem[0x0002] = 0xFA; // High byte (0xFA00 - BIOS)

    // 0x0005: JMP BDOS (BDOS entry point)
    mem[0x0005] = 0xC3; // JMP instruction
    mem[0x0006] = 0x06; // Low byte
    mem[0x0007] = 0xE4; // High byte (0xE406)

    // Set default DMA address at 0x0080
    mem[0x0080] = 0x00;

    // Here you would load CCP, BDOS, and BIOS binaries
    // For now, this is just the framework
}

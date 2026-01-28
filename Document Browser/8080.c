#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

// Debug flags - set to 1 to enable, 0 to disable
#define DEBUG_CPU 0        // CPU instruction debugging (JNZ, DCR, etc.)
#define DEBUG_DISK_IO 1    // Disk I/O port operations
#define DEBUG_HALT 1       // Show registers when halting

int addressBus = 0;

unsigned char mem[0x10000] = { 0 };
struct i8080 cpu;
struct i8080* p = &cpu;
char buffer[80]; // for displaying reg dump
int currentAndNext[6]; // store the just executed and next to be executed instructions for display


void MemWrite(int address, int value)
{
    if (address < 0 || address >= 0x10000) {
        return; // Bounds check - silently ignore out of range
    }
    mem[address] = value;
    addressBus = address;
}


int MemRead(int address)
{
    if (address < 0 || address >= 0x10000) {
        return 0; // Bounds check - return 0 for out of range
    }
    addressBus = address;
    return mem[address];
}

#include "8080.h"

// ============================================================================
// CP/M SUPPORT - Inline Implementation
// ============================================================================

// Forward declarations for BDOS file operations
int bdos_open_file(struct i8080* cpu);
int bdos_close_file(struct i8080* cpu);
int bdos_make_file(struct i8080* cpu);
int bdos_read_sequential(struct i8080* cpu);
int bdos_write_sequential(struct i8080* cpu);
int bdos_search_first(struct i8080* cpu);
int bdos_search_next(struct i8080* cpu);
int bdos_delete_file(struct i8080* cpu);
int bdos_rename_file(struct i8080* cpu);

// Console I/O state
typedef struct {
    char input_buffer[256];
    int input_read_pos;
    int input_write_pos;
    char output_buffer[1024];
    int output_pos;
    int waiting_for_input;      // Flag: 1 = CPU is blocked waiting for input
    int input_echo;             // Flag: 1 = echo input characters
} console_state;

console_state cpm_console;

// Disk state structure
typedef struct {
    unsigned char current_disk;     // 0=A:, 1=B:
    unsigned char current_track;    // 0-76
    unsigned char current_sector;   // 1-26
    unsigned int dma_address;       // DMA transfer address
    unsigned int dir_base_offset;  // Directory base offset in bytes
} disk_state;

disk_state cpm_disk;

// Disk images: 77 tracks × 26 sectors × 128 bytes = 256,256 bytes each
unsigned char disk_a[77 * 26 * 128];
unsigned char disk_b[77 * 26 * 128];

static int disk_a_loaded = 0;
static int disk_b_loaded = 0;
static unsigned int disk_dir_base_offset[2] = { 0, 0 };
static char disk_base_path[512] = { 0 };

static unsigned int detect_directory_base_offset(const unsigned char *disk, size_t disk_size);

void cpm_console_init(void) {
    memset(&cpm_console, 0, sizeof(console_state));
    cpm_console.waiting_for_input = 0;
    cpm_console.input_echo = 1;  // Echo input by default
}

int cpm_console_status(void) {
    return (cpm_console.input_read_pos != cpm_console.input_write_pos) ? 0xFF : 0x00;
}

unsigned char cpm_console_input(void) {
    while (cpm_console.input_read_pos == cpm_console.input_write_pos) {
        return 0; // No input available
    }
    unsigned char ch = cpm_console.input_buffer[cpm_console.input_read_pos];
    cpm_console.input_read_pos = (cpm_console.input_read_pos + 1) % 256;
    return ch;
}

void cpm_console_output(unsigned char ch) {
    if (cpm_console.output_pos < 1024) {
        cpm_console.output_buffer[cpm_console.output_pos++] = ch;
    }

    // Mirror output to Xcode console
    #if DEBUG_DISK_IO
    if (ch == 0x00) {
        unsigned int hl = 0x100 * cpu.reg[H] + cpu.reg[L];
        unsigned int de = 0x100 * cpu.reg[D] + cpu.reg[E];
        printf("\n[OUT: NUL] PC=0x%04X HL=0x%04X DE=0x%04X\n", cpu.prog_ctr, hl, de);
        fflush(stdout);
    }
    #endif
    if (ch == '\n' || ch == '\r') {
        printf("\n");
        fflush(stdout);
    } else if (ch >= 32 && ch < 127) {
        printf("%c", ch);
        fflush(stdout);
    } else {
        printf("[0x%02X]", ch);
        fflush(stdout);
    }
}

void cpm_put_char(unsigned char ch) {
    cpm_console.input_buffer[cpm_console.input_write_pos] = ch;
    cpm_console.input_write_pos = (cpm_console.input_write_pos + 1) % 256;
    cpm_console.waiting_for_input = 0;

    // Log input characters (for debugging)
    static int first_input = 1;
    if (first_input) {
        printf("\n[Input→CP/M] ");
        first_input = 0;
    }
    if (ch == '\n') {
        printf("\\n");
    } else if (ch >= 32 && ch < 127) {
        printf("%c", ch);
    } else {
        printf("[0x%02X]", ch);
    }
    fflush(stdout);
}

unsigned char cpm_get_char(void) {
    if (cpm_console.output_pos == 0) {
        return 0;
    }
    unsigned char ch = cpm_console.output_buffer[0];
    cpm_console.output_pos--;
    memmove(cpm_console.output_buffer, cpm_console.output_buffer + 1, cpm_console.output_pos);
    return ch;
}

void cpm_bdos_call(struct i8080* cpu) {
    unsigned char function = (cpu->reg)[C];
    unsigned char param_e = (cpu->reg)[E];

    switch (function) {
        case 1: { // Console Input - wait for character
            // Check if input is available
            if (cpm_console.input_read_pos == cpm_console.input_write_pos) {
                // No input available - set waiting flag and don't advance PC
                cpm_console.waiting_for_input = 1;
                // Return without modifying A register - will retry this call
                return;
            }

            // Input available - get character
            unsigned char ch = cpm_console_input();
            (cpu->reg)[A] = ch;
            cpm_console.waiting_for_input = 0;
            break;
        }

        case 2: // Console Output
            cpm_console_output(param_e);
            break;

        case 9: { // Print String (terminated by $)
            unsigned int addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
            #if DEBUG_DISK_IO
            printf("\n[BDOS-9: Print String @ 0x%04X] ", addr);
            printf("\n[BDOS-9: Bytes @ 0x%04X] ", addr);
            for (int i = 0; i < 8; i++) {
                printf("%02X ", mem[addr + i]);
            }
            printf("\n");
            #endif
            while (mem[addr] != '$') {
                cpm_console_output(mem[addr++]);
            }
            break;
        }

        case 10: { // Read Console Buffer
            unsigned int buffer_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
            unsigned char max_len = mem[buffer_addr];

            // Use a static variable to track current position during multi-call reads
            static unsigned char count = 0;
            static int first_call = 1;

            // First call - initialize
            if (first_call) {
                count = 0;
                first_call = 0;
                #if DEBUG_DISK_IO
                printf("\n[BDOS-10: Read Console Buffer @ 0x%04X, max=%d]\n", buffer_addr, max_len);
                fflush(stdout);
                #endif
            }

            // Read characters until Enter (0x0D) or buffer full
            while (count < max_len) {
                // Check if input is available
                if (cpm_console.input_read_pos == cpm_console.input_write_pos) {
                    // No input available - set waiting flag and retry
                    cpm_console.waiting_for_input = 1;
                    return;  // Will retry this BDOS call
                }

                unsigned char ch = cpm_console_input();

                // Echo character if enabled
                if (cpm_console.input_echo) {
                    cpm_console_output(ch);
                }

                if (ch == 0x0D || ch == 0x0A) {  // Enter
                    // Echo newline
                    if (cpm_console.input_echo) {
                        cpm_console_output(0x0D);
                        cpm_console_output(0x0A);
                    }
                    break;
                }

                // Backspace handling
                if (ch == 0x08 || ch == 0x7F) {  // BS or DEL
                    if (count > 0) {
                        count--;
                        if (cpm_console.input_echo) {
                            cpm_console_output(0x08);  // BS
                            cpm_console_output(' ');   // Space
                            cpm_console_output(0x08);  // BS
                        }
                    }
                    continue;
                }

                mem[buffer_addr + 2 + count] = ch;
                count++;
            }

            mem[buffer_addr + 1] = count;  // Store actual length
            if (count < max_len) {
                mem[buffer_addr + 2 + count] = 0;  // Null-terminate for parsers
            }
            cpm_console.waiting_for_input = 0;
            first_call = 1;  // Reset for next call

            #if DEBUG_DISK_IO
            printf("[BDOS-10: Read %d characters]\n", count);
            fflush(stdout);
            #endif
            break;
        }

        case 11: // Get Console Status
            (cpu->reg)[A] = cpm_console_status();
            break;

        case 13: // Reset Disk System
            printf("\n[BDOS-13: Reset Disk System]\n");
            fflush(stdout);
            cpm_disk.current_disk = 0;
            cpm_disk.current_track = 0;
            cpm_disk.current_sector = 1;
            (cpu->reg)[A] = 0; // Success
            break;

        case 14: // Select Disk
            printf("\n[BDOS-14: Select Disk %c:]\n", 'A' + param_e);
            fflush(stdout);
            if (param_e <= 1) {
                cpm_disk.current_disk = param_e;
                (cpu->reg)[A] = 0; // Success
            } else {
                (cpu->reg)[A] = 0xFF; // Error - invalid disk
            }
            break;

        case 25: // Get Current Disk
            printf("\n[BDOS-25: Get Current Disk → %c:]\n", 'A' + cpm_disk.current_disk);
            fflush(stdout);
            (cpu->reg)[A] = cpm_disk.current_disk;
            break;

        case 15: // Open File
            bdos_open_file(cpu);
            break;

        case 16: // Close File
            bdos_close_file(cpu);
            break;

        case 17: // Search First
            bdos_search_first(cpu);
            break;

        case 18: // Search Next
            bdos_search_next(cpu);
            break;

        case 19: // Delete File
            bdos_delete_file(cpu);
            break;

        case 20: // Read Sequential
            bdos_read_sequential(cpu);
            break;

        case 21: // Write Sequential
            bdos_write_sequential(cpu);
            break;

        case 22: // Make File
            bdos_make_file(cpu);
            break;

        case 23: // Rename File
            bdos_rename_file(cpu);
            break;

        case 26: { // Set DMA Address
            unsigned int dma = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
            printf("\n[BDOS-26: Set DMA Address → 0x%04X]\n", dma);
            fflush(stdout);
            cpm_disk.dma_address = dma;
            (cpu->reg)[A] = 0; // Success
            break;
        }

        default:
            printf("\n[BDOS: Unimplemented function %d]\n", function);
            (cpu->reg)[A] = 0xFF; // Error
            break;
    }
}

// ============================================================================
// DISK EMULATION
// ============================================================================

static int get_disk_path(char *buffer, size_t size, const char *filename) {
    if (!buffer || size == 0) {
        return 0;
    }
    const char *base = disk_base_path[0] != '\0' ? disk_base_path : getenv("HOME");
    if (!base) {
        return 0;
    }
    if (disk_base_path[0] != '\0') {
        int written = snprintf(buffer, size, "%s/%s", base, filename);
        return (written > 0 && (size_t)written < size);
    }
    int written = snprintf(buffer, size, "%s/Documents/%s", base, filename);
    return (written > 0 && (size_t)written < size);
}

void cpm_set_disk_base_path(const char *path) {
    if (!path) {
        disk_base_path[0] = '\0';
        return;
    }
    snprintf(disk_base_path, sizeof(disk_base_path), "%s", path);
}

static int load_disk_image(const char *filename, unsigned char *disk, size_t size) {
    char path[512];
    if (!get_disk_path(path, sizeof(path), filename)) {
        return 0;
    }
    FILE *f = fopen(path, "rb");
    if (!f) {
        printf("[Disk] ERROR: Failed to open %s (%s)\n", path, strerror(errno));
        fflush(stdout);
        return 0;
    }
    fseek(f, 0, SEEK_END);
    long file_size = ftell(f);
    fseek(f, 0, SEEK_SET);
    printf("[Disk] Loading image %s (%ld bytes)\n", path, file_size);
    fflush(stdout);
    if (file_size != (long)size) {
        fclose(f);
        printf("[Disk] ERROR: Image size mismatch (expected %lu)\n", (unsigned long)size);
        fflush(stdout);
        return 0;
    }
    size_t read_size = fread(disk, 1, size, f);
    fclose(f);
    if (read_size != size) {
        return 0;
    }
    printf("[Disk] Loaded image %s\n", path);
    fflush(stdout);
    return 1;
}

static void save_disk_image(const char *filename, unsigned char *disk, size_t size) {
    char path[512];
    if (!get_disk_path(path, sizeof(path), filename)) {
        return;
    }
    FILE *f = fopen(path, "wb");
    if (!f) {
        printf("[Disk] ERROR: Failed to save %s (%s)\n", path, strerror(errno));
        fflush(stdout);
        return;
    }
    size_t written = fwrite(disk, 1, size, f);
    fclose(f);
    if (written != size) {
        printf("[Disk] ERROR: Short write saving %s\n", path);
        fflush(stdout);
        return;
    }
}

static void cpm_disk_load_images(void) {
    disk_a_loaded = load_disk_image("A.DSK", disk_a, sizeof(disk_a));
    disk_b_loaded = load_disk_image("B.DSK", disk_b, sizeof(disk_b));
    printf("[Disk] A.DSK loaded: %s\n", disk_a_loaded ? "yes" : "no");
    printf("[Disk] B.DSK loaded: %s\n", disk_b_loaded ? "yes" : "no");
    fflush(stdout);
}

static void cpm_disk_save_current(void) {
    if (cpm_disk.current_disk == 0) {
        save_disk_image("A.DSK", disk_a, sizeof(disk_a));
    } else {
        save_disk_image("B.DSK", disk_b, sizeof(disk_b));
    }
}

void cpm_disk_init(void) {
    memset(&cpm_disk, 0, sizeof(disk_state));
    cpm_disk.dma_address = 0x0080; // Default DMA address
    memset(disk_a, 0xE5, sizeof(disk_a)); // Fill with 0xE5 (CP/M empty marker)
    memset(disk_b, 0xE5, sizeof(disk_b));
    cpm_disk_load_images();
    disk_dir_base_offset[0] = detect_directory_base_offset(disk_a, sizeof(disk_a));
    disk_dir_base_offset[1] = detect_directory_base_offset(disk_b, sizeof(disk_b));
    cpm_disk.dir_base_offset = disk_dir_base_offset[cpm_disk.current_disk];
    printf("[Disk] Directory base offset A: %u bytes\n", disk_dir_base_offset[0]);
    printf("[Disk] Directory base offset B: %u bytes\n", disk_dir_base_offset[1]);
    fflush(stdout);

    printf("[Disk] Initialized 2 drives (A: and B:)\n");
    printf("[Disk] Size: 256KB each (77 tracks × 26 sectors × 128 bytes)\n");
    fflush(stdout);
}

void cpm_select_disk(unsigned char disk) {
    cpm_disk.current_disk = disk;
    cpm_disk.dir_base_offset = disk_dir_base_offset[disk];
    printf("[Disk] Selected drive %c:\n", 'A' + disk);
    fflush(stdout);
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
    printf("[Disk] Home: Track 0\n");
    fflush(stdout);
}

int cpm_read_sector(void) {
    // Validate sector number (CP/M sectors are 1-26)
    if (cpm_disk.current_sector < 1 || cpm_disk.current_sector > 26) {
        printf("[Disk] ERROR: Invalid sector %d\n", cpm_disk.current_sector);
        return 1;
    }

    // Calculate offset in disk image
    int offset = (cpm_disk.current_track * 26 + (cpm_disk.current_sector - 1)) * 128;

    // Select disk image
    unsigned char *disk = (cpm_disk.current_disk == 0) ? disk_a : disk_b;

    // Copy sector to DMA address
    for (int i = 0; i < 128; i++) {
        mem[cpm_disk.dma_address + i] = disk[offset + i];
    }

    printf("[Disk] Read %c: T%d S%d → DMA 0x%04X\n",
           'A' + cpm_disk.current_disk,
           cpm_disk.current_track,
           cpm_disk.current_sector,
           cpm_disk.dma_address);
    fflush(stdout);

    return 0; // Success
}

int cpm_write_sector(void) {
    // Validate sector number
    if (cpm_disk.current_sector < 1 || cpm_disk.current_sector > 26) {
        printf("[Disk] ERROR: Invalid sector %d\n", cpm_disk.current_sector);
        return 1;
    }

    // Calculate offset in disk image
    int offset = (cpm_disk.current_track * 26 + (cpm_disk.current_sector - 1)) * 128;

    // Select disk image
    unsigned char *disk = (cpm_disk.current_disk == 0) ? disk_a : disk_b;

    // Copy from DMA address to sector
    for (int i = 0; i < 128; i++) {
        disk[offset + i] = mem[cpm_disk.dma_address + i];
    }

    printf("[Disk] Write %c: T%d S%d ← DMA 0x%04X\n",
           'A' + cpm_disk.current_disk,
           cpm_disk.current_track,
           cpm_disk.current_sector,
           cpm_disk.dma_address);
    fflush(stdout);
    cpm_disk_save_current();

    return 0; // Success
}

// ============================================================================
// CP/M FILE SYSTEM
// ============================================================================

// FCB (File Control Block) structure - 32 bytes
typedef struct {
    unsigned char drive;           // 0: use default, 1-16: A-P
    char filename[8];              // Filename, padded with spaces
    char extension[3];             // Extension, padded with spaces
    unsigned char extent_low;      // Extent number (low byte)
    unsigned char reserved[2];     // Reserved bytes
    unsigned char record_count;    // Records in current extent (0-128)
    unsigned char allocation[16];  // Block allocation map
} fcb_t;

// Directory entry structure (same as FCB for directory storage)
typedef struct {
    unsigned char user_number;     // 0-15 user, 0xE5 = deleted
    char filename[8];
    char extension[3];
    unsigned char extent_low;
    unsigned char reserved[2];
    unsigned char record_count;
    unsigned char allocation[16];
} dir_entry_t;

// Helper: Get pointer to current disk
unsigned char* get_current_disk(void) {
    return (cpm_disk.current_disk == 0) ? disk_a : disk_b;
}

static int is_valid_dir_char(unsigned char ch) {
    ch &= 0x7F;
    if (ch == ' ' || ch == 0x00) {
        return 1;
    }
    if ((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')) {
        return 1;
    }
    return 0;
}

static int entry_is_blank(const unsigned char *entry) {
    for (int i = 0; i < 11; i++) {
        unsigned char ch = entry[1 + i] & 0x7F;
        if (ch != 0x00 && ch != ' ') {
            return 0;
        }
    }
    return 1;
}

static int entry_has_filename(const unsigned char *entry) {
    for (int i = 0; i < 8; i++) {
        unsigned char ch = entry[1 + i] & 0x7F;
        if (ch != 0x00 && ch != ' ') {
            return 1;
        }
    }
    return 0;
}

static int entry_looks_valid(const unsigned char *entry) {
    unsigned char user = entry[0];
    if (user == 0xE5 || user > 0x1F) {
        return 0;
    }

    if (entry_is_blank(entry) || !entry_has_filename(entry)) {
        return 0;
    }

    for (int i = 0; i < 11; i++) {
        unsigned char ch = entry[1 + i];
        if (!is_valid_dir_char(ch)) {
            return 0;
        }
    }

    return 1;
}

static int directory_score(const unsigned char *disk, int base_offset) {
    int score = 0;
    for (int i = 0; i < 64; i++) {
        const unsigned char *entry = disk + base_offset + (i * 32);
        if (entry_looks_valid(entry)) {
            score++;
        }
    }
    return score;
}

static unsigned int detect_directory_base_offset(const unsigned char *disk, size_t disk_size) {
    int base0 = 0;
    int base2 = 2 * 26 * 128;
    int entry_bytes = 64 * 32;

    if (base2 + entry_bytes > (int)disk_size) {
        return 0;
    }

    int score0 = directory_score(disk, base0);
    int score2 = directory_score(disk, base2);
    if (score2 > score0) {
        return (unsigned int)base2;
    }

    return (unsigned int)base0;
}

// Helper: Read directory entry (0-63 for tracks 0-1)
void read_dir_entry(int entry_num, dir_entry_t* entry) {
    unsigned char* disk = get_current_disk();
    int sector_offset = entry_num / 4;  // 4 entries per sector
    int entry_offset = entry_num % 4;   // Which entry in sector
    int disk_offset = (int)cpm_disk.dir_base_offset + sector_offset * 128 + entry_offset * 32;
    memcpy(entry, &disk[disk_offset], 32);
}

// Helper: Write directory entry
void write_dir_entry(int entry_num, dir_entry_t* entry) {
    unsigned char* disk = get_current_disk();
    int sector_offset = entry_num / 4;
    int entry_offset = entry_num % 4;
    int disk_offset = (int)cpm_disk.dir_base_offset + sector_offset * 128 + entry_offset * 32;
    memcpy(&disk[disk_offset], entry, 32);
    cpm_disk_save_current();
}

// Helper: Compare filename and extension
int fcb_match(dir_entry_t* entry, fcb_t* fcb) {
    // Check if entry is deleted
    if (entry->user_number == 0xE5) {
        #if DEBUG_DISK_IO
        printf("  [fcb_match] Entry is deleted (0xE5)\n");
        fflush(stdout);
        #endif
        return 0;
    }

    if (!entry_looks_valid((const unsigned char *)entry)) {
        #if DEBUG_DISK_IO
        printf("  [fcb_match] Entry invalid\n");
        fflush(stdout);
        #endif
        return 0;
    }

    #if DEBUG_DISK_IO
    printf("  [fcb_match] Entry: '%.8s.%.3s' vs FCB: '%.8s.%.3s'\n",
           entry->filename, entry->extension, fcb->filename, fcb->extension);
    fflush(stdout);
    #endif

    // Compare filename (handle ? wildcards)
    for (int i = 0; i < 8; i++) {
        if (fcb->filename[i] != '?' && fcb->filename[i] != entry->filename[i]) {
            #if DEBUG_DISK_IO
            printf("  [fcb_match] Filename mismatch at position %d: '%c' != '%c'\n",
                   i, fcb->filename[i], entry->filename[i]);
            fflush(stdout);
            #endif
            return 0;
        }
    }

    // Compare extension (handle ? wildcards)
    for (int i = 0; i < 3; i++) {
        if (fcb->extension[i] != '?' && fcb->extension[i] != entry->extension[i]) {
            #if DEBUG_DISK_IO
            printf("  [fcb_match] Extension mismatch at position %d: '%c' != '%c'\n",
                   i, fcb->extension[i], entry->extension[i]);
            fflush(stdout);
            #endif
            return 0;
        }
    }

    #if DEBUG_DISK_IO
    printf("  [fcb_match] MATCH!\n");
    fflush(stdout);
    #endif
    return 1;
}

// Helper: Find directory entry for FCB
int find_dir_entry(fcb_t* fcb) {
    dir_entry_t entry;

    for (int i = 0; i < 64; i++) {  // 64 directory entries in tracks 0-1
        read_dir_entry(i, &entry);
        if (fcb_match(&entry, fcb) && entry.extent_low == fcb->extent_low) {
            return i;
        }
    }

    return -1;  // Not found
}

// Helper: Find free directory entry
int find_free_dir_entry(void) {
    dir_entry_t entry;

    for (int i = 0; i < 64; i++) {
        read_dir_entry(i, &entry);
        if (entry.user_number == 0xE5 || entry_is_blank((const unsigned char *)&entry) ||
            !entry_has_filename((const unsigned char *)&entry)) {
            return i;
        }
    }

    return -1;  // Directory full
}

// BDOS Function 15: Open File
int bdos_open_file(struct i8080* cpu) {
    unsigned int fcb_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
    fcb_t fcb;
    memcpy(&fcb, &mem[fcb_addr], 32);

    #if DEBUG_DISK_IO
    printf("\n[BDOS-15: Open File] %.8s.%.3s\n", fcb.filename, fcb.extension);
    fflush(stdout);
    #endif

    int dir_index = find_dir_entry(&fcb);

    if (dir_index >= 0) {
        // File found - copy directory entry to FCB
        dir_entry_t entry;
        read_dir_entry(dir_index, &entry);

        // Fall back to allocated blocks if record count wasn't set.
        if (entry.record_count == 0) {
            int blocks = 0;
            while (blocks < 16 && entry.allocation[blocks] != 0) {
                blocks++;
            }
            if (blocks > 0) {
                entry.record_count = blocks * 8;
            }
        }

        // Copy allocation and record count back to FCB in memory
        memcpy(&mem[fcb_addr + 16], entry.allocation, 16);
        mem[fcb_addr + 15] = entry.record_count;
        mem[fcb_addr + 32] = 0;  // Current record (CR) = 0

        #if DEBUG_DISK_IO
        printf("[BDOS-15: File opened, %d records]\n", entry.record_count);
        fflush(stdout);
        #endif

        (cpu->reg)[A] = 0;  // Success
        return 0;
    } else {
        #if DEBUG_DISK_IO
        printf("[BDOS-15: File not found]\n");
        fflush(stdout);
        #endif

        (cpu->reg)[A] = 0xFF;  // File not found
        return 1;
    }
}

// BDOS Function 16: Close File
int bdos_close_file(struct i8080* cpu) {
    unsigned int fcb_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
    fcb_t fcb;
    memcpy(&fcb, &mem[fcb_addr], 32);

    #if DEBUG_DISK_IO
    printf("\n[BDOS-16: Close File] %.8s.%.3s\n", fcb.filename, fcb.extension);
    fflush(stdout);
    #endif

    int dir_index = find_dir_entry(&fcb);

    if (dir_index >= 0) {
        // Update directory entry with FCB data
        dir_entry_t entry;
        entry.user_number = 0;  // User 0
        memcpy(entry.filename, fcb.filename, 8);
        memcpy(entry.extension, fcb.extension, 3);
        entry.extent_low = fcb.extent_low;
        entry.reserved[0] = 0;
        entry.reserved[1] = 0;
        entry.record_count = mem[fcb_addr + 15];
        memcpy(entry.allocation, &mem[fcb_addr + 16], 16);

        write_dir_entry(dir_index, &entry);

        #if DEBUG_DISK_IO
        printf("[BDOS-16: File closed]\n");
        fflush(stdout);
        #endif

        (cpu->reg)[A] = 0;  // Success
        return 0;
    } else {
        (cpu->reg)[A] = 0xFF;  // Error
        return 1;
    }
}

// BDOS Function 22: Make File
int bdos_make_file(struct i8080* cpu) {
    unsigned int fcb_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
    fcb_t fcb;
    memcpy(&fcb, &mem[fcb_addr], 32);

    #if DEBUG_DISK_IO
    printf("\n[BDOS-22: Make File] %.8s.%.3s\n", fcb.filename, fcb.extension);
    fflush(stdout);
    #endif

    // Check if file already exists
    int existing = find_dir_entry(&fcb);
    if (existing >= 0) {
        // File exists, reuse its entry
        dir_entry_t entry;
        entry.user_number = 0;
        memcpy(entry.filename, fcb.filename, 8);
        memcpy(entry.extension, fcb.extension, 3);
        entry.extent_low = 0;
        entry.reserved[0] = 0;
        entry.reserved[1] = 0;
        entry.record_count = 0;
        memset(entry.allocation, 0, 16);

        write_dir_entry(existing, &entry);

        // Update FCB in memory
        mem[fcb_addr + 12] = 0;  // extent_low
        mem[fcb_addr + 15] = 0;  // record_count
        memset(&mem[fcb_addr + 16], 0, 16);  // allocation

        (cpu->reg)[A] = 0;  // Success
        return 0;
    }

    // Find free directory entry
    int dir_index = find_free_dir_entry();

    if (dir_index >= 0) {
        dir_entry_t entry;
        entry.user_number = 0;
        memcpy(entry.filename, fcb.filename, 8);
        memcpy(entry.extension, fcb.extension, 3);
        entry.extent_low = 0;
        entry.reserved[0] = 0;
        entry.reserved[1] = 0;
        entry.record_count = 0;
        memset(entry.allocation, 0, 16);

        write_dir_entry(dir_index, &entry);

        // Update FCB in memory
        mem[fcb_addr + 12] = 0;  // extent_low
        mem[fcb_addr + 15] = 0;  // record_count
        memset(&mem[fcb_addr + 16], 0, 16);  // allocation
        mem[fcb_addr + 32] = 0;  // Current record

        #if DEBUG_DISK_IO
        printf("[BDOS-22: File created at dir entry %d]\n", dir_index);
        fflush(stdout);
        #endif

        (cpu->reg)[A] = 0;  // Success
        return 0;
    } else {
        #if DEBUG_DISK_IO
        printf("[BDOS-22: Directory full]\n");
        fflush(stdout);
        #endif

        (cpu->reg)[A] = 0xFF;  // Directory full
        return 1;
    }
}

// BDOS Function 20: Read Sequential
int bdos_read_sequential(struct i8080* cpu) {
    unsigned int fcb_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
    unsigned char current_record = mem[fcb_addr + 32];  // CR field
    unsigned char record_count = mem[fcb_addr + 15];

    #if DEBUG_DISK_IO
    printf("\n[BDOS-20: Read Sequential] CR=%d, RC=%d\n", current_record, record_count);
    fflush(stdout);
    #endif

    // Check if we've read all records
    if (current_record >= record_count) {
        (cpu->reg)[A] = 1;  // End of file
        return 1;
    }

    // Calculate block and sector
    // For simplicity: 1 block = 1 track, each record = 128 bytes
    // Allocate blocks starting at track 2 (tracks 0-1 are directory)
    unsigned char block = mem[fcb_addr + 16 + (current_record / 8)];
    if (block == 0) {
        (cpu->reg)[A] = 1;  // No block allocated
        return 1;
    }

    // Calculate track and sector
    unsigned char track = block + 1;  // Blocks start at track 2
    unsigned char sector = (current_record % 8) + 1;

    // Read the sector
    cpm_disk.current_track = track;
    cpm_disk.current_sector = sector;
    int result = cpm_read_sector();

    // Increment current record
    mem[fcb_addr + 32] = current_record + 1;

    (cpu->reg)[A] = result ? 1 : 0;
    return result;
}

// BDOS Function 21: Write Sequential
int bdos_write_sequential(struct i8080* cpu) {
    unsigned int fcb_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
    unsigned char current_record = mem[fcb_addr + 32];  // CR field

    #if DEBUG_DISK_IO
    printf("\n[BDOS-21: Write Sequential] CR=%d\n", current_record);
    fflush(stdout);
    #endif

    // Calculate which block we need
    int block_index = current_record / 8;

    // Check if we need to allocate a new block
    if (mem[fcb_addr + 16 + block_index] == 0) {
        // Simple allocation: blocks numbered 1-15 (0 means unallocated)
        // Block N maps to track N+1 (tracks 0-1 are directory, data starts at track 2)
        unsigned char new_block = block_index + 1;
        mem[fcb_addr + 16 + block_index] = new_block;

        #if DEBUG_DISK_IO
        printf("[BDOS-21: Allocated block %d]\n", new_block);
        fflush(stdout);
        #endif
    }

    unsigned char block = mem[fcb_addr + 16 + block_index];
    unsigned char track = block + 1;  // Block 1 → Track 2, Block 2 → Track 3, etc.
    unsigned char sector = (current_record % 8) + 1;

    // Write the sector
    cpm_disk.current_track = track;
    cpm_disk.current_sector = sector;
    int result = cpm_write_sector();

    // Update record count and current record
    if (current_record >= mem[fcb_addr + 15]) {
        mem[fcb_addr + 15] = current_record + 1;  // Update RC
    }
    mem[fcb_addr + 32] = current_record + 1;  // Increment CR

    (cpu->reg)[A] = result ? 1 : 0;
    return result;
}

// Global for directory search continuation
static int search_dir_index = 0;

// BDOS Function 17: Search First
int bdos_search_first(struct i8080* cpu) {
    unsigned int fcb_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
    fcb_t fcb;
    memcpy(&fcb, &mem[fcb_addr], 32);

    #if DEBUG_DISK_IO
    printf("\n[BDOS-17: Search First] %.8s.%.3s\n", fcb.filename, fcb.extension);
    printf("  [BDOS-17: DMA] 0x%04X\n", cpm_disk.dma_address);
    fflush(stdout);
    #endif

    // Start search from directory entry 0
    search_dir_index = 0;

    // Search through directory
    dir_entry_t entry;
    for (int i = 0; i < 64; i++) {
        read_dir_entry(i, &entry);
        if (fcb_match(&entry, &fcb)) {
            // Found a match - copy into DMA slot indicated by directory code
            int dir_code = i % 4;
            memcpy(&mem[cpm_disk.dma_address + (dir_code * 32)], &entry, 32);
            search_dir_index = i + 1;  // Next search starts here

            #if DEBUG_DISK_IO
            printf("[BDOS-17: Found at dir entry %d, returning directory code %d]\n", i, i % 4);
            printf("  [BDOS-17: DMA bytes] ");
            for (int j = 0; j < 16; j++) {
                printf("%02X ", mem[cpm_disk.dma_address + j]);
            }
            printf("\n");
            fflush(stdout);
            #endif

            (cpu->reg)[A] = dir_code;  // Return directory code (0-3) for position in DMA buffer
            return 0;
        }
    }

    #if DEBUG_DISK_IO
    printf("[BDOS-17: Not found]\n");
    fflush(stdout);
    #endif

    (cpu->reg)[A] = 0xFF;  // Not found
    return 1;
}

// BDOS Function 18: Search Next
int bdos_search_next(struct i8080* cpu) {
    unsigned int fcb_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
    fcb_t fcb;
    memcpy(&fcb, &mem[fcb_addr], 32);

    #if DEBUG_DISK_IO
    printf("\n[BDOS-18: Search Next] %.8s.%.3s (from entry %d)\n",
           fcb.filename, fcb.extension, search_dir_index);
    printf("  [BDOS-18: DMA] 0x%04X\n", cpm_disk.dma_address);
    fflush(stdout);
    #endif

    // Continue search from where we left off
    dir_entry_t entry;
    for (int i = search_dir_index; i < 64; i++) {
        read_dir_entry(i, &entry);
        if (fcb_match(&entry, &fcb)) {
            // Found a match - copy into DMA slot indicated by directory code
            int dir_code = i % 4;
            memcpy(&mem[cpm_disk.dma_address + (dir_code * 32)], &entry, 32);
            search_dir_index = i + 1;

            #if DEBUG_DISK_IO
            printf("[BDOS-18: Found at dir entry %d, returning directory code %d]\n", i, i % 4);
            fflush(stdout);
            #endif

            (cpu->reg)[A] = dir_code;  // Return directory code (0-3) for position in DMA buffer
            return 0;
        }
    }

    #if DEBUG_DISK_IO
    printf("[BDOS-18: No more matches]\n");
    fflush(stdout);
    #endif

    (cpu->reg)[A] = 0xFF;  // No more matches
    return 1;
}

// BDOS Function 19: Delete File
int bdos_delete_file(struct i8080* cpu) {
    unsigned int fcb_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];
    fcb_t fcb;
    memcpy(&fcb, &mem[fcb_addr], 32);

    #if DEBUG_DISK_IO
    printf("\n[BDOS-19: Delete File] %.8s.%.3s\n", fcb.filename, fcb.extension);
    fflush(stdout);
    #endif

    int deleted_count = 0;
    dir_entry_t entry;

    // Search and delete all matching entries (handles wildcards)
    for (int i = 0; i < 64; i++) {
        read_dir_entry(i, &entry);
        if (fcb_match(&entry, &fcb)) {
            // Mark as deleted
            entry.user_number = 0xE5;
            write_dir_entry(i, &entry);
            deleted_count++;

            #if DEBUG_DISK_IO
            printf("[BDOS-19: Deleted dir entry %d]\n", i);
            fflush(stdout);
            #endif
        }
    }

    if (deleted_count > 0) {
        (cpu->reg)[A] = 0;  // Success
        return 0;
    } else {
        #if DEBUG_DISK_IO
        printf("[BDOS-19: File not found]\n");
        fflush(stdout);
        #endif

        (cpu->reg)[A] = 0xFF;  // Not found
        return 1;
    }
}

// BDOS Function 23: Rename File
int bdos_rename_file(struct i8080* cpu) {
    unsigned int fcb_addr = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];

    // CP/M Rename FCB format:
    // Bytes 0-11: Old name (drive, filename[8], extension[3])
    // Bytes 16-27: New name (drive, filename[8], extension[3])
    fcb_t old_fcb, new_fcb;

    // Clear structures
    memset(&old_fcb, 0, sizeof(fcb_t));
    memset(&new_fcb, 0, sizeof(fcb_t));

    // Copy old name (drive + 8 chars + 3 chars = 12 bytes)
    old_fcb.drive = mem[fcb_addr];
    memcpy(old_fcb.filename, &mem[fcb_addr + 1], 8);
    memcpy(old_fcb.extension, &mem[fcb_addr + 9], 3);
    old_fcb.extent_low = 0;  // Match extent 0

    // Copy new name from bytes 16-27
    new_fcb.drive = mem[fcb_addr + 16];
    memcpy(new_fcb.filename, &mem[fcb_addr + 17], 8);
    memcpy(new_fcb.extension, &mem[fcb_addr + 25], 3);

    #if DEBUG_DISK_IO
    printf("\n[BDOS-23: Rename File] %.8s.%.3s → %.8s.%.3s\n",
           old_fcb.filename, old_fcb.extension,
           new_fcb.filename, new_fcb.extension);
    fflush(stdout);
    #endif

    // Find the old file
    int dir_index = find_dir_entry(&old_fcb);

    if (dir_index >= 0) {
        // Read the entry
        dir_entry_t entry;
        read_dir_entry(dir_index, &entry);

        // Update with new name
        memcpy(entry.filename, new_fcb.filename, 8);
        memcpy(entry.extension, new_fcb.extension, 3);

        // Write it back
        write_dir_entry(dir_index, &entry);

        #if DEBUG_DISK_IO
        printf("[BDOS-23: Renamed dir entry %d]\n", dir_index);
        fflush(stdout);
        #endif

        (cpu->reg)[A] = 0;  // Success
        return 0;
    } else {
        #if DEBUG_DISK_IO
        printf("[BDOS-23: File not found]\n");
        fflush(stdout);
        #endif

        (cpu->reg)[A] = 0xFF;  // Not found
        return 1;
    }
}

// ============================================================================
// CP/M INITIALIZATION
// ============================================================================

// Helper: Create a sample file on disk
void cpm_create_sample_file(const char* name, const char* ext, const char* content) {
    dir_entry_t entry;

    // Set up directory entry
    entry.user_number = 0;
    memset(entry.filename, ' ', 8);
    memset(entry.extension, ' ', 3);
    memcpy(entry.filename, name, strlen(name) > 8 ? 8 : strlen(name));
    memcpy(entry.extension, ext, strlen(ext) > 3 ? 3 : strlen(ext));
    entry.extent_low = 0;
    entry.reserved[0] = 0;
    entry.reserved[1] = 0;

    // Calculate how many records we need
    int content_len = strlen(content);
    int records = (content_len + 127) / 128;  // Round up
    entry.record_count = records;

    // Allocate blocks (simple: one block per 8 records)
    memset(entry.allocation, 0, 16);
    int blocks_needed = (records + 7) / 8;
    for (int i = 0; i < blocks_needed && i < 16; i++) {
        entry.allocation[i] = i + 1;  // Blocks 1, 2, 3, etc.
    }

    // Find free directory entry
    int dir_index = find_free_dir_entry();
    if (dir_index < 0) return;  // Directory full

    // Write directory entry
    write_dir_entry(dir_index, &entry);

    // Write content to disk
    unsigned char* disk = get_current_disk();
    int offset = 0;
    for (int rec = 0; rec < records; rec++) {
        int block = entry.allocation[rec / 8];
        int track = block + 1;  // Data starts at track 2
        int sector = (rec % 8) + 1;
        int disk_offset = (track * 26 + (sector - 1)) * 128;

        // Copy up to 128 bytes
        for (int i = 0; i < 128; i++) {
            if (offset < content_len) {
                disk[disk_offset + i] = content[offset++];
            } else {
                disk[disk_offset + i] = 0x1A;  // CP/M EOF marker
            }
        }
    }
}

// Helper: Create a sample binary file on disk
void cpm_create_sample_file_bytes(const char* name, const char* ext, const unsigned char* content, int content_len) {
    dir_entry_t entry;

    // Set up directory entry
    entry.user_number = 0;
    memset(entry.filename, ' ', 8);
    memset(entry.extension, ' ', 3);
    memcpy(entry.filename, name, strlen(name) > 8 ? 8 : strlen(name));
    memcpy(entry.extension, ext, strlen(ext) > 3 ? 3 : strlen(ext));
    entry.extent_low = 0;
    entry.reserved[0] = 0;
    entry.reserved[1] = 0;

    // Calculate how many records we need
    int records = (content_len + 127) / 128;  // Round up
    entry.record_count = records;

    // Allocate blocks (simple: one block per 8 records)
    memset(entry.allocation, 0, 16);
    int blocks_needed = (records + 7) / 8;
    for (int i = 0; i < blocks_needed && i < 16; i++) {
        entry.allocation[i] = i + 1;  // Blocks 1, 2, 3, etc.
    }

    // Find free directory entry
    int dir_index = find_free_dir_entry();
    if (dir_index < 0) return;  // Directory full

    // Write directory entry
    write_dir_entry(dir_index, &entry);

    // Write content to disk
    unsigned char* disk = get_current_disk();
    int offset = 0;
    for (int rec = 0; rec < records; rec++) {
        int block = entry.allocation[rec / 8];
        int track = block + 1;  // Data starts at track 2
        int sector = (rec % 8) + 1;
        int disk_offset = (track * 26 + (sector - 1)) * 128;

        // Copy up to 128 bytes
        for (int i = 0; i < 128; i++) {
            if (offset < content_len) {
                disk[disk_offset + i] = content[offset++];
            } else {
                disk[disk_offset + i] = 0x1A;  // CP/M EOF marker
            }
        }
    }
}

void cpm_init(void) {
    cpm_console_init();
    cpm_disk_init();

    if (!disk_a_loaded) {
        // Create some sample files for demo on a fresh disk
        cpm_create_sample_file("WELCOME", "TXT", "Welcome to CP/M 2.2!\r\nType DIR to see files.\r\n");
        cpm_create_sample_file("HELP", "TXT", "Available commands:\r\nDIR - List files\r\nTYPE filename - Display file\r\nERA filename - Delete file\r\nEXIT - Halt system\r\n");
        cpm_create_sample_file("README", "TXT", "This is a CP/M 2.2 emulator running on an Intel 8080 CPU.\r\n\r\nHave fun exploring!\r\n");

        static const unsigned char hello_com[] = {
            0x11, 0x09, 0x01,       // LXI D,0109h
            0x0E, 0x09,             // MVI C,09h
            0xCD, 0x05, 0x00,       // CALL 0005h
            0xC9,                   // RET
            0x48, 0x45, 0x4C, 0x4C, 0x4F, 0x20, 0x46, 0x52,
            0x4F, 0x4D, 0x20, 0x43, 0x4F, 0x4D, 0x21, 0x0D,
            0x0A, 0x24              // "HELLO FROM COM!\r\n$"
        };
        cpm_create_sample_file_bytes("HELLO", "COM", hello_com, sizeof(hello_com));

        static const unsigned char plop_com[] = {
            0x11, 0x09, 0x01,       // LXI D,0109h
            0x0E, 0x16,             // MVI C,16h (BDOS Make File)
            0xCD, 0x05, 0x00,       // CALL 0005h
            0xC9,                   // RET
            0x00,                   // Drive (default)
            0x50, 0x4C, 0x4F, 0x50, 0x20, 0x20, 0x20, 0x20, // "PLOP    "
            0x54, 0x58, 0x54,       // "TXT"
            0x00,                   // Extent low
            0x00, 0x00,             // Reserved
            0x00,                   // Record count
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 // Allocation
        };
        cpm_create_sample_file_bytes("PLOP", "COM", plop_com, sizeof(plop_com));
        save_disk_image("A.DSK", disk_a, sizeof(disk_a));
    }

    printf("\n");
    printf("========================================\n");
    printf("CP/M System Initialized\n");
    printf("BDOS Entry: 0x0005\n");
    printf("Console Ports: 0x00, 0x01\n");
    printf("Disk Ports: 0x10-0x15\n");
    printf("========================================\n");
    if (!disk_a_loaded) {
        printf("Sample files created on drive A:\n");
        printf("  WELCOME.TXT\n");
        printf("  HELP.TXT\n");
        printf("  README.TXT\n");
        printf("  HELLO.COM\n");
        printf("  PLOP.COM\n");
    } else {
        printf("Using disk image from Documents (A.DSK)\n");
    }
    printf("========================================\n");
    printf("CP/M Console Output:\n");
    fflush(stdout);
}

// ============================================================================
// END CP/M SUPPORT
// ============================================================================

unsigned int exec_inst(struct i8080* cpu, unsigned char* mem) {
    unsigned int p = cpu->prog_ctr;
    unsigned char opcode = mem[p];
    unsigned int dest = 0x100 * (cpu->reg)[H] + (cpu->reg)[L];
    unsigned int d8 = mem[p+1];//8-bit data or least sig. part of 16-bit data
    unsigned int d16 = mem[p+2];//Most sig. part of 16-bit data
    unsigned int da = 0x100 * d16 + d8;//Use if 16 bit data refers to an address
    
    switch (opcode) {
            //LXI(dest, d16)
        case 0x01: (cpu->reg)[B] = d16; (cpu->reg)[C] = d8; return p+3;
        case 0x11: (cpu->reg)[D] = d16; (cpu->reg)[E] = d8; return p+3;
        case 0x21: (cpu->reg)[H] = d16; (cpu->reg)[L] = d8; return p+3;
        case 0x31: cpu->stack_ptr = 0x100*d16 + d8; return p+3;
            //Direct addressing: STA, LDA, SHLD, LHLD
        case 0x32: MemWrite(da,(cpu->reg)[A]); /* mem[da] = (cpu->reg)[A]; */return p+3;
        case 0x3a: (cpu->reg)[A] = MemRead(da); /*mem[da];*/ return p+3;
        case 0x22: MemWrite(da,(cpu->reg)[L]); MemWrite(da+1, (cpu->reg)[H]); /* mem[da] = (cpu->reg)[L]; mem[da+1] = (cpu->reg)[H]; */return p+3;
        case 0x2a: (cpu->reg)[L] = MemRead(da); /*mem[da];*/ (cpu->reg)[H] = MemRead(da+1); /*mem[da+1]; */return p+3;
            //STAX, LDAX
        case 0x02: MemWrite(0x100*(cpu->reg)[B]+(cpu->reg)[C], (cpu->reg)[A]); return p+1;
        case 0x12: MemWrite(0x100*(cpu->reg)[D]+(cpu->reg)[E], (cpu->reg)[A]); return p+1;
        case 0x0a: (cpu->reg)[A]=MemRead(0x100*(cpu->reg)[B]+(cpu->reg)[C]); /*mem[0x100*(cpu->reg)[B]+(cpu->reg)[C]]; */return p+1;
        case 0x1a: (cpu->reg)[A]=MemRead(0x100*(cpu->reg)[D]+(cpu->reg)[E]); /*mem[0x100*(cpu->reg)[D]+(cpu->reg)[E]];*/ return p+1;
            //MVI(dest, d8)
        case 0x06: (cpu->reg)[B] = d8; return p+2;
        case 0x16: (cpu->reg)[D] = d8; return p+2;
        case 0x26: (cpu->reg)[H] = d8; return p+2;
        case 0x36: MemWrite(dest, d8); /* mem[dest] = d8; */ return p+2;
        case 0x0e: (cpu->reg)[C] = d8; return p+2;
        case 0x1e: (cpu->reg)[E] = d8; return p+2;
        case 0x2e: (cpu->reg)[L] = d8; return p+2;
        case 0x3e: (cpu->reg)[A] = d8; return p+2;
            //MOV(dest, src)
        case 0x40: return p+1;
        case 0x41: (cpu->reg)[B] = (cpu->reg)[C]; return p+1;
        case 0x42: (cpu->reg)[B] = (cpu->reg)[D]; return p+1;
        case 0x43: (cpu->reg)[B] = (cpu->reg)[E]; return p+1;
        case 0x44: (cpu->reg)[B] = (cpu->reg)[H]; return p+1;
        case 0x45: (cpu->reg)[B] = (cpu->reg)[L]; return p+1;
        case 0x46: (cpu->reg)[B] = MemRead(dest); /*mem[dest];*/ return p+1;
        case 0x47: (cpu->reg)[B] = (cpu->reg)[A]; return p+1;
        case 0x48: (cpu->reg)[C] = (cpu->reg)[B]; return p+1;
        case 0x49: return p+1;
        case 0x4a: (cpu->reg)[C] = (cpu->reg)[D]; return p+1;
        case 0x4b: (cpu->reg)[C] = (cpu->reg)[E]; return p+1;
        case 0x4c: (cpu->reg)[C] = (cpu->reg)[H]; return p+1;
        case 0x4d: (cpu->reg)[C] = (cpu->reg)[L]; return p+1;
        case 0x4e:  (cpu->reg)[C] = MemRead(dest); /*mem[dest];*/ return p+1;
        case 0x4f: (cpu->reg)[C] = (cpu->reg)[A]; return p+1;
        case 0x50: (cpu->reg)[D] = (cpu->reg)[B]; return p+1;
        case 0x51: (cpu->reg)[D] = (cpu->reg)[C]; return p+1;
        case 0x52: return p+1;
        case 0x53: (cpu->reg)[D] = (cpu->reg)[E]; return p+1;
        case 0x54: (cpu->reg)[D] = (cpu->reg)[H]; return p+1;
        case 0x55: (cpu->reg)[D] = (cpu->reg)[L]; return p+1;
        case 0x56: (cpu->reg)[D] = MemRead(dest); /*mem[dest];*/ return p+1;
        case 0x57: (cpu->reg)[D] = (cpu->reg)[A]; return p+1;
        case 0x58: (cpu->reg)[E] = (cpu->reg)[B]; return p+1;
        case 0x59: (cpu->reg)[E] = (cpu->reg)[C]; return p+1;
        case 0x5a: (cpu->reg)[E] = (cpu->reg)[D]; return p+1;
        case 0x5b: return p+1;
        case 0x5c: (cpu->reg)[E] = (cpu->reg)[H]; return p+1;
        case 0x5d: (cpu->reg)[E] = (cpu->reg)[L]; return p+1;
        case 0x5e: (cpu->reg)[E] = MemRead(dest); /*mem[dest];*/ return p+1;
        case 0x5f: (cpu->reg)[E] = (cpu->reg)[A]; return p+1;
        case 0x60: (cpu->reg)[H] = (cpu->reg)[B]; return p+1;
        case 0x61: (cpu->reg)[H] = (cpu->reg)[C]; return p+1;
        case 0x62: (cpu->reg)[H] = (cpu->reg)[D]; return p+1;
        case 0x63: (cpu->reg)[H] = (cpu->reg)[E]; return p+1;
        case 0x64: return p+1;
        case 0x65: (cpu->reg)[H] = (cpu->reg)[L]; return p+1;
        case 0x66:   (cpu->reg)[H] = MemRead(dest); /*mem[dest];*/ return p+1;
        case 0x67: (cpu->reg)[H] = (cpu->reg)[A]; return p+1;
        case 0x68: (cpu->reg)[L] = (cpu->reg)[B]; return p+1;
        case 0x69: (cpu->reg)[L] = (cpu->reg)[C]; return p+1;
        case 0x6a: (cpu->reg)[L] = (cpu->reg)[D]; return p+1;
        case 0x6b: (cpu->reg)[L] = (cpu->reg)[E]; return p+1;
        case 0x6c: (cpu->reg)[L] = (cpu->reg)[H]; return p+1;
        case 0x6d: return p+1;
        case 0x6e: (cpu->reg)[L] = MemRead(dest); /*mem[dest];*/ return p+1;
        case 0x6f: (cpu->reg)[L] = (cpu->reg)[A]; return p+1;
        case 0x70: MemWrite(dest, (cpu->reg)[B]); return p+1; // mem[dest] = (cpu->reg)[B]; return p+1;
        case 0x71: MemWrite(dest, (cpu->reg)[C]); return p+1; // mem[dest] = (cpu->reg)[C]; return p+1;
        case 0x72: MemWrite(dest, (cpu->reg)[D]); return p+1; // mem[dest] = (cpu->reg)[D]; return p+1;
        case 0x73: MemWrite(dest, (cpu->reg)[E]); return p+1; // mem[dest] = (cpu->reg)[E]; return p+1;
        case 0x74: MemWrite(dest, (cpu->reg)[H]); return p+1; // mem[dest] = (cpu->reg)[H]; return p+1;
        case 0x75: MemWrite(dest, (cpu->reg)[L]); return p+1; // mem[dest] = (cpu->reg)[L]; return p+1;
        case 0x76: // halt
#if DEBUG_HALT
            printf("\n========================================\n");
            printf("HALT at PC=0x%04X\n", p);
            printf("========================================\n");
            printf("Registers:\n");
            printf("  A=%02X  B=%02X  C=%02X  D=%02X  E=%02X  H=%02X  L=%02X\n",
                   (cpu->reg)[A], (cpu->reg)[B], (cpu->reg)[C], (cpu->reg)[D],
                   (cpu->reg)[E], (cpu->reg)[H], (cpu->reg)[L]);
            printf("  SP=%04X  PC=%04X\n", cpu->stack_ptr, p);
            printf("Flags: ");
            if (cpu->carry) printf("CY ");
            if (cpu->aux_carry) printf("AC ");
            if (cpu->sign) printf("S ");
            if (cpu->iszero) printf("Z ");
            if (cpu->parity) printf("P ");
            printf("\n========================================\n");
            fflush(stdout);
#endif
            return p;
        case 0x77: MemWrite(dest, (cpu->reg)[A]); return p+1; // mem[dest] = (cpu->reg)[A]; return p+1;
        case 0x78: (cpu->reg)[A] = (cpu->reg)[B]; return p+1;
        case 0x79: (cpu->reg)[A] = (cpu->reg)[C]; return p+1;
        case 0x7a: (cpu->reg)[A] = (cpu->reg)[D]; return p+1;
        case 0x7b: (cpu->reg)[A] = (cpu->reg)[E]; return p+1;
        case 0x7c: (cpu->reg)[A] = (cpu->reg)[H]; return p+1;
        case 0x7d: (cpu->reg)[A] = (cpu->reg)[L]; return p+1;
        case 0x7e: (cpu->reg)[A] = MemRead(dest); /*mem[dest];*/ return p+1;
        case 0x7f: return p+1;
            //Increment/decrement
        case 0x04: (cpu->reg)[B] = increment((cpu->reg)[B], cpu); return p+1;
        case 0x0c: (cpu->reg)[C] = increment((cpu->reg)[C], cpu); return p+1;
        case 0x14: (cpu->reg)[D] = increment((cpu->reg)[D], cpu); return p+1;
        case 0x1c: (cpu->reg)[E] = increment((cpu->reg)[E], cpu); return p+1;
        case 0x24: (cpu->reg)[H] = increment((cpu->reg)[H], cpu); return p+1;
        case 0x2c: (cpu->reg)[L] = increment((cpu->reg)[L], cpu); return p+1;
        case 0x34: MemWrite(dest, increment(MemRead(dest), cpu)); return p+1;
        case 0x3c: (cpu->reg)[A] = increment((cpu->reg)[A], cpu); return p+1;
        case 0x05: // DCR B
            {
                unsigned char old_val = (cpu->reg)[B];
                (cpu->reg)[B] = decrement((cpu->reg)[B], cpu);
#if DEBUG_CPU
                printf("[DCR B] %02X → %02X, zero flag=%d\n", old_val, (cpu->reg)[B], cpu->iszero);
                fflush(stdout);
#endif
            }
            return p+1;
        case 0x0d: (cpu->reg)[C] = decrement((cpu->reg)[C], cpu); return p+1;
        case 0x15: (cpu->reg)[D] = decrement((cpu->reg)[D], cpu); return p+1;
        case 0x1d: (cpu->reg)[E] = decrement((cpu->reg)[E], cpu); return p+1;
        case 0x25: (cpu->reg)[H] = decrement((cpu->reg)[H], cpu); return p+1;
        case 0x2d: (cpu->reg)[L] = decrement((cpu->reg)[L], cpu); return p+1;
        case 0x35: MemWrite(dest, decrement(MemRead(dest), cpu)); return p+1;
        case 0x3d: (cpu->reg)[A] = decrement((cpu->reg)[A], cpu); return p+1;
            //Rotate
        case 0x07: rotate(1, 0, cpu); return p+1;
        case 0x17: rotate(1, 1, cpu); return p+1;
        case 0x0f: rotate(0, 0, cpu); return p+1;
        case 0x1f: rotate(0, 1, cpu); return p+1;
        case 0x27: daa(cpu); return p+1;//DAA - Decimal Adjust Accumulator
        case 0x2f: (cpu->reg)[A] = ~(cpu->reg)[A]; return p+1;
        case 0x37: cpu->carry = 1; return p+1;
        case 0x3f: cpu->carry = !(cpu->carry); return p+1;
            //16-bit inc/dec
        case 0x03: doubleinr(B, cpu); return p+1;
        case 0x13: doubleinr(D, cpu); return p+1;
        case 0x23: doubleinr(H, cpu); return p+1;
        case 0x33: doubleinr(SP, cpu); return p+1;
        case 0x0b: doubledcr(B, cpu); return p+1;
        case 0x1b: doubledcr(D, cpu); return p+1;
        case 0x2b: doubledcr(H, cpu); return p+1;
        case 0x3b: doubledcr(SP, cpu); return p+1;
            //XTHL, XCHG, SPHL
        case 0xe3: xthl(cpu, mem); return p+1;
        case 0xeb: xchg(cpu); return p+1;
        case 0xf9: cpu->stack_ptr = 0x100*(cpu->reg)[H]+(cpu->reg)[L]; return p+1;
            //Arith/logic
        case 0x80: add((cpu->reg)[B], cpu, 0); return p+1;
        case 0x81: add((cpu->reg)[C], cpu, 0); return p+1;
        case 0x82: add((cpu->reg)[D], cpu, 0); return p+1;
        case 0x83: add((cpu->reg)[E], cpu, 0); return p+1;
        case 0x84: add((cpu->reg)[H], cpu, 0); return p+1;
        case 0x85: add((cpu->reg)[L], cpu, 0); return p+1;
        case 0x86: add(MemRead(dest), /*mem[dest];*/ cpu, 0); return p+1;
        case 0x87: add((cpu->reg)[A], cpu, 0); return p+1;
        case 0x88: add((cpu->reg)[B], cpu, 1); return p+1;
        case 0x89: add((cpu->reg)[C], cpu, 1); return p+1;
        case 0x8a: add((cpu->reg)[D], cpu, 1); return p+1;
        case 0x8b: add((cpu->reg)[E], cpu, 1); return p+1;
        case 0x8c: add((cpu->reg)[H], cpu, 1); return p+1;
        case 0x8d: add((cpu->reg)[L], cpu, 1); return p+1;
        case 0x8e: add(MemRead(dest), /*mem[dest];*/ cpu, 1); return p+1;
        case 0x8f: add((cpu->reg)[A], cpu, 1); return p+1;
        case 0x90: sub((cpu->reg)[B], cpu, 0); return p+1;
        case 0x91: sub((cpu->reg)[C], cpu, 0); return p+1;
        case 0x92: sub((cpu->reg)[D], cpu, 0); return p+1;
        case 0x93: sub((cpu->reg)[E], cpu, 0); return p+1;
        case 0x94: sub((cpu->reg)[H], cpu, 0); return p+1;
        case 0x95: sub((cpu->reg)[L], cpu, 0); return p+1;
        case 0x96: sub(MemRead(dest), /*mem[dest];*/ cpu, 0); return p+1;
        case 0x97: sub((cpu->reg)[A], cpu, 0); return p+1;
        case 0x98: sub((cpu->reg)[B], cpu, 1); return p+1;
        case 0x99: sub((cpu->reg)[C], cpu, 1); return p+1;
        case 0x9a: sub((cpu->reg)[D], cpu, 1); return p+1;
        case 0x9b: sub((cpu->reg)[E], cpu, 1); return p+1;
        case 0x9c: sub((cpu->reg)[H], cpu, 1); return p+1;
        case 0x9d: sub((cpu->reg)[L], cpu, 1); return p+1;
        case 0x9e: sub(MemRead(dest), /*mem[dest];*/ cpu, 1); return p+1;
        case 0x9f: sub((cpu->reg)[A], cpu, 1); return p+1;
        case 0xa0: logic(bw_and, (cpu->reg)[B], cpu); return p+1;
        case 0xa1: logic(bw_and, (cpu->reg)[C], cpu); return p+1;
        case 0xa2: logic(bw_and, (cpu->reg)[D], cpu); return p+1;
        case 0xa3: logic(bw_and, (cpu->reg)[E], cpu); return p+1;
        case 0xa4: logic(bw_and, (cpu->reg)[H], cpu); return p+1;
        case 0xa5: logic(bw_and, (cpu->reg)[L], cpu); return p+1;
        case 0xa6: logic(bw_and, MemRead(dest), /*mem[dest];*/ cpu); return p+1;
        case 0xa7: logic(bw_and, (cpu->reg)[A], cpu); return p+1;
        case 0xa8: logic(bw_xor, (cpu->reg)[B], cpu); return p+1;
        case 0xa9: logic(bw_xor, (cpu->reg)[C], cpu); return p+1;
        case 0xaa: logic(bw_xor, (cpu->reg)[D], cpu); return p+1;
        case 0xab: logic(bw_xor, (cpu->reg)[E], cpu); return p+1;
        case 0xac: logic(bw_xor, (cpu->reg)[H], cpu); return p+1;
        case 0xad: logic(bw_xor, (cpu->reg)[L], cpu); return p+1;
        case 0xae: logic(bw_xor, MemRead(dest), /*mem[dest];*/ cpu); return p+1;
        case 0xaf: logic(bw_xor, (cpu->reg)[A], cpu); return p+1;
        case 0xb0: logic(bw_or, (cpu->reg)[B], cpu); return p+1;
        case 0xb1: logic(bw_or, (cpu->reg)[C], cpu); return p+1;
        case 0xb2: logic(bw_or, (cpu->reg)[D], cpu); return p+1;
        case 0xb3: logic(bw_or, (cpu->reg)[E], cpu); return p+1;
        case 0xb4: logic(bw_or, (cpu->reg)[H], cpu); return p+1;
        case 0xb5: logic(bw_or, (cpu->reg)[L], cpu); return p+1;
        case 0xb6: logic(bw_or, MemRead(dest), /*mem[dest];*/ cpu); return p+1;
        case 0xb7: logic(bw_or, (cpu->reg)[A], cpu); return p+1;
        case 0xb8: cmp((cpu->reg)[B], cpu); return p+1;
        case 0xb9: cmp((cpu->reg)[C], cpu); return p+1;
        case 0xba: cmp((cpu->reg)[D], cpu); return p+1;
        case 0xbb: cmp((cpu->reg)[E], cpu); return p+1;
        case 0xbc: cmp((cpu->reg)[H], cpu); return p+1;
        case 0xbd: cmp((cpu->reg)[L], cpu); return p+1;
        case 0xbe: cmp(MemRead(dest), /*mem[dest];*/ cpu); return p+1;
        case 0xbf: cmp((cpu->reg)[A], cpu); return p+1;
            //ADI, ADC, SUI, SBI, ANI, XRI, ORI, CPI
        case 0xc6: add(d8, cpu, 0); return p+2;
        case 0xce: add(d8, cpu, 1); return p+2;
        case 0xd6: sub(d8, cpu, 0); return p+2;
        case 0xde: sub(d8, cpu, 1); return p+2;
        case 0xe6: logic(bw_and, d8, cpu); return p+2;
        case 0xee: logic(bw_xor, d8, cpu); return p+2;
        case 0xf6: logic(bw_or, d8, cpu); return p+2;
        case 0xfe: cmp(d8, cpu); return p+2;
            //16bit A/L
        case 0x09: doubleadd(B, cpu); return p+1;
        case 0x19: doubleadd(D, cpu); return p+1;
        case 0x29: doubleadd(H, cpu); return p+1;
        case 0x39: doubleadd(SP, cpu); return p+1;
            //Push/pop using stack pointer
        case 0xc1: pop(B, cpu, mem); return p+1;
        case 0xd1: pop(D, cpu, mem); return p+1;
        case 0xe1: pop(H, cpu, mem); return p+1;
        case 0xf1: pop(A, cpu, mem); return p+1;
        case 0xc5: push(B, cpu, mem); return p+1;
        case 0xd5: push(D, cpu, mem); return p+1;
        case 0xe5: push(H, cpu, mem); return p+1;
        case 0xf5: push(A, cpu, mem); return p+1;
            //Jumps
        case 0xcb:
        case 0xc3: return da;//JMP
        case 0xc2: // JNZ
#if DEBUG_CPU
            printf("[JNZ] PC=%04X, target=%04X, zero=%d, ", p, da, cpu->iszero);
            if (!(cpu->iszero)) {
                printf("JUMPING to %04X\n", da);
                fflush(stdout);
            } else {
                printf("NOT jumping (continuing to %04X)\n", p+3);
                fflush(stdout);
            }
#endif
            return !(cpu->iszero) ? da : p+3;

        case 0xd2: return !(cpu->carry)  ? da : p+3;//JNC
        case 0xe2: return !(cpu->parity) ? da : p+3;//JPO
        case 0xf2: return !(cpu->sign)   ? da : p+3;//JP
        case 0xca: return  (cpu->iszero) ? da : p+3;//JZ
        case 0xda: return  (cpu->carry)  ? da : p+3;//JC
        case 0xea: return  (cpu->parity) ? da : p+3;//JPE
        case 0xfa: return  (cpu->sign)   ? da : p+3;//JM
        case 0xe9: return 0x100*(cpu->reg)[H]+(cpu->reg)[L];//PCHL
            //Calls
        case 0xcd:
        case 0xdd:
        case 0xed:
        case 0xfd: {
            // CP/M BDOS call trap
            if (da == 0x0005) {
                cpm_bdos_call(cpu);
                // If waiting for input, don't advance PC (retry the CALL)
                if (cpm_console.waiting_for_input) {
                    return p;  // Retry this CALL instruction
                }
                return p+3; // Skip the CALL, act like it returned
            }
            return call(p+3, da, cpu, mem); // Normal CALL
        }
        case 0xc4: return !(cpu->iszero) ? call(p+3, da, cpu, mem) : p+3;//CNZ
        case 0xd4: return !(cpu->carry)  ? call(p+3, da, cpu, mem) : p+3;//CNC
        case 0xe4: return !(cpu->parity) ? call(p+3, da, cpu, mem) : p+3;//CPO
        case 0xf4: return !(cpu->sign)   ? call(p+3, da, cpu, mem) : p+3;//CP
        case 0xcc: return  (cpu->iszero) ? call(p+3, da, cpu, mem) : p+3;//CZ
        case 0xdc: return  (cpu->carry)  ? call(p+3, da, cpu, mem) : p+3;//CC
        case 0xec: return  (cpu->parity) ? call(p+3, da, cpu, mem) : p+3;//CPE
        case 0xfc: return  (cpu->sign)   ? call(p+3, da, cpu, mem) : p+3;//CM
            //Returns
        case 0xc9:
        case 0xd9: return ret(cpu, mem);//RET
        case 0xc0: return !(cpu->iszero) ? ret(cpu, mem) : p+1;//RNZ
        case 0xd0: return !(cpu->carry)  ? ret(cpu, mem) : p+1;//RNC
        case 0xe0: return !(cpu->parity) ? ret(cpu, mem) : p+1;//RPO
        case 0xf0: return !(cpu->sign)   ? ret(cpu, mem) : p+1;//RP
        case 0xc8: return  (cpu->iszero) ? ret(cpu, mem) : p+1;//RZ
        case 0xd8: return  (cpu->carry)  ? ret(cpu, mem) : p+1;//RC
        case 0xe8: return  (cpu->parity) ? ret(cpu, mem) : p+1;//RPE
        case 0xf8: return  (cpu->sign)   ? ret(cpu, mem) : p+1;//RM
            //Restarts
        case 0xc7: return call(p+1, 0x00, cpu, mem);//RST 0
        case 0xcf: return call(p+1, 0x08, cpu, mem);//RST 1
        case 0xd7: return call(p+1, 0x10, cpu, mem);//RST 2
        case 0xdf: return call(p+1, 0x18, cpu, mem);//RST 3
        case 0xe7: return call(p+1, 0x20, cpu, mem);//RST 4
        case 0xef: return call(p+1, 0x28, cpu, mem);//RST 5
        case 0xf7: return call(p+1, 0x30, cpu, mem);//RST 6
        case 0xff: return call(p+1, 0x38, cpu, mem);//RST 7
            
            // IN, OUT - CP/M Console and Disk I/O
        case 0xdb: { // IN instruction
            unsigned char port = d8;
            if (port == 0x00 || port == 0x01) {
                // Console status/input (legacy)
                (cpu->reg)[A] = cpm_console_status();
            } else if (port == 0x15) {
                // Disk operation result (0=success, 1=error)
                (cpu->reg)[A] = 0x00; // Success for now
            }
            // BIOS I/O ports (0xF0-0xFA)
            else if (port == 0xF0) {
                // CONST_PORT - Console status
                (cpu->reg)[A] = cpm_console_status();
            } else if (port == 0xF1) {
                // CONIN_PORT - Console input
                (cpu->reg)[A] = cpm_console_input();
            } else if (port == 0xF8) {
                // DISK_READ - Read sector
                (cpu->reg)[A] = cpm_read_sector();
            } else if (port == 0xF9) {
                // DISK_WRITE - Write sector
                (cpu->reg)[A] = cpm_write_sector();
            } else {
                (cpu->reg)[A] = 0x00; // Other ports return 0
            }
            return p+2;
        }
        case 0xd3: { // OUT instruction
            unsigned char port = d8;
            unsigned char value = (cpu->reg)[A];

            if (port == 0x01) {
                // Console output
                cpm_console_output(value);
            } else if (port == 0x10) {
                // Disk select
#if DEBUG_DISK_IO
                printf("[OUT] Port 0x10: Select disk %d\n", value);
                fflush(stdout);
#endif
                cpm_select_disk(value);
            } else if (port == 0x11) {
                // Set track
#if DEBUG_DISK_IO
                printf("[OUT] Port 0x11: Set track %d\n", value);
                fflush(stdout);
#endif
                cpm_set_track(value);
            } else if (port == 0x12) {
                // Set sector
#if DEBUG_DISK_IO
                printf("[OUT] Port 0x12: Set sector %d\n", value);
                fflush(stdout);
#endif
                cpm_set_sector(value);
            } else if (port == 0x13) {
                // DMA address low byte
                cpm_disk.dma_address = (cpm_disk.dma_address & 0xFF00) | value;
#if DEBUG_DISK_IO
                printf("[OUT] Port 0x13: DMA low=0x%02X (DMA now: 0x%04X)\n", value, cpm_disk.dma_address);
                fflush(stdout);
#endif
            } else if (port == 0x14) {
                // DMA address high byte
                cpm_disk.dma_address = (cpm_disk.dma_address & 0x00FF) | (value << 8);
#if DEBUG_DISK_IO
                printf("[OUT] Port 0x14: DMA high=0x%02X (DMA now: 0x%04X)\n", value, cpm_disk.dma_address);
                fflush(stdout);
#endif
            } else if (port == 0x15) {
                // Disk operation (0=read, 1=write, 2=home)
#if DEBUG_DISK_IO
                printf("[OUT] Port 0x15: Operation=%d ", value);
#endif
                if (value == 0) {
#if DEBUG_DISK_IO
                    printf("(READ)\n");
                    fflush(stdout);
#endif
                    cpm_read_sector();
                } else if (value == 1) {
#if DEBUG_DISK_IO
                    printf("(WRITE)\n");
                    fflush(stdout);
#endif
                    cpm_write_sector();
                } else if (value == 2) {
#if DEBUG_DISK_IO
                    printf("(HOME)\n");
                    fflush(stdout);
#endif
                    cpm_home_disk();
                }
#if DEBUG_DISK_IO
                else {
                    printf("(UNKNOWN)\n");
                    fflush(stdout);
                }
#endif
            }
            // BIOS I/O ports (0xF0-0xFA)
            else if (port == 0xF2) {
                // CONOUT_PORT - Console output
                cpm_console_output(value);
            } else if (port == 0xF3) {
                // DISK_SELECT - Select disk
                cpm_select_disk(value);
            } else if (port == 0xF4) {
                // DISK_TRACK - Set track
                cpm_set_track(value);
            } else if (port == 0xF5) {
                // DISK_SECTOR - Set sector
                cpm_set_sector(value);
            } else if (port == 0xF6) {
                // DISK_DMA_LO - DMA address low byte
                cpm_disk.dma_address = (cpm_disk.dma_address & 0xFF00) | value;
            } else if (port == 0xF7) {
                // DISK_DMA_HI - DMA address high byte
                cpm_disk.dma_address = (cpm_disk.dma_address & 0x00FF) | (value << 8);
            } else if (port == 0xFA) {
                // DISK_HOME - Home disk
                cpm_home_disk();
            }
            return p+2;
        }

            //EI, DI - Enable/Disable Interrupts
        case 0xfb: cpu->interrupt_enable = 1; return p+1;//EI
        case 0xf3: cpu->interrupt_enable = 0; return p+1;//DI

            //NOP
        case 0x00:
        case 0x10:
        case 0x20:
        case 0x30:
        case 0x08:
        case 0x18:
        case 0x28:
        case 0x38: return p+1;
        default: perror("Unrecognized instruction");
    }
    
    return 0;
}



char * dumpRegs(struct i8080* p)
{
    
    sprintf(buffer, "PC:%04X\tA:%02X B:%02X C:%02X D:%02X E:%02X H:%02X L:%02X SP:%04X\n",
            (p->prog_ctr),
            (p->reg)[A], (p->reg)[B], (p->reg)[C], (p->reg)[D],
            (p->reg)[E], (p->reg)[H], (p->reg)[L], (p->stack_ptr));
    
    return buffer;
}

int currentAddressBus(void)
{
    return addressBus;
}

int currentAddress(void)
{
    return cpu.prog_ctr;
}

int currentData(void)
{
    return mem[cpu.prog_ctr];
}

int* instructions(void)
{
    return currentAndNext;
}


char* codestep(void)
{
    currentAndNext[0] = mem[cpu.prog_ctr];
    currentAndNext[1] = mem[cpu.prog_ctr+1];
    currentAndNext[2] = mem[cpu.prog_ctr+2];
    cpu.prog_ctr = exec_inst(&cpu, mem) & 0xFFFF;
    currentAndNext[3] = mem[cpu.prog_ctr];
    currentAndNext[4] = mem[cpu.prog_ctr+1];
    currentAndNext[5] = mem[cpu.prog_ctr+2];
    return dumpRegs(&cpu);
}

char* codereset(void)
{
    // reset all registers

    cpu.prog_ctr = 0;
    cpu.stack_ptr = 0;

    cpu.reg[A] = 0;
    cpu.reg[H] = 0;
    cpu.reg[L] = 0;
    cpu.reg[B] = 0;
    cpu.reg[C] = 0;
    cpu.reg[D] = 0;
    cpu.reg[E] = 0;
    cpu.reg[SP] = 0;

    // Reset flags
    cpu.carry = 0;
    cpu.aux_carry = 0;
    cpu.iszero = 0;
    cpu.parity = 0;
    cpu.sign = 0;

    // Reset interrupt state
    cpu.interrupt_enable = 0;
    cpu.interrupt_pending = 0;
    cpu.interrupt_opcode = 0;

    // Initialize CP/M subsystem
    cpm_init();

    currentAndNext[0] = mem[cpu.prog_ctr];
    currentAndNext[1] = mem[cpu.prog_ctr+1];
    currentAndNext[2] = mem[cpu.prog_ctr+2];
    currentAndNext[3] = mem[cpu.prog_ctr+3];
    currentAndNext[4] = mem[cpu.prog_ctr+4];
    currentAndNext[5] = mem[cpu.prog_ctr+5];

    return dumpRegs(&cpu);
}

void coderun(void)
{
    codestep();
    cpu.prog_ctr = exec_inst(&cpu, mem) & 0xFFFF;
    dumpRegs(&cpu);
}

void codeload(const char *sourcecode, unsigned int org)
{
    unsigned long length = strlen(sourcecode);

    const char *pos = sourcecode;
    for (size_t count = 0; count < length / 2; count++)
    {
        sscanf(pos, "%2hhx",&mem[org + count]);
        pos += 2;
    }
    printf("[Loader] Loaded %lu bytes at address 0x%04X\n", length/2, org);
    fflush(stdout);
}

void cpu_set_pc(unsigned short addr)
{
    cpu.prog_ctr = addr;
    currentAndNext[0] = mem[cpu.prog_ctr];
    currentAndNext[1] = mem[cpu.prog_ctr+1];
    currentAndNext[2] = mem[cpu.prog_ctr+2];
    currentAndNext[3] = mem[cpu.prog_ctr+3];
    currentAndNext[4] = mem[cpu.prog_ctr+4];
    currentAndNext[5] = mem[cpu.prog_ctr+5];
}

// Interrupt support functions
void trigger_interrupt(unsigned char opcode)
{
    // Queue an interrupt with the given opcode (typically RST 0-7)
    cpu.interrupt_pending = 1;
    cpu.interrupt_opcode = opcode;
}

int check_interrupt(void)
{
    // Returns 1 if interrupt should be processed, 0 otherwise
    return (cpu.interrupt_enable && cpu.interrupt_pending);
}

void process_interrupt(void)
{
    // Process pending interrupt if enabled
    if (check_interrupt()) {
        cpu.interrupt_enable = 0; // Disable further interrupts
        cpu.interrupt_pending = 0; // Clear pending flag

        // Execute the interrupt opcode (typically RST instruction)
        unsigned char saved_opcode = mem[cpu.prog_ctr];
        mem[cpu.prog_ctr] = cpu.interrupt_opcode;
        cpu.prog_ctr = exec_inst(&cpu, mem) & 0xFFFF;
        mem[cpu.prog_ctr] = saved_opcode; // Restore (though PC has changed)
    }
}

// CP/M console waiting state
int cpm_is_waiting_for_input(void)
{
    return cpm_console.waiting_for_input;
}

void cpm_clear_waiting(void)
{
    cpm_console.waiting_for_input = 0;
}

void cpm_set_echo(int enable)
{
    cpm_console.input_echo = enable;
}

/*
 int execute8080code(const char *sourcecode) {
 
 //    unsigned char mem[0xFFFF] = { 0 };
 //    unsigned long length = strlen(sourcecode);
 //
 //    struct i8080 cpu;
 //    struct i8080* p = &cpu;
 
 unsigned long length = strlen(sourcecode);
 
 
 // Copy the code into "memory" of our 8080VM
 const char *pos = sourcecode;
 for (size_t count = 0; count < length / 2; count++)
 {
 sscanf(pos, "%2hhx",&mem[count]);
 pos += 2;
 }
 
 // reset all registers
 cpu.reg[A] = 0;
 cpu.reg[H] = 0;
 cpu.reg[L] = 0;
 cpu.reg[B] = 0;
 cpu.reg[C] = 0;
 cpu.reg[D] = 0;
 cpu.reg[E] = 0;
 cpu.reg[SP] = 0;
 
 // Run the code
 runcode(0, p, mem);
 
 return 0;
 }
 */

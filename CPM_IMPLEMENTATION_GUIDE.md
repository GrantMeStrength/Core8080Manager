# CP/M Implementation Guide for Core8080 Emulator

## Overview
This document outlines the steps required to run CP/M 2.2 on the Core8080 emulator.

## 1. Console I/O Implementation (Priority: HIGH)

### What's Needed
CP/M programs interact with the console through I/O ports. We need to:

1. **Implement IN instruction for console input**
   - Port 0x00 or 0x01: Console status (returns 0xFF if key ready, 0x00 if not)
   - Port 0x01: Console data (returns ASCII character)

2. **Implement OUT instruction for console output**
   - Port 0x01: Console output (sends ASCII character to display)

### Implementation Strategy
```c
// In 8080.c, replace the IN/OUT stubs:

// Global I/O state
unsigned char console_input_buffer = 0;
char console_input_ready = 0;

case 0xdb: { // IN instruction
    unsigned char port = d8;
    unsigned char value = 0;

    switch (port) {
        case 0x00: // Console status
            value = console_input_ready ? 0xFF : 0x00;
            break;
        case 0x01: // Console data
            value = console_input_buffer;
            console_input_ready = 0;
            break;
    }
    (cpu->reg)[A] = value;
    return p+2;
}

case 0xd3: { // OUT instruction
    unsigned char port = d8;
    unsigned char value = (cpu->reg)[A];

    if (port == 0x01) {
        // Send character to console output
        send_char_to_console(value);
    }
    return p+2;
}
```

### Swift Integration
```swift
// Add to bridging header:
void set_console_input(unsigned char ch);
unsigned char get_console_output();

// In Swift UI:
func handleKeyPress(_ key: String) {
    if let char = key.first?.asciiValue {
        set_console_input(char)
    }
}
```

---

## 2. Disk Emulation System (Priority: HIGH)

### CP/M Disk Format
- **Track**: 77 tracks per disk (numbered 0-76)
- **Sector**: 26 sectors per track (128 bytes each, numbered 1-26)
- **Total Size**: 77 × 26 × 128 = 256,256 bytes (~250KB per disk)
- **Directory**: First 2 tracks reserved for directory

### Disk I/O Ports
Typically:
- Port 0x10: Disk select (A=0, B=1, C=2, D=3)
- Port 0x11: Track number
- Port 0x12: Sector number
- Port 0x13: DMA address low byte
- Port 0x14: DMA address high byte
- Port 0x15: Disk operation (0=read, 1=write)

### Implementation
```c
// Disk state
unsigned char current_disk = 0;
unsigned char current_track = 0;
unsigned char current_sector = 0;
unsigned int dma_address = 0x0080; // Default DMA address

// Disk images stored as files
unsigned char disk_a[77 * 26 * 128];
unsigned char disk_b[77 * 26 * 128];

void read_sector() {
    int offset = (current_track * 26 + (current_sector - 1)) * 128;
    unsigned char *disk = (current_disk == 0) ? disk_a : disk_b;

    for (int i = 0; i < 128; i++) {
        mem[dma_address + i] = disk[offset + i];
    }
}

void write_sector() {
    int offset = (current_track * 26 + (current_sector - 1)) * 128;
    unsigned char *disk = (current_disk == 0) ? disk_a : disk_b;

    for (int i = 0; i < 128; i++) {
        disk[offset + i] = mem[dma_address + i];
    }
}
```

### iOS File Storage
```swift
// Store disk images in app documents directory
func loadDiskImage(drive: String) -> Data? {
    let filename = "cpm_disk_\(drive).img"
    // Load 256KB disk image from Documents folder
    // Return as Data object to pass to C code
}

func saveDiskImage(drive: String, data: Data) {
    // Save disk image back to Documents folder
}
```

---

## 3. BDOS System Call Interface (Priority: MEDIUM)

### How CP/M System Calls Work
Programs call BDOS by:
```assembly
MVI C, function_number  ; Load function number into C register
MVI E, parameter        ; Load parameter into E (or DE)
CALL 0x0005            ; Call BDOS entry point
```

### BDOS Functions We Need (minimum set)
```
Function  Description
--------  -----------
0         System Reset
1         Console Input (wait for char)
2         Console Output (char in E)
6         Direct Console I/O
9         Print String (terminated by $)
10        Read Console Buffer
11        Get Console Status
13        Reset Disk System
14        Select Disk (disk in E: 0=A, 1=B)
15        Open File
16        Close File
17        Search for First
18        Search for Next
19        Delete File
20        Read Sequential
21        Write Sequential
22        Make File
25        Get Current Disk
26        Set DMA Address
```

### Implementation Strategy
```c
// Trap CALL 0x0005 in exec_inst
// Check if address is 0x0005, then emulate BDOS

void handle_bdos_call(struct i8080* cpu) {
    unsigned char function = (cpu->reg)[C];
    unsigned char param_e = (cpu->reg)[E];
    unsigned int param_de = 0x100 * (cpu->reg)[D] + (cpu->reg)[E];

    switch (function) {
        case 1: // Console Input
            (cpu->reg)[A] = wait_for_console_input();
            break;

        case 2: // Console Output
            send_char_to_console(param_e);
            break;

        case 9: // Print String
            print_string_at(param_de); // Print until '$'
            break;

        case 15: // Open File
            (cpu->reg)[A] = open_file(param_de);
            break;

        // ... implement other functions
    }
}
```

---

## 4. CP/M BIOS Implementation (Priority: MEDIUM)

### BIOS Jump Table
The BIOS starts with a jump table at 0xFA00:

```assembly
BOOT:   JMP  BOOT_CODE    ; Cold start
WBOOT:  JMP  WBOOT_CODE   ; Warm start
CONST:  JMP  CONST_CODE   ; Console status
CONIN:  JMP  CONIN_CODE   ; Console input
CONOUT: JMP  CONOUT_CODE  ; Console output
LIST:   JMP  LIST_CODE    ; List output (printer)
PUNCH:  JMP  PUNCH_CODE   ; Punch output
READER: JMP  READER_CODE  ; Reader input
HOME:   JMP  HOME_CODE    ; Home disk
SELDSK: JMP  SELDSK_CODE  ; Select disk
SETTRK: JMP  SETTRK_CODE  ; Set track number
SETSEC: JMP  SETSEC_CODE  ; Set sector number
SETDMA: JMP  SETDMA_CODE  ; Set DMA address
READ:   JMP  READ_CODE    ; Read sector
WRITE:  JMP  WRITE_CODE   ; Write sector
LISTST: JMP  LISTST_CODE  ; List status
SECTRAN:JMP  SECTRAN_CODE ; Sector translate
```

### BIOS Functions Implementation
```c
// These would be loaded into memory at 0xFA00+
// We can either:
// 1. Load a real BIOS binary
// 2. Emulate BIOS calls by trapping jumps to 0xFA00+ range
```

---

## 5. Memory Initialization

### Loading CP/M into Memory
```c
void load_cpm() {
    // 1. Load CCP at 0xDC00 (CCP.COM - 2KB)
    load_binary_file("ccp.bin", 0xDC00);

    // 2. Load BDOS at 0xE400 (BDOS.COM - 3.5KB)
    load_binary_file("bdos.bin", 0xE400);

    // 3. Load BIOS at 0xFA00 (custom BIOS - 1.5KB)
    load_binary_file("bios.bin", 0xFA00);

    // 4. Set up jump vectors at bottom of memory
    mem[0x0000] = 0xC3; // JMP instruction
    mem[0x0001] = 0x00; // Low byte of warm boot address
    mem[0x0002] = 0xFA; // High byte (0xFA00)

    mem[0x0005] = 0xC3; // JMP instruction
    mem[0x0006] = 0x06; // Low byte of BDOS entry
    mem[0x0007] = 0xE4; // High byte (0xE406)

    // 5. Set up disk parameter headers and tables
    setup_disk_parameters();

    // 6. Initialize default DMA address
    mem[0x0080] = 0x00; // Default command buffer
}
```

---

## 6. File System Support

### CP/M Directory Entry Format
Each directory entry is 32 bytes:
```
Offset  Length  Description
0       1       User number (0-15, 0xE5 if deleted)
1       8       Filename (padded with spaces)
9       3       Extension (padded with spaces)
12      1       Extent number
13      2       Reserved
15      1       Record count
16      16      Disk allocation map
```

### Implementation
```c
typedef struct {
    unsigned char user_number;
    char filename[8];
    char extension[3];
    unsigned char extent;
    unsigned char reserved[2];
    unsigned char record_count;
    unsigned char allocation[16];
} cpm_directory_entry;

// Search for file
int find_file(const char* filename) {
    // Search directory entries on current disk
    // Return directory index or -1 if not found
}

// Open file for reading/writing
int open_cpm_file(const char* filename) {
    // Find file in directory
    // Set up FCB (File Control Block)
    // Return file handle
}
```

---

## 7. Testing Strategy

### Phase 1: Basic I/O
```assembly
; Test program: Echo characters
ORG 0100H
LOOP:
    MVI C, 1      ; BDOS function 1: Console input
    CALL 5        ; Call BDOS
    MOV E, A      ; Move input to E
    MVI C, 2      ; BDOS function 2: Console output
    CALL 5        ; Call BDOS
    JMP LOOP      ; Repeat
```

### Phase 2: Disk Operations
```assembly
; Test program: Read directory
ORG 0100H
    MVI C, 17     ; Search for first
    LXI D, FCB    ; Point to FCB
    CALL 5
    ; ... process directory entry
```

### Phase 3: Run CP/M
- Load full CP/M 2.2
- Boot to CCP prompt (A>)
- Try DIR command
- Run simple .COM programs

---

## 8. Implementation Checklist

### Minimal Working System
- [ ] Console input via IN instruction
- [ ] Console output via OUT instruction
- [ ] Basic BDOS calls (1, 2, 9, 11)
- [ ] Memory layout with CCP/BDOS/BIOS
- [ ] Warm boot vector at 0x0000

### Full CP/M Support
- [ ] Disk emulation (read/write sectors)
- [ ] All essential BDOS calls (0-26)
- [ ] File operations (open, close, read, write)
- [ ] Directory management
- [ ] Disk image persistence (save/load from iOS)

### User Interface Enhancements
- [ ] Terminal emulator view
- [ ] Virtual keyboard for CP/M control characters
- [ ] Disk image management UI
- [ ] Load .COM files from iOS Files app
- [ ] Save/load CP/M session state

---

## 9. Estimated Effort

| Component | Complexity | Estimated Time |
|-----------|------------|----------------|
| Console I/O | Low | 2-4 hours |
| Basic BDOS calls | Medium | 8-12 hours |
| Disk emulation | Medium | 12-16 hours |
| File system | High | 16-24 hours |
| Full BIOS | Medium | 8-12 hours |
| Testing & debugging | High | 16-24 hours |
| UI enhancements | Medium | 8-12 hours |
| **Total** | | **70-104 hours** |

---

## 10. Quick Start Approach

### Fastest Path to "Hello CP/M"

1. **Stub out BDOS calls** (4 hours)
   - Implement functions 1, 2, 9 only
   - Just enough for console I/O

2. **Create minimal BIOS** (4 hours)
   - Console routines only
   - No disk support yet

3. **Load CCP manually** (2 hours)
   - Pre-assemble simple CCP
   - Hard-code in memory

4. **Test with echo program** (2 hours)
   - Verify basic operation

**Total for minimal demo: ~12 hours**

This gives you a working "console" that can run simple programs that only use console I/O.

---

## Resources Needed

### CP/M Binaries
- CP/M 2.2 system files (CCP.COM, BDOS.COM)
- Reference BIOS source code
- Sample .COM programs for testing

### Documentation
- CP/M 2.2 System Alteration Guide
- CP/M 2.2 Interface Guide
- Intel 8080 Assembly Language Reference

### Tools
- CP/M disk image tools (cpmtools)
- Hex editor for examining .COM files
- CP/M cross-assembler (zmac, asz80)

---

## Conclusion

Running CP/M is definitely achievable! The core emulator is solid after our fixes. The main work is:

1. **I/O infrastructure** - Connect emulator ports to iOS UI
2. **System call interface** - Implement BDOS functions
3. **Disk emulation** - Virtual disk drives with file persistence

Start with console I/O and basic BDOS calls for quickest results. You could have a working CP/M console in a weekend of focused coding!

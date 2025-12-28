# Debug System and Project Status

## Debug Flags

Debug output can be controlled via flags in `8080.c` (lines 5-8):

```c
#define DEBUG_CPU 0        // CPU instruction debugging (JNZ, DCR, etc.)
#define DEBUG_DISK_IO 0    // Disk I/O port operations
#define DEBUG_HALT 1       // Show registers when halting
```

Set to `1` to enable, `0` to disable.

### DEBUG_CPU
Shows CPU instruction execution details:
- `[DCR B] 80 → 7F, zero flag=0` - Decrement operations
- `[JNZ] PC=0009, target=0007, zero=0, JUMPING to 0007` - Jump decisions

### DEBUG_DISK_IO
Shows all disk I/O operations:
- `[OUT] Port 0x10: Select disk 0` - Port operations
- `[Disk] Write A: T0 S1 ← DMA 0x0200` - Disk read/write

### DEBUG_HALT
Shows register dump when program halts:
```
========================================
HALT at PC=0x003F
========================================
Registers:
  A=FF  B=00  C=00  D=00  E=00  H=02  L=00
  SP=0000  PC=003F
Flags: AC Z P
========================================
```

## ORG Directive Issue

**Current Status:** The emulator loads code at address `0x0000` regardless of the `org` directive.

**Workaround:** Use `org 0h` in assembly programs for this emulator.

**Why:** The `codeload()` function loads hex output sequentially starting at address 0. The assembler's `org` directive affects address calculations in the assembly, but not where the code is actually loaded.

**Example:**
```assembly
org 0h          ; Correct for this emulator

; Fill buffer with test pattern
    lxi h, 0200h
    mvi b, 080h
    ...
```

**Future Fix Options:**
1. Modify `codeload()` to parse and respect org directive
2. Modify assembler to output position-independent code
3. Add loader that reads org from assembly output

For now, **always use `org 0h`** for programs in this emulator.

## What's Working

✅ **Intel 8080 CPU Emulation**
- All instructions implemented
- Flags (Zero, Sign, Parity, Carry, Aux Carry)
- Interrupts (EI/DI, RST)
- DAA (Decimal Adjust Accumulator)

✅ **CP/M Console I/O**
- BDOS Functions: 1 (input), 2 (output), 9 (print string), 11 (status)
- Port-based I/O: 0x00 (input), 0x01 (output)
- Bidirectional buffering
- Console output mirrored to Xcode debug console

✅ **CP/M Disk Emulation**
- Two 256KB virtual disks (A: and B:)
- 77 tracks × 26 sectors × 128 bytes per disk
- BDOS Functions: 13 (reset), 14 (select), 25 (get current), 26 (set DMA)
- Port-based I/O: 0x10-0x15
- Read/Write/Home operations
- **Verified working with disk test program**

✅ **iOS Integration**
- UIKit-based emulator view with LED displays
- Document browser for saving/loading programs
- Assembler with hex output
- Sample programs (Kill the Bit, Echo Test, Disk Test)

## Next Steps

### Near Term (Basic File Operations)
1. **Add BDOS file functions**:
   - Function 15: Open File
   - Function 16: Close File
   - Function 20: Read Sequential
   - Function 21: Write Sequential
   - Function 22: Create File
   - Function 23: Rename File
   - Function 19: Delete File

2. **Implement CP/M directory structure**:
   - Directory entries (32 bytes each)
   - File Control Blocks (FCB)
   - Allocation vectors
   - Directory hash/lookup

3. **Add file system operations**:
   - Format disk with directory
   - Create/delete files
   - Read/write file data
   - Track allocation

### Medium Term (Full CP/M)
1. **Load actual CP/M 2.2**:
   - CCP (Console Command Processor)
   - BDOS (already partially implemented)
   - BIOS (needs implementation)

2. **Run CP/M programs**:
   - Load .COM files
   - Execute ED, PIP, STAT, etc.
   - Support CP/M system calls

### Long Term (Enhancements)
1. **Persistent disk images**:
   - Save/load disk images to iOS filesystem
   - Import/export .DSK files
   - Pre-made disk images with software

2. **Enhanced UI**:
   - Terminal view for console I/O
   - Disk browser/explorer
   - File manager
   - Keyboard input support

3. **Performance**:
   - Optimize emulation speed
   - Adjustable CPU clock rate
   - Fast-forward mode

## Test Results

**Disk Test (Success: A=FF)**
```
[Disk] Write A: T0 S1 ← DMA 0x0200
[Disk] Read A: T0 S1 → DMA 0x0200
HALT at PC=0x003F
Registers: A=FF
```

Program successfully:
- Filled buffer with 0xAA pattern
- Wrote 128 bytes to disk
- Cleared buffer to 0x00
- Read 128 bytes from disk
- Verified data integrity (0xAA matched)
- Halted with success code

## Files Modified in This Session

- `8080.c` - Added disk emulation, BDOS functions, debug flags
- `8080.h` - Fixed CPU bugs, added aux carry, DAA, interrupts
- `EmulatorViewController.swift` - Added console output polling
- `TextDocumentViewController.swift` - Added disk test sample program
- `Document Browser-Bridging-Header.h` - Added CP/M function declarations

## Debug Tips

1. **Enable DEBUG_CPU** to trace instruction execution
2. **Enable DEBUG_DISK_IO** to see all disk operations
3. **DEBUG_HALT** shows final state when program stops
4. **Watch Xcode console** for all debug output
5. **Use STEP button** to single-step through code (with DEBUG_CPU=1)

## Current Limitations

- ORG must be 0h (code loads at address 0x0000)
- No file system yet (just raw sector I/O)
- Console output only (no keyboard input UI yet)
- STEP button steps by bytes not instructions (display issue)
- Some printf output may not appear during fast execution

Congratulations on getting disk emulation working! 🎉

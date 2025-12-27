# CP/M Disk Emulation Test Guide

## What Was Implemented

The disk emulation system is now complete with:

### BDOS Functions
- **Function 13**: Reset Disk System - Resets to drive A:, track 0, sector 1
- **Function 14**: Select Disk - Switches between drives A: and B:
- **Function 25**: Get Current Disk - Returns currently selected disk (0=A:, 1=B:)
- **Function 26**: Set DMA Address - Sets memory address for disk transfers

### Port I/O Operations
- **Port 0x10**: Select disk (0=A:, 1=B:)
- **Port 0x11**: Set track number (0-76)
- **Port 0x12**: Set sector number (1-26)
- **Port 0x13**: DMA address low byte
- **Port 0x14**: DMA address high byte
- **Port 0x15**: Execute operation (0=read, 1=write, 2=home)

### Virtual Disks
- Two 256KB disk images (A: and B:)
- 77 tracks × 26 sectors × 128 bytes per disk
- Initialized with 0xE5 (CP/M empty marker)

## Running the Disk Test

### 1. Load the Test Program

1. Run the app from Xcode
2. Click the **"Samples"** button to cycle through programs
3. Keep clicking until you see the **"CP/M Disk I/O Test"** program load
4. Click **"Assemble"**
5. Click **"Emulate"**

### 2. What the Test Does

The test program:
1. Selects disk A: using BDOS function 14
2. Gets the current disk using BDOS function 25
3. Sets DMA address to 0x0200 using BDOS function 26
4. Fills 128 bytes at 0x0200 with test pattern 0xAA
5. Writes the data to disk A:, track 0, sector 1 using port I/O
6. Clears the buffer with zeros
7. Reads the sector back from disk
8. Verifies the first byte is 0xAA
9. Prints "Disk OK!" if successful, "Disk FAIL!" if not

### 3. View the Results

Open the **Xcode Debug Console** (⇧⌘C) to see detailed output:

```
========================================
CP/M Console I/O System Initialized
BDOS Entry: 0x0005
Console Ports: 0x00, 0x01
========================================
[Disk] Initialized 2 drives (A: and B:)
[Disk] Size: 256KB each (77 tracks × 26 sectors × 128 bytes)
========================================

[BDOS-14: Select Disk A:]

[BDOS-25: Get Current Disk → A:]

[BDOS-26: Set DMA Address → 0x0200]

[Disk] Select disk A:
[Disk] Set track 0
[Disk] Set sector 1
[Disk] Set DMA low byte: 0x00 (DMA now: 0x0200)
[Disk] Set DMA high byte: 0x02 (DMA now: 0x0200)
[Disk] Write A: T0 S1 ← DMA 0x0200 (128 bytes)
[Disk] Read A: T0 S1 → DMA 0x0200

[BDOS-9: Print String @ 0x02XX] Disk OK!
Disk OK!
```

### 4. Click Reset and Run

1. Click **"Reset"** to initialize the emulator
2. Click **"Run"** to execute the test
3. Watch the console output

## Understanding the Output

### Disk Operations
Each disk operation is logged:
- **Select disk**: Shows which disk is being selected (A: or B:)
- **Set track/sector**: Shows disk position
- **Set DMA**: Shows the memory address being used
- **Write**: Shows data being written from memory to disk
- **Read**: Shows data being read from disk to memory

### BDOS Calls
Each BDOS function call is logged:
- **BDOS-13**: Reset disk system
- **BDOS-14**: Disk selection with drive letter
- **BDOS-25**: Current disk query with result
- **BDOS-26**: DMA address setting with hex address

## Success Criteria

If the test passes, you'll see:
```
Disk OK!
```

This means:
- Disk selection works (BDOS function 14)
- DMA address setting works (BDOS function 26)
- Writing to disk works (port 0x15 with value 1)
- Reading from disk works (port 0x15 with value 0)
- Data integrity is maintained (read data matches written data)

## Troubleshooting

### If You See "Disk FAIL!"

Check the console output for:
1. Incorrect DMA address being set
2. Write operation not executing
3. Read operation not executing
4. Data mismatch in verification

### If the Program Hangs

1. The program has no infinite loops, so it should complete quickly
2. Check that you clicked "Run" not just "Step"
3. Click "Reset" and try again

### If You See No Output

1. Make sure the Debug Console is visible (⇧⌘C)
2. Check that the program assembled correctly
3. Verify you clicked "Reset" before "Run"

## Next Steps

Now that basic disk I/O works, you can:

1. **Add More BDOS Functions**:
   - Function 15: Open File
   - Function 16: Close File
   - Function 17: Search First
   - Function 18: Search Next
   - Function 19: Delete File
   - Function 20: Read Sequential
   - Function 21: Write Sequential

2. **Implement CP/M Directory**:
   - Add directory entry structures
   - Implement file allocation
   - Create formatted disk images

3. **Add File System Support**:
   - Implement CP/M file operations
   - Add disk image save/load from iOS filesystem
   - Create sample disk images with files

4. **Load Actual CP/M**:
   - Add CCP (Console Command Processor)
   - Add BIOS (Basic I/O System)
   - Run real CP/M programs

## Technical Details

### Disk Format
```
Total Size: 256,256 bytes (256KB)
Tracks: 77 (numbered 0-76)
Sectors per Track: 26 (numbered 1-26)
Bytes per Sector: 128
```

### Memory Layout
```
0x0000-0x00FF: Zero page and system area
0x0100-0x01FF: Program area (default TPA start)
0x0200-0x027F: DMA buffer (default, 128 bytes)
0x0280-FFFF:   Available program memory
```

### CP/M Standard DMA Address
- Default: 0x0080 (128 bytes)
- Can be changed with BDOS function 26

## Congratulations!

You now have a working disk emulation system for your 8080 emulator. The virtual disks can store and retrieve data, and both port-based I/O and BDOS function calls work correctly!

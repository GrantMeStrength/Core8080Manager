# CP/M Interactive Shell - Implementation Guide

## What Was Implemented

You now have a fully functional CP/M interactive shell! Phase 1 is complete with all requested features:

### ✅ 1. Terminal View with Keyboard Support
- **File**: `CPMTerminalViewController.swift`
- Full-screen terminal with green-on-black retro styling
- Menlo monospace font for authentic terminal feel
- Custom keyboard toolbar with CP/M control characters (^C, ^Z, ESC)
- Auto-uppercase conversion (CP/M standard)
- Proper character echoing and backspace handling
- Scroll-to-bottom behavior

### ✅ 2. Blocking Console Input (BDOS Function 1)
- **Modified**: `8080.c` lines 154-168
- CPU now properly waits for user input without busy-looping
- Sets `waiting_for_input` flag when no input available
- Emulator pauses execution until character arrives
- Input is properly echoed back to the user

### ✅ 3. Blocking Read Buffer (BDOS Function 10)
- **Modified**: `8080.c` lines 185-254
- Full line editing with backspace support
- Character-by-character reading with echo
- Waits for Enter key before completing
- Properly handles empty lines

### ✅ 4. Simple CCP Assembly Program
- **File**: `TextDocumentViewController.swift` - `loadInteractiveCCP()`
- **Commands Implemented**:
  - `DIR` - List all files on disk
  - `TYPE filename` - Display file contents
  - `ERA filename` - Delete a file
  - `EXIT` - Halt the system
- Proper filename parsing (8.3 format)
- Clean error messages
- Infinite command loop with "A>" prompt

### ✅ 5. Sample Files Pre-loaded
- **Modified**: `8080.c` - `cpm_create_sample_file()`
- Three demo files created automatically:
  - `WELCOME.TXT` - Welcome message
  - `HELP.TXT` - Command reference
  - `README.TXT` - System information

## How to Use

### Step 1: Load the Interactive CCP

1. Open your app in Xcode
2. Click the **"Samples"** button repeatedly to cycle through programs
3. Stop when you see **"CP/M Interactive Shell (CCP)"**
4. Click **"Assemble"**

### Step 2: Launch the Terminal

**Option A**: Add a Terminal button to your storyboard
- Open Main.storyboard
- Find the TextDocumentViewController scene
- Add a UIBarButtonItem to the toolbar
- Set its action to `tapTerminal:`
- Run the app and click the Terminal button

**Option B**: Call it programmatically (temporary test)
Add this to your code somewhere you can trigger it:
```swift
tapTerminal(self)
```

### Step 3: Use the Interactive Shell

Once the terminal opens, you'll see:
```
CP/M 2.2 Terminal
Ready.

A>_
```

Try these commands:

#### List Files
```
A>DIR
  WELCOME .TXT  HELP    .TXT  README  .TXT
```

#### Display File Contents
```
A>TYPE WELCOME.TXT
Welcome to CP/M 2.2!
Type DIR to see files.

A>TYPE HELP.TXT
Available commands:
DIR - List files
TYPE filename - Display file
ERA filename - Delete file
EXIT - Halt system
```

#### Delete a File
```
A>ERA README.TXT
File deleted

A>DIR
  WELCOME .TXT  HELP    .TXT
```

#### Exit
```
A>EXIT
Goodbye!
(System halts)
```

### Keyboard Features

- **^C Button**: Send Ctrl-C (interrupt)
- **^Z Button**: Send Ctrl-Z (EOF marker)
- **ESC Button**: Send Escape character
- **Done Button**: Hide keyboard
- **Auto-uppercase**: All input automatically converted to uppercase (CP/M standard)
- **Backspace**: Works correctly to delete characters

## Technical Details

### How Blocking Input Works

Instead of truly blocking (which would freeze the iOS UI), the system uses a "waiting" flag:

1. When BDOS function 1 or 10 is called with no input available:
   - Set `cpm_console.waiting_for_input = 1`
   - Return immediately without advancing PC
   - Emulator checks this flag before executing instructions

2. When user types a character:
   - Character goes into input buffer via `cpm_put_char()`
   - Next emulator step detects input available
   - BDOS call retries and succeeds
   - Clear `waiting_for_input` flag and continue

3. The emulator loop (in CPMTerminalViewController):
   ```swift
   func emulatorStep() {
       if cpm_is_waiting_for_input() != 0 {
           return  // Don't execute, wait for input
       }
       codestep()  // Execute next instruction
   }
   ```

### File System Details

- **Directory**: First 2 tracks (64 entries max)
- **Data Storage**: Tracks 2-76
- **Allocation**: 1 block = 1 track, 8 records per block
- **Record Size**: 128 bytes
- **EOF Marker**: 0x1A (Ctrl-Z)

### Command Parsing

The CCP uses simple string matching:
1. Read command line into buffer (max 40 chars)
2. Compare first characters to known commands
3. Parse filename from command line (for TYPE, ERA)
4. Call appropriate BDOS functions

## Next Steps

### Immediate Improvements

1. **Add REN Command**: Implement rename functionality
   - Parse two filenames from command line
   - Call BDOS function 23

2. **Add SAVE Command**: Create new files from terminal
   - Read content from console
   - Write to new file

3. **Command History**: Use up/down arrows to recall previous commands

4. **Tab Completion**: Auto-complete filenames

### Phase 2 Enhancements

1. **More Commands**:
   - `STAT` - Show disk statistics
   - `TYPE` with wildcards
   - `COPY` - Copy files
   - `FORMAT` - Format disk

2. **Multiple Disks**:
   - Switch between A: and B:
   - Copy files between disks

3. **Load .COM Files**:
   - Import actual CP/M programs from iOS Files app
   - Execute them in the emulator

### Phase 3 - Full CP/M

1. **Load Real CCP**: Use actual CP/M 2.2 CCP binary
2. **Full BDOS**: Complete all 37 BDOS functions
3. **BIOS**: Implement full CP/M BIOS
4. **Run Classic Software**: WordStar, Turbo Pascal, dBase, etc.

## Troubleshooting

### Terminal Doesn't Appear
- Make sure you assembled the code first
- Check that `tapTerminal` action is connected in storyboard
- Look for errors in Xcode console

### No Input Echo
- Check that `cpm_console.input_echo` is set to 1
- Verify BDOS function 2 (console output) is working

### Commands Don't Work
- Ensure you're typing in UPPERCASE (or let auto-conversion handle it)
- Check spelling exactly: DIR, TYPE, ERA, EXIT
- For TYPE/ERA, include the full filename: `TYPE WELCOME.TXT`

### File Not Found
- Use DIR to see what files exist
- Remember the 8.3 format: 8 chars max for name, 3 for extension
- Filenames are space-padded in memory

## Files Modified/Created

### New Files:
- `CPMTerminalViewController.swift` - Terminal UI
- `CPM_INTERACTIVE_SHELL_GUIDE.md` - This guide

### Modified Files:
- `8080.c`:
  - Console I/O state with waiting flags (lines 56-64)
  - Blocking BDOS function 1 (lines 154-168)
  - Blocking BDOS function 10 with editing (lines 185-254)
  - Sample file creation (lines 973-1024)
  - Helper functions (lines 1557-1570)

- `Document Browser-Bridging-Header.h`:
  - Exposed new C functions (lines 23-25)

- `TextDocumentViewController.swift`:
  - Interactive CCP assembly program (lines 918-1314)
  - Terminal launch action (lines 338-360)
  - Updated sample cycling (lines 362-378)

## Congratulations!

You now have a working CP/M interactive shell! 🎉

You can:
- Type commands interactively
- List files with DIR
- Read files with TYPE
- Delete files with ERA
- Navigate with a real command prompt

This is a huge milestone - you've essentially created a miniature operating system running on an emulated 1970s CPU, all on an iPad!

Have fun exploring your CP/M system!

# CP/M Terminal Guide

## Overview

The app now has a **CP/M Terminal** feature accessible from the main screen:

- **CP/M Terminal** button appears in the Document Browser (before selecting any file)
- **CP/M Terminal** button also appears in the editor toolbar (after opening a file)

Access the terminal anytime using the **"CP/M Terminal" button**!

---

## How to Access CP/M Terminal

### From Document Browser (Main Screen)
```
┌──────────────────────────────────────────────┐
│ Document Browser          [CP/M Terminal]    │ ← Navigation Bar
├──────────────────────────────────────────────┤
│                                              │
│  [+] Create New Document                     │
│                                              │
│  My Programs                                 │
│    killthebit.asm                            │
│    test.asm                                  │
│                                              │
└──────────────────────────────────────────────┘
```

### From Editor (After Opening a File)
```
┌──────────────────────────────────────────────┐
│ [Documents] [Assemble] [Emulate] [Samples]  │
│              [CP/M Terminal] [Done]          │ ← Toolbar
└──────────────────────────────────────────────┘
```

Click **"CP/M Terminal"** from either location to:
1. Load the Interactive Shell program
2. Assemble it automatically
3. Launch the full-screen terminal

---

## 📦 Samples Mode

**Purpose**: Run classic Intel 8080 sample programs with LED blinkenlights visualization

### UI Elements

- **Mode Selector**: Shows "Samples" selected
- **Code Editor**: Editable assembly code
- **Samples Button**: Cycles through programs
- **Assemble Button**: Compiles the code
- **Emulate Button**: Launches LED emulator

### Available Samples

1. **Kill the Bit** - Classic game
2. **CP/M Echo Test** - Simple console I/O test
3. **CP/M Disk Test** - Disk read/write test
4. **CP/M File Operations Test** - File create/read test
5. **CP/M Directory Operations** - Search/rename/delete demo
6. **CP/M CCP Demo** - Automated command demo

### How to Use

1. **Switch to Samples Mode** (if not already)
2. **Click "Samples"** to cycle through programs
3. **Click "Assemble"** to compile
4. **Click "Emulate"** to run with LED visualization
5. Watch the blinking LEDs!

### Visual Feedback

- Code editor is **white/light background**
- Code is **editable** - modify as you like
- LED emulator shows address bus and data bus

---

## 💻 CP/M Terminal Mode

**Purpose**: Interactive CP/M 2.2 operating system with file system

### How It Works

When you click the **"CP/M Terminal"** button in the toolbar:
1. The Interactive Shell program loads automatically
2. Code is assembled automatically
3. Terminal launches in full-screen mode
4. You can start typing commands immediately

### Pre-loaded Files

When you enter Terminal Mode, the system creates:
- **WELCOME.TXT** - Welcome message
- **HELP.TXT** - Command reference
- **README.TXT** - System information

### How to Use

1. **Click "CP/M Terminal" button in toolbar**
   - Interactive Shell loads automatically
   - Code auto-assembles
   - Terminal opens automatically

2. **Start typing commands**
   - Full-screen terminal with green-on-black retro styling
   - Keyboard pops up automatically
   - Commands are auto-converted to uppercase

3. **Try these commands:**
   ```
   A>DIR
   A>TYPE WELCOME.TXT
   A>TYPE HELP.TXT
   A>ERA README.TXT
   A>EXIT
   ```

### Visual Feedback

- Code editor has **gray background** (read-only)
- Code shows the Interactive Shell program
- Terminal is **green-on-black** with monospace font

---

## Available Commands (Terminal Mode)

### DIR
**List all files on disk**
```
A>DIR
  WELCOME .TXT  HELP    .TXT  README  .TXT
```

### TYPE filename
**Display file contents**
```
A>TYPE WELCOME.TXT
Welcome to CP/M 2.2!
Type DIR to see files.
```

### ERA filename
**Delete a file**
```
A>ERA README.TXT
File deleted
```

### EXIT
**Halt the system**
```
A>EXIT
Goodbye!
```

---

## Using Both Modes

### Working with Samples (Default Mode)
1. Use the **"Samples"** button to cycle through programs
2. Click **"Assemble"** to compile
3. Click **"Emulate"** to run with LED visualization

### Launching CP/M Terminal
1. Click **"CP/M Terminal"** button in toolbar
2. Everything happens automatically - just start typing!
3. Close terminal with **"Close"** button to return to samples

---

## UI Flow Diagrams

### Samples Mode Flow (Default)
```
Open App
   ↓
[Edit/View Assembly Code]
   ↓
Click "Samples" → Cycle through programs
   ↓
Click "Assemble" → Compile code
   ↓
Click "Emulate" → LED Emulator opens
```

### CP/M Terminal Flow
```
Click "CP/M Terminal" button in toolbar
   ↓
Interactive Shell loads automatically
   ↓
Code auto-assembles
   ↓
Terminal appears automatically (full-screen)
   ↓
Type commands (DIR, TYPE, ERA, EXIT)
   ↓
Click "Close" to return to editing
```

---

## Visual States

### Main Editor View
```
┌──────────────────────────────────────────────────┐
│ [Documents] [Assemble] [Emulate] [Samples]      │
│              [CP/M Terminal] [Done]              │ ← Toolbar
├──────────────────────────────────────────────────┤
│                                                  │
│  ; Kill the Bit                                  │ ← Editable Code
│  org 0h                                          │   (White background)
│  lxi h, 0                                        │
│  ...                                             │
│                                                  │
├──────────────────────────────────────────────────┤
│  ; Assembled code                                │ ← Assembly Output
│  0000: LXI H, 0000                               │   (Paper background)
│  ...                                             │
└──────────────────────────────────────────────────┘
```

### Terminal Open
```
┌──────────────────────────────────────┐
│ CP/M Terminal                 [Close]│
├──────────────────────────────────────┤
│                                      │
│  CP/M 2.2 Terminal                   │ ← Full-screen
│  Ready.                              │   Green text
│                                      │   Black background
│  A>DIR                               │
│    WELCOME .TXT  HELP    .TXT        │
│                                      │
│  A>_                                 │ ← Cursor
│                                      │
├──────────────────────────────────────┤
│ [^C] [^Z] [ESC]         [Done]       │ ← Keyboard toolbar
└──────────────────────────────────────┘
```

---

## Keyboard Controls (Terminal Mode)

### Automatic Features
- **Auto-uppercase** - All input converts to uppercase (CP/M standard)
- **Echo** - Characters appear as you type
- **Backspace** - Works correctly

### Toolbar Buttons
- **^C** - Send Control-C (interrupt)
- **^Z** - Send Control-Z (EOF)
- **ESC** - Send Escape
- **Done** - Hide keyboard

### Navigation Bar
- **Close** - Exit terminal, return to code view
- **Reset** - Clear terminal and restart emulator

---

## Tips for Best Experience

### For Samples Mode
- **Edit freely** - Modify the assembly code
- **Try different programs** - Click Samples to cycle
- **Watch the LEDs** - See the CPU in action
- **Learn 8080 assembly** - Great educational tool

### For Terminal Mode
- **Don't edit code** - It's auto-managed
- **Use proper filenames** - 8.3 format (FILENAME.EXT)
- **Commands are uppercase** - Type DIR not dir
- **Watch debug output** - Check Xcode console for system messages

---

## Troubleshooting

### "Assemble First" Alert
- Mode switched before assembly completed
- Wait a moment and try again
- Or click "Assemble" manually

### Terminal Doesn't Respond
- Make sure keyboard is visible (tap text area)
- Try the Reset button in navigation bar
- Close and relaunch terminal

### Samples Button Not Cycling
- Check you're in Samples Mode
- Code might be corrupted - tap Samples again

### Can't Edit Code
- You're in Terminal Mode (intentional)
- Switch to Samples Mode to edit freely

---

## Summary

### How to Use Your CP/M System

**For Sample Programs:**
- Use the **"Samples"** button to browse programs
- Click **"Assemble"** to compile
- Click **"Emulate"** to see LED visualization

**For Interactive CP/M:**
- Click **"CP/M Terminal"** in toolbar
- Everything loads automatically
- Start typing commands (DIR, TYPE, ERA, EXIT)

**Simple, one-button access to CP/M!** 🎉

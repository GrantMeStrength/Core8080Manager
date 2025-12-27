# CP/M Console Output Guide

## Viewing CP/M Output in Xcode Console

Since the emulator view's text area shows the code listing, all CP/M console I/O is now mirrored to Xcode's console log.

## How to See the Output

1. **Run the app from Xcode**
2. **Open the Debug Console** (⇧⌘C or View → Debug Area → Activate Console)
3. **Load the CP/M Echo Test**:
   - Click "Samples" button to load the test program
   - Click "Assemble"
   - Click "Emulate"
   - Click "Reset"
   - Click "Run"

## What You'll See

### On Startup (when Reset is clicked):
```
========================================
CP/M Console I/O System Initialized
BDOS Entry: 0x0005
Console Ports: 0x00, 0x01
========================================
CP/M Console Output:

[Input→CP/M] Hello, CP/M!\n
```

### As the Echo Program Runs:
```
Hello, CP/M!
Hello, CP/M!
Hello, CP/M!
Hello, CP/M!
...
```

Each "Hello, CP/M!" represents one full cycle through the input buffer.

## Understanding the Output

### Input Display
```
[Input→CP/M] Hello, CP/M!\n
```
- Shows characters being sent TO the CP/M program
- `\n` represents newline character
- Non-printable characters shown as `[0xXX]`

### Output Display
```
Hello, CP/M!
```
- Shows characters being output BY the CP/M program
- Each character is echoed as it's received
- Newlines create new lines in the console

### BDOS Function Calls
If you use BDOS function 9 (Print String), you'll see:
```
[BDOS-9: Print String @ 0x0150] Welcome to CP/M!
```

### Unimplemented Functions
If the program calls an unimplemented BDOS function:
```
[BDOS: Unimplemented function 15]
```

## Character Encoding

| Character | Display |
|-----------|---------|
| Printable (32-126) | As-is (letters, numbers, symbols) |
| Newline (\n, 0x0A) | New line |
| Carriage Return (\r, 0x0D) | New line |
| Other control chars | `[0xXX]` hex notation |

## Example Full Session

```
========================================
CP/M Console I/O System Initialized
BDOS Entry: 0x0005
Console Ports: 0x00, 0x01
========================================
CP/M Console Output:

[Input→CP/M] Hello, CP/M!\n
Hello, CP/M!
Hello, CP/M!
Hello, CP/M!
Hello, CP/M!
Hello, CP/M!
...
```

The program loops continuously, echoing the input until stopped.

## Debugging Tips

### If You See No Output:
1. Check that you clicked "Run" (not just "Step")
2. Verify the program assembled correctly
3. Check that the hex output contains the echo program code

### If Output Stops:
1. Program may have halted (check if PC is not advancing)
2. Input buffer may be empty
3. Click "Reset" and "Run" again

### To See Individual Steps:
1. Click "Step" instead of "Run"
2. Watch the console for each BDOS call
3. Observe one character echoed per cycle

## Performance Notes

- `fflush(stdout)` is called after each character to ensure immediate display
- Console logging has minimal performance impact
- Large amounts of output may slow down execution slightly

## Next Steps

### Add Interactive Input:
Modify `EmulatorViewController` to capture keyboard input:

```swift
// Add to viewDidLoad():
let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showKeyboard))
view.addGestureRecognizer(tapGesture)

@objc func showKeyboard() {
    let alert = UIAlertController(title: "Send to CP/M",
                                  message: "Enter text:",
                                  preferredStyle: .alert)
    alert.addTextField()
    alert.addAction(UIAlertAction(title: "Send", style: .default) { _ in
        if let text = alert.textFields?.first?.text {
            for char in text.utf8 {
                cpm_put_char(char)
            }
            cpm_put_char(13) // CR
            cpm_put_char(10) // LF
        }
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
}
```

This will let you type messages that get echoed by the CP/M program!

## Congratulations! 🎉

You now have a working CP/M console with full debugging visibility in Xcode's console. You can see exactly what's happening as your 8080 programs run!

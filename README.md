# Core8080

An app for creating, editing and assembling (and now emulating!) 8080 source code files.

## Overview

This project builds on the GitHub project [8080Core](https://github.com/GrantMeStrength/core8080), which combines the Assembler, with the [Document Browser sample](https://developer.apple.com/documentation/uikit/view_controllers/building_a_document_browser-based_app) that Apple publishes to create a basic UI. (This version has many fixes to that project, and you should use this version if possible. The UI stuff shouldn't get in the way.)

![The emulator running](https://raw.githubusercontent.com/GrantMeStrength/Core8080Manager/master/Document%20Browser/screenshots/sim1.png)

The result is an app that can create, load and save Intel 8080 files of type .s, assemble them into hex and octal and watch them run on a virtual 8080 (a totally not-accurate virtual 8080, by the way). It is not a complete macro assembler, but understands the directives ORG, DW and labels. It's hopefully enough to learn the basics of assembly language programming.

![Source code editing and assembled](https://raw.githubusercontent.com/GrantMeStrength/Core8080Manager/master/Document%20Browser/screenshots/sim0.png)

### Updates

* I have added some very basic emulation of the assembled code running. The execution of the instructions was based in part on [i8080-emu](https://github.com/cbrooks90/i8080-emu) by cbrooks90, but has been re-written several times now.

* Once you have Assembled the code, tap on Emulate and you will see a very basic computer system (based on the Altair 8800). You can tap STEP to go through each instruction (not each memory address, so sometimes it'll skip by 2 or 3 locations. This is different from the actual Altair). The upper "LEDs" show the contents of the address shown on the lower "LEDs". You can therefore "run" your code. The position of the program counter will be highlighted in the source code.

* Kill the Bit - an Altair classic - now runs. I had forgotten to implement the IN opcode (even though it currently does nothing, on the Virtual Altair it could be connected to a yet-to-be-created on-screen button). You can add it to an empty document by tapping the Samples menu. I'll add more samples as time permits. Note the timing has been changed from the original, as this emulator runs much slower than the real hardware (!).


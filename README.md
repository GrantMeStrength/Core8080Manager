# 8080CoreManager

An app for creating, editing and assembling (and now emulating!) 8080 source code files.

## Overview

This project builds on the GitHub project [8080Core](https://github.com/GrantMeStrength/core8080), which combines the Assembler, with the [Document Browser sample](https://developer.apple.com/documentation/uikit/view_controllers/building_a_document_browser-based_app) that Apple publishes. 

The result is an app that can create, load and save Intel 8080 files of type .s, and assemble them into hex and octal.


### Updates

* I have added some very basic emulation of the assembled code running (much more work to be done). The execution of the instructions is based in part on [i8080-emu](https://github.com/cbrooks90/i8080-emu) by cbrooks90.

* Once you have Assembled the code, tap on Emulate and you will see a very basic computer system. Tap LOAD to copy the program into memory. You can then tap STEP to go through each instruction (not each memory address, so sometimes it'll skip by 2 or 3 locations). The upper "LEDs" show the contents of the address shown on the lower "LEDs". You can therefore "run" your code.


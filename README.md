# 8080CoreManager

An app for creating, editing and assembling (and now emulating!) 8080 source code files.

## Overview

This project builds on the GitHub project [8080Core](https://github.com/GrantMeStrength/core8080), which contains the Assembler, and the [Document Browser sample](https://developer.apple.com/documentation/uikit/view_controllers/building_a_document_browser-based_app) that Apple publish. The result is an app that can create, load and save files of type .s, and assemble them into hex and octal.


### Updates

* Added some very basic emulation of the assembled code running (much more work to be done). The execution of the instructions is based in part on [i8080-emu](https://github.com/cbrooks90/i8080-emu) by cbrooks90.

* You would only know something is happening by looking at the console output, but a GUI is on the way (probably based on the Altair 8800's blinkenlights).


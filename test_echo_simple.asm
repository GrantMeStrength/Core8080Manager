; Simple CP/M Echo - Minimal version
; Just echoes one character at a time

org 0100h        ; CP/M TPA starts at 0x0100

; Main loop - read and echo forever
loop:
    mvi c, 01h   ; BDOS function 1: Console input (0E 01)
    call 0005h   ; Call BDOS (CD 05 00)
    mov e, a     ; Move char to E (5F)
    mvi c, 02h   ; BDOS function 2: Console output (0E 02)
    call 0005h   ; Call BDOS (CD 05 00)
    jmp loop     ; Jump to loop (C3 00 01)

end

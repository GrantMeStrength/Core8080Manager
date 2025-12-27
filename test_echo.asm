; CP/M Echo Test Program
; Echoes characters typed on the console
; Press Ctrl+C (0x03) to exit

org 0100h        ; CP/M programs start at 0x0100

start:
    ; Print welcome message
    lxi d, welcome
    mvi c, 9     ; BDOS function 9: Print string
    call 5       ; Call BDOS

loop:
    ; Read character from console
    mvi c, 1     ; BDOS function 1: Console input
    call 5       ; Call BDOS

    ; Check for Ctrl+C (exit)
    cpi 3        ; Compare with 0x03
    jz exit      ; Jump to exit if equal

    ; Echo the character
    mov e, a     ; Move character to E register
    mvi c, 2     ; BDOS function 2: Console output
    call 5       ; Call BDOS

    jmp loop     ; Repeat

exit:
    ; Print goodbye message
    lxi d, goodbye
    mvi c, 9     ; BDOS function 9: Print string
    call 5       ; Call BDOS

    ret          ; Return to CP/M (or halt for now)

welcome:
    db 13, 10, 'CP/M Echo Test', 13, 10
    db 'Type characters (Ctrl+C to exit)', 13, 10, '$'

goodbye:
    db 13, 10, 'Goodbye!', 13, 10, '$'

end

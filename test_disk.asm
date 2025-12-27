; CP/M Disk I/O Test
; Tests basic disk operations using both port I/O and BDOS calls

org 100h     ; CP/M programs start at 0x0100

; Initialize: Set up BDOS entry point at 0x0005
; (This is normally done by CP/M loader)

start:
    ; Test 1: Select disk A: using BDOS
    mvi c, 14h       ; BDOS function 14: Select Disk
    mvi e, 00h       ; Drive A: (0)
    call 0005h       ; Call BDOS

    ; Test 2: Get current disk
    mvi c, 19h       ; BDOS function 25: Get Current Disk
    call 0005h       ; Call BDOS
    ; Result in A should be 0

    ; Test 3: Set DMA address to 0x0200
    lxi d, 0200h     ; DE = 0x0200
    mvi c, 1Ah       ; BDOS function 26: Set DMA Address
    call 0005h       ; Call BDOS

    ; Test 4: Write data to disk using port I/O
    ; First, fill memory at 0x0200 with test pattern
    lxi h, 0200h     ; HL = 0x0200
    mvi b, 128       ; 128 bytes (one sector)
    mvi a, 0AAh      ; Test pattern
fill_loop:
    mov m, a         ; Store pattern
    inx h            ; Next byte
    dcr b            ; Decrement counter
    jnz fill_loop    ; Continue until done

    ; Set up disk parameters via ports
    mvi a, 00h       ; Disk A:
    out 10h          ; Port 0x10: Select disk

    mvi a, 00h       ; Track 0
    out 11h          ; Port 0x11: Set track

    mvi a, 01h       ; Sector 1
    out 12h          ; Port 0x12: Set sector

    mvi a, 00h       ; DMA low byte
    out 13h          ; Port 0x13: DMA address low

    mvi a, 02h       ; DMA high byte
    out 14h          ; Port 0x14: DMA address high

    mvi a, 01h       ; Write operation
    out 15h          ; Port 0x15: Execute write

    ; Test 5: Clear the buffer
    lxi h, 0200h     ; HL = 0x0200
    mvi b, 128       ; 128 bytes
    mvi a, 00h       ; Clear with zeros
clear_loop:
    mov m, a         ; Clear byte
    inx h            ; Next byte
    dcr b            ; Decrement counter
    jnz clear_loop   ; Continue until done

    ; Test 6: Read the data back
    mvi a, 00h       ; Read operation
    out 15h          ; Port 0x15: Execute read

    ; Test 7: Verify first byte (should be 0xAA)
    lxi h, 0200h     ; HL = 0x0200
    mov a, m         ; Load first byte
    cpi 0AAh         ; Compare with expected value
    jnz error        ; Jump to error if mismatch

success:
    ; Print success message
    lxi d, msg_ok
    mvi c, 09h       ; BDOS function 9: Print String
    call 0005h
    hlt              ; Stop

error:
    ; Print error message
    lxi d, msg_err
    mvi c, 09h       ; BDOS function 9: Print String
    call 0005h
    hlt              ; Stop

msg_ok:
    db 'Disk test PASSED!$'

msg_err:
    db 'Disk test FAILED!$'

end

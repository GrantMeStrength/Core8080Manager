; Minimal CP/M Bootstrap
; This sets up CP/M vectors and runs a simple command loop
; Load this at 0x0100 and run it

        ORG     0100h

START:
        ; Set up CP/M system vectors
        ; Vector at 0x0000: JMP WBOOT (warm boot)
        LXI     H, WBOOT_VEC
        SHLD    0000h
        MVI     A, 0C3h         ; JMP opcode
        STA     0000h

        ; Vector at 0x0005: JMP BDOS
        ; BDOS is handled by C code via trap
        LXI     H, BDOS_ENTRY
        SHLD    0006h
        MVI     A, 0C3h         ; JMP opcode
        STA     0005h

        ; Print sign-on message
        LXI     D, SIGNON
        MVI     C, 9            ; Print string
        CALL    0005h

; Main command loop
COMMAND_LOOP:
        ; Print prompt "A>"
        LXI     D, PROMPT
        MVI     C, 9
        CALL    0005h

        ; Read command line into buffer at 0x80
        LXI     D, CMDBUF
        MVI     C, 10           ; Read console buffer
        CALL    0005h

        ; Check command
        LXI     H, CMDBUF+2     ; Point to actual text
        LDA     CMDBUF+1        ; Get length
        ORA     A               ; Zero length?
        JZ      COMMAND_LOOP    ; Yes, reprompt

        ; Check for "DIR" command
        MOV     A, M
        CPI     'D'
        JNZ     TRY_TYPE
        INX     H
        MOV     A, M
        CPI     'I'
        JNZ     TRY_TYPE
        INX     H
        MOV     A, M
        CPI     'R'
        JNZ     TRY_TYPE
        CALL    DO_DIR
        JMP     COMMAND_LOOP

TRY_TYPE:
        LXI     H, CMDBUF+2
        MOV     A, M
        CPI     'T'
        JNZ     TRY_EXIT
        INX     H
        MOV     A, M
        CPI     'Y'
        JNZ     TRY_EXIT
        INX     H
        MOV     A, M
        CPI     'P'
        JNZ     TRY_EXIT
        INX     H
        MOV     A, M
        CPI     'E'
        JNZ     TRY_EXIT
        CALL    DO_TYPE
        JMP     COMMAND_LOOP

TRY_EXIT:
        LXI     H, CMDBUF+2
        MOV     A, M
        CPI     'E'
        JNZ     UNKNOWN_CMD
        INX     H
        MOV     A, M
        CPI     'X'
        JNZ     UNKNOWN_CMD
        INX     H
        MOV     A, M
        CPI     'I'
        JNZ     UNKNOWN_CMD
        INX     H
        MOV     A, M
        CPI     'T'
        JNZ     UNKNOWN_CMD
        HLT                     ; Exit

UNKNOWN_CMD:
        LXI     D, ERR_MSG
        MVI     C, 9
        CALL    0005h
        JMP     COMMAND_LOOP

; DIR command - list files
DO_DIR:
        ; Set up wildcard FCB for all files
        LXI     H, SEARCH_FCB
        MVI     M, 0            ; Drive (0 = default)
        INX     H
        MVI     B, 11           ; 11 chars (8.3 filename)
DIR_FILL_WILD:
        MVI     M, '?'          ; Wildcard
        INX     H
        DCR     B
        JNZ     DIR_FILL_WILD

        ; Search for first file
        LXI     D, SEARCH_FCB
        MVI     C, 17           ; Search first
        CALL    0005h

        CPI     0FFh            ; Not found?
        JZ      DIR_DONE

        LXI     D, DIR_HDR
        MVI     C, 9
        CALL    0005h

DIR_NEXT_FILE:
        ; A contains directory code (0-3)
        PUSH    PSW
        LXI     D, SPACE
        MVI     C, 9
        CALL    0005h
        POP     PSW

        ; Display filename from DMA buffer at 0x80
        ANI     03h             ; Get position (0-3)
        ADD     A               ; x2
        ADD     A               ; x4
        ADD     A               ; x8
        ADD     A               ; x16
        ADD     A               ; x32
        ADI     81h             ; Add to 0x80 base, skip drive byte
        MOV     L, A
        MVI     H, 0

        ; Print 8-char filename
        MVI     B, 8
DIR_PRINT_NAME:
        MOV     E, M
        PUSH    H
        PUSH    B
        MVI     C, 2
        CALL    0005h
        POP     B
        POP     H
        INX     H
        DCR     B
        JNZ     DIR_PRINT_NAME

        ; Print dot
        MVI     E, '.'
        MVI     C, 2
        CALL    0005h

        ; Print 3-char extension
        MVI     B, 3
DIR_PRINT_EXT:
        MOV     E, M
        PUSH    H
        PUSH    B
        MVI     C, 2
        CALL    0005h
        POP     B
        POP     H
        INX     H
        DCR     B
        JNZ     DIR_PRINT_EXT

        ; Search for next
        MVI     C, 18           ; Search next
        CALL    0005h
        CPI     0FFh
        JNZ     DIR_NEXT_FILE

DIR_DONE:
        LXI     D, CRLF
        MVI     C, 9
        CALL    0005h
        RET

; TYPE command - display file (simplified - just shows message)
DO_TYPE:
        LXI     D, TYPE_MSG
        MVI     C, 9
        CALL    0005h
        RET

; Warm boot vector (just restart command loop)
WBOOT_VEC:
        JMP     COMMAND_LOOP

; BDOS entry point (handled by C code)
BDOS_ENTRY:
        RET                     ; Should never reach here

; Data
SIGNON:   DB    0Dh, 0Ah
          DB    'CP/M 2.2 Core8080 Edition', 0Dh, 0Ah
          DB    'Type DIR for directory', 0Dh, 0Ah, '$'
PROMPT:   DB    0Dh, 0Ah, 'A>$'
ERR_MSG:  DB    '?$'
DIR_HDR:  DB    0Dh, 0Ah, 'Directory:', 0Dh, 0Ah, '$'
SPACE:    DB    ' $'
CRLF:     DB    0Dh, 0Ah, '$'
TYPE_MSG: DB    'TYPE command - use DIR to see files$'

; Command buffer
CMDBUF:   DB    127             ; Max length
          DB    0               ; Actual length (filled by BDOS)
          DS    128             ; Buffer space

; Search FCB
SEARCH_FCB: DS  36

          END

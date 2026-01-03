; CP/M Console Command Processor (CCP)
; Simplified version with basic built-in commands
; Located at 0xDC00

        ORG     0DC00h

CCP_START:
        LXI     SP, 0100h       ; Set up stack

CCP_PROMPT:
        ; Display prompt: "A>"
        LDA     CDISK           ; Get current disk
        ADI     'A'             ; Convert to letter
        MOV     E, A
        MVI     C, 2            ; BDOS console output
        CALL    0005h
        MVI     E, '>'
        MVI     C, 2
        CALL    0005h

        ; Read command line
        LXI     D, CMDBUF       ; Point to command buffer
        MVI     A, 127          ; Max length
        STA     CMDBUF          ; Store max length
        MVI     C, 10           ; BDOS read console buffer
        CALL    0005h

        ; Check if empty command
        LDA     CMDBUF+1        ; Get actual length
        ORA     A               ; Check if zero
        JZ      CCP_PROMPT      ; Empty, show prompt again

        ; Null-terminate command
        MOV     B, A            ; Length to B
        LXI     H, CMDBUF+2     ; Point to start of text
        MVI     A, 0
        DAD     B               ; HL now points after last char
        MOV     M, A            ; Null terminate

        ; Parse command - get first word
        LXI     H, CMDBUF+2     ; Point to command text
        CALL    SKIP_SPACES     ; Skip leading spaces
        MOV     D, H            ; Save command start
        MOV     E, L

        ; Check for built-in commands
        LXI     H, CMDBUF+2
        CALL    SKIP_SPACES

        ; Compare with "DIR"
        LXI     D, CMD_DIR
        CALL    STRCMP_3
        JZ      DO_DIR

        ; Compare with "TYPE"
        LXI     H, CMDBUF+2
        CALL    SKIP_SPACES
        LXI     D, CMD_TYPE
        CALL    STRCMP_4
        JZ      DO_TYPE

        ; Compare with "ERA"
        LXI     H, CMDBUF+2
        CALL    SKIP_SPACES
        LXI     D, CMD_ERA
        CALL    STRCMP_3
        JZ      DO_ERA

        ; Compare with "REN"
        LXI     H, CMDBUF+2
        CALL    SKIP_SPACES
        LXI     D, CMD_REN
        CALL    STRCMP_3
        JZ      DO_REN

        ; Not a built-in, try to load .COM file
        JMP     LOAD_COM

; =============================================================================
; Built-in Commands
; =============================================================================

DO_DIR:
        ; Print directory listing
        LXI     D, MSG_DIR
        MVI     C, 9
        CALL    0005h

        ; Search for all files (*.*)
        LXI     H, FCB_WILD     ; Wildcard FCB
        MVI     M, 0            ; Drive 0 (default)
        INX     H
        MVI     B, 11           ; 11 bytes for name+ext
        MVI     A, '?'          ; Wildcard
DIR_FILL:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     DIR_FILL

        ; Search first
        LXI     D, FCB_WILD
        MVI     C, 17           ; BDOS search first
        CALL    0005h
        CPI     0FFh            ; Check if found
        JZ      DIR_DONE        ; No files found

DIR_LOOP:
        ; Display filename
        ; A contains directory code (0-3)
        ; Actual entry is at 0x80 + (A * 32)
        ANI     3               ; Get position in buffer
        RLC
        RLC
        RLC
        RLC
        RLC                     ; Multiply by 32
        ADI     81h             ; Add base address (skip drive byte)
        MOV     L, A
        MVI     H, 0            ; HL = address of filename

        ; Print 8-char filename
        MVI     B, 8
DIR_NAME:
        MOV     A, M
        ANI     7Fh             ; Strip high bit
        CPI     ' '
        JZ      DIR_EXT         ; Skip spaces
        MOV     E, A
        PUSH    H
        PUSH    B
        MVI     C, 2
        CALL    0005h
        POP     B
        POP     H
DIR_NAME_NEXT:
        INX     H
        DCR     B
        JNZ     DIR_NAME

DIR_EXT:
        ; Print extension
        MVI     E, '.'
        PUSH    H
        MVI     C, 2
        CALL    0005h
        POP     H
        MVI     B, 3
DIR_EXT_LOOP:
        MOV     A, M
        ANI     7Fh
        MOV     E, A
        PUSH    H
        PUSH    B
        MVI     C, 2
        CALL    0005h
        POP     B
        POP     H
        INX     H
        DCR     B
        JNZ     DIR_EXT_LOOP

        ; Print space
        MVI     E, ' '
        MVI     C, 2
        CALL    0005h
        MVI     E, ' '
        MVI     C, 2
        CALL    0005h

        ; Search next
        MVI     C, 18           ; BDOS search next
        CALL    0005h
        CPI     0FFh
        JNZ     DIR_LOOP

DIR_DONE:
        ; Print newline
        LXI     D, MSG_CRLF
        MVI     C, 9
        CALL    0005h
        JMP     CCP_PROMPT

DO_TYPE:
        ; TYPE command - display file contents
        LXI     D, MSG_TYPE
        MVI     C, 9
        CALL    0005h
        JMP     CCP_PROMPT

DO_ERA:
        ; ERA command - erase file
        LXI     D, MSG_ERA
        MVI     C, 9
        CALL    0005h
        JMP     CCP_PROMPT

DO_REN:
        ; REN command - rename file
        LXI     D, MSG_REN
        MVI     C, 9
        CALL    0005h
        JMP     CCP_PROMPT

LOAD_COM:
        ; Try to load .COM file
        LXI     D, MSG_UNKNOWN
        MVI     C, 9
        CALL    0005h
        JMP     CCP_PROMPT

; =============================================================================
; Helper Functions
; =============================================================================

; Skip spaces in string pointed to by HL
SKIP_SPACES:
        MOV     A, M
        CPI     ' '
        RNZ
        INX     H
        JMP     SKIP_SPACES

; Compare 3-character string at HL with string at DE
; Returns Z flag set if match
STRCMP_3:
        PUSH    H
        PUSH    D
        MVI     B, 3
STRCMP_3_LOOP:
        LDAX    D
        CMP     M
        JNZ     STRCMP_3_FAIL
        INX     H
        INX     D
        DCR     B
        JNZ     STRCMP_3_LOOP
        ; Check if command is followed by space or end
        MOV     A, M
        CPI     ' '
        JZ      STRCMP_3_OK
        CPI     0
        JZ      STRCMP_3_OK
STRCMP_3_FAIL:
        POP     D
        POP     H
        ORI     1               ; Clear Z flag
        RET
STRCMP_3_OK:
        POP     D
        POP     H
        XRA     A               ; Set Z flag
        RET

; Compare 4-character string at HL with string at DE
STRCMP_4:
        PUSH    H
        PUSH    D
        MVI     B, 4
STRCMP_4_LOOP:
        LDAX    D
        CMP     M
        JNZ     STRCMP_4_FAIL
        INX     H
        INX     D
        DCR     B
        JNZ     STRCMP_4_LOOP
        ; Check if command is followed by space or end
        MOV     A, M
        CPI     ' '
        JZ      STRCMP_4_OK
        CPI     0
        JZ      STRCMP_4_OK
STRCMP_4_FAIL:
        POP     D
        POP     H
        ORI     1
        RET
STRCMP_4_OK:
        POP     D
        POP     H
        XRA     A
        RET

; =============================================================================
; Data
; =============================================================================

CDISK:  DB      0               ; Current disk

CMDBUF: DS      128             ; Command buffer

FCB_WILD: DS    36              ; FCB for wildcard searches

; Command strings
CMD_DIR:  DB    'DIR'
CMD_TYPE: DB    'TYPE'
CMD_ERA:  DB    'ERA'
CMD_REN:  DB    'REN'

; Messages
MSG_DIR:     DB  'Directory:', 0Dh, 0Ah, '$'
MSG_TYPE:    DB  'TYPE not implemented yet', 0Dh, 0Ah, '$'
MSG_ERA:     DB  'ERA not implemented yet', 0Dh, 0Ah, '$'
MSG_REN:     DB  'REN not implemented yet', 0Dh, 0Ah, '$'
MSG_UNKNOWN: DB  '?', 0Dh, 0Ah, '$'
MSG_CRLF:    DB  0Dh, 0Ah, '$'

        END

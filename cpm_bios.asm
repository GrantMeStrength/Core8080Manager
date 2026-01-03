; CP/M 2.2 Compatible BIOS for Core8080 Emulator
; Minimal BIOS that interfaces with C emulator functions
;
; Memory layout:
;   0x0000-0x00FF: System vectors and page zero
;   0x0100-0xDBFF: TPA (Transient Program Area)
;   0xDC00-0xE3FF: CCP (Console Command Processor) - 2KB
;   0xE400-0xF9FF: BDOS (Basic Disk Operating System) - 5.5KB
;   0xFA00-0xFFFF: BIOS (Basic I/O System) - 1.5KB

; BIOS entry point is 0xFA00
        ORG     0FA00h

; BIOS Jump Table - Standard CP/M 2.2 Interface
BOOT:   JMP     BOOT_IMPL       ; Cold start
WBOOT:  JMP     WBOOT_IMPL      ; Warm start
CONST:  JMP     CONST_IMPL      ; Console status
CONIN:  JMP     CONIN_IMPL      ; Console input
CONOUT: JMP     CONOUT_IMPL     ; Console output
LIST:   JMP     LIST_IMPL       ; List output (printer)
PUNCH:  JMP     PUNCH_IMPL      ; Punch output (paper tape)
READER: JMP     READER_IMPL     ; Reader input (paper tape)
HOME:   JMP     HOME_IMPL       ; Home disk head
SELDSK: JMP     SELDSK_IMPL     ; Select disk drive
SETTRK: JMP     SETTRK_IMPL     ; Set track number
SETSEC: JMP     SETSEC_IMPL     ; Set sector number
SETDMA: JMP     SETDMA_IMPL     ; Set DMA address
READ:   JMP     READ_IMPL       ; Read disk sector
WRITE:  JMP     WRITE_IMPL      ; Write disk sector
LISTST: JMP     LISTST_IMPL     ; List status
SECTRAN: JMP    SECTRAN_IMPL    ; Sector translate

; =============================================================================
; BIOS Implementation
; Each function uses I/O ports to communicate with C emulator
; =============================================================================

; Port definitions for emulator interface
CONST_PORT      EQU     0F0h    ; Console status port
CONIN_PORT      EQU     0F1h    ; Console input port
CONOUT_PORT     EQU     0F2h    ; Console output port
DISK_SELECT     EQU     0F3h    ; Disk select port
DISK_TRACK      EQU     0F4h    ; Track number port
DISK_SECTOR     EQU     0F5h    ; Sector number port
DISK_DMA_LO     EQU     0F6h    ; DMA address low byte
DISK_DMA_HI     EQU     0F7h    ; DMA address high byte
DISK_READ       EQU     0F8h    ; Disk read operation
DISK_WRITE      EQU     0F9h    ; Disk write operation
DISK_HOME       EQU     0FAh    ; Disk home operation

; -----------------------------------------------------------------------------
; BOOT - Cold start initialization
; -----------------------------------------------------------------------------
BOOT_IMPL:
        LXI     SP, 0100h       ; Set up stack below TPA
        MVI     A, 0            ; Select disk A:
        STA     CDISK           ; Save current disk
        OUT     DISK_SELECT     ; Tell emulator

        ; Print sign-on message
        LXI     D, SIGNON
        MVI     C, 9            ; BDOS print string
        CALL    0005h           ; Call BDOS

        ; Fall through to warm boot

; -----------------------------------------------------------------------------
; WBOOT - Warm start (reload CCP)
; -----------------------------------------------------------------------------
WBOOT_IMPL:
        LXI     SP, 0100h       ; Reset stack
        MVI     C, 0            ; Select disk A:
        CALL    SELDSK_IMPL

        ; In a full CP/M system, we would reload CCP from disk here
        ; For now, jump to CCP entry point (assuming it's in memory)
        JMP     0DC00h          ; Jump to CCP

; -----------------------------------------------------------------------------
; CONST - Console status
; Returns: A = 0xFF if character ready, 0x00 if not
; -----------------------------------------------------------------------------
CONST_IMPL:
        IN      CONST_PORT      ; Read status from emulator
        RET

; -----------------------------------------------------------------------------
; CONIN - Console input
; Returns: A = character from console
; -----------------------------------------------------------------------------
CONIN_IMPL:
        IN      CONIN_PORT      ; Read character from emulator
        ANI     7Fh             ; Strip high bit
        RET

; -----------------------------------------------------------------------------
; CONOUT - Console output
; Input: C = character to output
; -----------------------------------------------------------------------------
CONOUT_IMPL:
        MOV     A, C            ; Get character
        OUT     CONOUT_PORT     ; Send to emulator
        RET

; -----------------------------------------------------------------------------
; LIST - List output (printer)
; Input: C = character to output
; For this emulator, we just ignore it
; -----------------------------------------------------------------------------
LIST_IMPL:
        RET

; -----------------------------------------------------------------------------
; LISTST - List status
; Returns: A = 0xFF if printer ready, 0x00 if not
; -----------------------------------------------------------------------------
LISTST_IMPL:
        MVI     A, 0FFh         ; Always ready (fake it)
        RET

; -----------------------------------------------------------------------------
; PUNCH - Punch output (paper tape)
; Input: C = character to output
; -----------------------------------------------------------------------------
PUNCH_IMPL:
        RET                     ; Not implemented

; -----------------------------------------------------------------------------
; READER - Reader input (paper tape)
; Returns: A = character
; -----------------------------------------------------------------------------
READER_IMPL:
        MVI     A, 1Ah          ; Return EOF
        RET

; -----------------------------------------------------------------------------
; HOME - Move disk head to track 0
; -----------------------------------------------------------------------------
HOME_IMPL:
        OUT     DISK_HOME       ; Tell emulator to home
        MVI     A, 0
        STA     CTRACK          ; Track 0
        RET

; -----------------------------------------------------------------------------
; SELDSK - Select disk drive
; Input: C = disk number (0=A:, 1=B:, etc.)
; Returns: HL = address of disk parameter header, or 0000h if error
; -----------------------------------------------------------------------------
SELDSK_IMPL:
        MOV     A, C            ; Get disk number
        CPI     2               ; Check if valid (0-1 for A: and B:)
        JNC     SELDSK_ERR      ; Invalid disk

        STA     CDISK           ; Save current disk
        OUT     DISK_SELECT     ; Tell emulator

        ; Return DPH address for this disk
        ; We'll use a simple DPH
        LXI     H, DPH0         ; Return DPH address
        RET

SELDSK_ERR:
        LXI     H, 0            ; Return error
        RET

; -----------------------------------------------------------------------------
; SETTRK - Set track number
; Input: BC = track number
; -----------------------------------------------------------------------------
SETTRK_IMPL:
        MOV     A, C            ; Get track number (only low byte)
        STA     CTRACK          ; Save current track
        OUT     DISK_TRACK      ; Tell emulator
        RET

; -----------------------------------------------------------------------------
; SETSEC - Set sector number
; Input: BC = sector number
; -----------------------------------------------------------------------------
SETSEC_IMPL:
        MOV     A, C            ; Get sector number
        STA     CSECTOR         ; Save current sector
        OUT     DISK_SECTOR     ; Tell emulator
        RET

; -----------------------------------------------------------------------------
; SETDMA - Set DMA address
; Input: BC = DMA address
; -----------------------------------------------------------------------------
SETDMA_IMPL:
        MOV     A, C            ; Low byte
        OUT     DISK_DMA_LO
        STA     CDMA            ; Save DMA low
        MOV     A, B            ; High byte
        OUT     DISK_DMA_HI
        STA     CDMA+1          ; Save DMA high
        RET

; -----------------------------------------------------------------------------
; READ - Read sector
; Returns: A = 0 if OK, 1 if error
; -----------------------------------------------------------------------------
READ_IMPL:
        IN      DISK_READ       ; Trigger read operation
        RET                     ; A contains result from emulator

; -----------------------------------------------------------------------------
; WRITE - Write sector
; Input: C = write type (0=normal, 1=directory, 2=unallocated)
; Returns: A = 0 if OK, 1 if error
; -----------------------------------------------------------------------------
WRITE_IMPL:
        IN      DISK_WRITE      ; Trigger write operation
        RET                     ; A contains result from emulator

; -----------------------------------------------------------------------------
; SECTRAN - Sector translation
; Input: BC = logical sector, DE = translate table address
; Returns: HL = physical sector
; For now, we use identity mapping (no translation)
; -----------------------------------------------------------------------------
SECTRAN_IMPL:
        MOV     L, C            ; Logical sector to HL
        MOV     H, B
        RET

; =============================================================================
; Data Area
; =============================================================================

; Current disk parameters
CDISK:  DB      0               ; Current disk (0=A:)
CTRACK: DB      0               ; Current track
CSECTOR: DB     0               ; Current sector
CDMA:   DW      0080h           ; Current DMA address

; Disk Parameter Header (simplified)
DPH0:   DW      0               ; XLT - Sector translation table (none)
        DW      0               ; Scratch area
        DW      0               ; Scratch area
        DW      0               ; Scratch area
        DW      DIRBUF          ; DIR - Directory buffer
        DW      DPB0            ; DPB - Disk parameter block
        DW      CSV0            ; CSV - Checksum vector
        DW      ALV0            ; ALV - Allocation vector

; Disk Parameter Block for standard CP/M 2.2 disk
; 77 tracks, 26 sectors/track, 128 bytes/sector
DPB0:   DW      26              ; SPT - Sectors per track
        DB      3               ; BSH - Block shift factor
        DB      7               ; BLM - Block mask
        DB      0               ; EXM - Extent mask
        DW      242             ; DSM - Disk size - 1 (in blocks)
        DW      63              ; DRM - Directory max - 1
        DB      192             ; AL0 - Alloc 0
        DB      0               ; AL1 - Alloc 1
        DW      16              ; CKS - Check size
        DW      2               ; OFF - Track offset

; Buffers and work areas
DIRBUF: DS      128             ; Directory buffer
CSV0:   DS      16              ; Checksum vector
ALV0:   DS      32              ; Allocation vector

SIGNON: DB      'CP/M 2.2 Core8080 BIOS', 0Dh, 0Ah, '$'

        END

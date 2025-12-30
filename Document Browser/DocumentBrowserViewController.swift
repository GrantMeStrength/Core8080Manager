/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A document browser view controller subclass that implements methods for creating, opening, and importing documents.
*/

import UIKit
import os.log

/// - Tag: DocumentBrowserViewController
class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
    
     
    
    
    /// - Tag: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        allowsDocumentCreation = true
        allowsPickingMultipleItems = false

        // Add CP/M Terminal button
        addCPMTerminalButton()
    }

    func addCPMTerminalButton() {
        let terminalButton = UIBarButtonItem(
            title: "CP/M Terminal",
            style: .plain,
            target: self,
            action: #selector(launchCPMTerminal)
        )

        // Add to the trailing (right side) of navigation bar
        additionalTrailingNavigationBarButtonItems = [terminalButton]
    }

    @objc func launchCPMTerminal() {
        // Create the terminal view controller
        let terminalVC = CPMTerminalViewController()
        let navController = UINavigationController(rootViewController: terminalVC)
        navController.modalPresentationStyle = .fullScreen

        // Load and assemble the Interactive Shell
        let assembler = Assemble()
        let interactiveShellCode = getInteractiveShellCode()

        let tokenized = assembler.Tokenize(code: interactiveShellCode)
        let result = assembler.TwoPass(code: tokenized)

        let hexOutput = result.2
        let orgAddress = result.4
        let success = result.3

        guard success else {
            // Show error alert
            let alert = UIAlertController(
                title: "Assembly Error",
                message: "Failed to assemble the Interactive Shell program.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        // Present terminal and start emulator
        present(navController, animated: true) {
            terminalVC.startEmulator(withProgram: hexOutput, org: orgAddress)
        }
    }

    func getInteractiveShellCode() -> String {
        // Return the Interactive Shell assembly code
        return """
; CP/M Interactive Shell (CCP)
; A simple Console Command Processor with:
; - DIR: List directory
; - TYPE filename: Display file contents
; - ERA filename: Delete file
; - EXIT: Halt system

org 0h

; ===== Main Loop =====
start:
    ; Print prompt
    lxi d, prompt
    mvi c, 09h
    call 0005h

    ; Read command line
    lxi d, cmd_buffer
    mvi c, 0Ah          ; BDOS function 10: Read buffer
    call 0005h

    ; Get length and check if empty
    lda cmd_buffer_len
    ora a
    jz start            ; Empty line, show prompt again

    ; Convert to uppercase and parse
    call parse_command
    jmp start           ; Loop forever

; ===== Parse Command =====
parse_command:
    ; Point to first character of command
    lxi h, cmd_buffer_data

    ; Check for DIR
    mov a, m
    cpi 44h             ; 'D'
    jnz check_type
    inx h
    mov a, m
    cpi 49h             ; 'I'
    jnz check_type
    inx h
    mov a, m
    cpi 52h             ; 'R'
    jnz check_type
    jmp cmd_dir

check_type:
    ; Check for TYPE
    lxi h, cmd_buffer_data
    mov a, m
    cpi 54h             ; 'T'
    jnz check_era
    inx h
    mov a, m
    cpi 59h             ; 'Y'
    jnz check_era
    inx h
    mov a, m
    cpi 50h             ; 'P'
    jnz check_era
    inx h
    mov a, m
    cpi 45h             ; 'E'
    jnz check_era
    ; Parse filename for TYPE command
    lxi h, cmd_buffer_data_5  ; Skip "TYPE "
    lxi d, fcb_temp
    call parse_filename
    jmp cmd_type

check_era:
    ; Check for ERA
    lxi h, cmd_buffer_data
    mov a, m
    cpi 45h             ; 'E'
    jnz check_exit
    inx h
    mov a, m
    cpi 52h             ; 'R'
    jnz check_exit
    inx h
    mov a, m
    cpi 41h             ; 'A'
    jnz check_exit
    ; Parse filename for ERA command
    lxi h, cmd_buffer_data_4  ; Skip "ERA "
    lxi d, fcb_temp
    call parse_filename
    jmp cmd_era

check_exit:
    ; Check for EXIT
    lxi h, cmd_buffer_data
    mov a, m
    cpi 45h             ; 'E'
    jnz unknown_cmd
    inx h
    mov a, m
    cpi 58h             ; 'X'
    jnz unknown_cmd
    inx h
    mov a, m
    cpi 49h             ; 'I'
    jnz unknown_cmd
    inx h
    mov a, m
    cpi 54h             ; 'T'
    jnz unknown_cmd
    ; Exit - halt system
    lxi d, msg_goodbye
    mvi c, 09h
    call 0005h
    hlt

unknown_cmd:
    lxi d, msg_unknown
    mvi c, 09h
    call 0005h
    ret

; ===== Parse Filename =====
; HL = source, DE = FCB dest
parse_filename:
    push b
    push h
    push d

    ; Initialize FCB with spaces
    xchg
    mvi m, 00h          ; Drive
    inx h
    mvi b, 11
fill_spaces:
    mvi m, 20h          ; Space character
    inx h
    dcr b
    jnz fill_spaces

    ; Copy filename (up to 8 chars or '.')
    xchg
    pop d
    push d
    inx d               ; Skip drive byte
    mvi b, 8
copy_name:
    mov a, m
    cpi 20h             ; Space
    jz parse_ext
    cpi 2Eh             ; Period '.'
    jz parse_ext
    cpi 00h             ; Null terminator
    jz parse_done
    stax d
    inx h
    inx d
    dcr b
    jnz copy_name

parse_ext:
    ; Skip to extension
skip_dot:
    mov a, m
    cpi 2Eh             ; Period '.'
    jz found_dot
    cpi 20h             ; Space
    jz parse_done
    cpi 00h             ; Null terminator
    jz parse_done
    inx h
    jmp skip_dot

found_dot:
    inx h
    pop d
    push d
    lxi b, 9
    dad b               ; Point to extension in FCB
    xchg
    mvi b, 3
copy_ext:
    mov a, m
    cpi 20h             ; Space
    jz parse_done
    cpi 00h             ; Null terminator
    jz parse_done
    stax d
    inx h
    inx d
    dcr b
    jnz copy_ext

parse_done:
    pop d
    pop h
    pop b
    ret

; ===== DIR Command =====
cmd_dir:
    lxi d, msg_newline
    mvi c, 09h
    call 0005h

    ; Search for first file (*.*)
    lxi d, fcb_all
    mvi c, 11h          ; BDOS function 17: Search first
    call 0005h
    cpi 0FFh
    rz                  ; No files found

dir_loop:
    call print_dir_entry

    ; Search for next
    lxi d, fcb_all
    mvi c, 12h          ; BDOS function 18: Search next
    call 0005h
    cpi 0FFh
    jnz dir_loop

    lxi d, msg_newline
    mvi c, 09h
    call 0005h
    ret

print_dir_entry:
    ; Print spacing
    lxi d, msg_space
    mvi c, 09h
    call 0005h

    ; Print filename (8 chars) from DMA+1
    lxi h, 0081h
    mvi b, 08h
print_name:
    mov a, m
    ani 7Fh             ; Mask attribute bit
    mov e, a
    mvi c, 02h
    call 0005h
    inx h
    dcr b
    jnz print_name

    ; Print dot
    mvi e, 2Eh          ; Period '.'
    mvi c, 02h
    call 0005h

    ; Print extension (3 chars)
    mvi b, 03h
print_ext:
    mov a, m
    ani 7Fh
    mov e, a
    mvi c, 02h
    call 0005h
    inx h
    dcr b
    jnz print_ext

    ret

; ===== TYPE Command =====
cmd_type:
    ; Open file
    lxi d, fcb_temp
    mvi c, 0Fh          ; BDOS function 15: Open file
    call 0005h
    cpi 0FFh
    jz file_not_found

    lxi d, msg_newline
    mvi c, 09h
    call 0005h

type_loop:
    ; Read sequential
    lxi d, fcb_temp
    mvi c, 14h          ; BDOS function 20: Read sequential
    call 0005h
    ora a
    jnz type_done       ; End of file

    ; Display buffer contents
    lxi h, 0080h
    mvi b, 128
display_char:
    mov e, m
    mov a, e
    cpi 1Ah             ; CP/M EOF marker (^Z)
    jz type_done
    mvi c, 02h
    call 0005h
    inx h
    dcr b
    jnz display_char
    jmp type_loop

type_done:
    lxi d, msg_newline
    mvi c, 09h
    call 0005h
    ret

file_not_found:
    lxi d, msg_not_found
    mvi c, 09h
    call 0005h
    ret

; ===== ERA Command =====
cmd_era:
    lxi d, fcb_temp
    mvi c, 13h          ; BDOS function 19: Delete file
    call 0005h
    cpi 0FFh
    jz file_not_found

    lxi d, msg_deleted
    mvi c, 09h
    call 0005h
    ret

; ===== Data =====
prompt:
    db 0Dh, 0Ah, 41h, 3Eh, 24h    ; CR LF "A>" $

msg_newline:
    db 0Dh, 0Ah, 24h               ; CR LF $

msg_space:
    db 20h, 20h, 24h               ; "  " $

msg_unknown:
    db 0Dh, 0Ah, 55h, 6Eh, 6Bh, 6Eh, 6Fh, 77h, 6Eh, 20h
    db 63h, 6Fh, 6Dh, 6Dh, 61h, 6Eh, 64h
    db 0Dh, 0Ah, 24h               ; "Unknown command"

msg_not_found:
    db 0Dh, 0Ah, 46h, 69h, 6Ch, 65h, 20h
    db 6Eh, 6Fh, 74h, 20h, 66h, 6Fh, 75h, 6Eh, 64h
    db 0Dh, 0Ah, 24h               ; "File not found"

msg_deleted:
    db 0Dh, 0Ah, 46h, 69h, 6Ch, 65h, 20h
    db 64h, 65h, 6Ch, 65h, 74h, 65h, 64h
    db 0Dh, 0Ah, 24h               ; "File deleted"

msg_goodbye:
    db 0Dh, 0Ah, 47h, 6Fh, 6Fh, 64h, 62h, 79h, 65h, 21h
    db 0Dh, 0Ah, 24h               ; "Goodbye!"

; Command buffer: max 40 chars
cmd_buffer:
    db 40               ; Byte 0: Max length
cmd_buffer_len:
    db 0                ; Byte 1: Actual length (filled by BDOS)
cmd_buffer_data:
    db 0, 0, 0, 0       ; Bytes 2-5
cmd_buffer_data_4:
    db 0                ; Byte 6 (for "ERA " - skip 4 chars)
cmd_buffer_data_5:
    db 0                ; Byte 7 (for "TYPE " - skip 5 chars)
    ds 34               ; Bytes 8-41 (rest of buffer)

; FCBs
fcb_all:
    db 00h
    db 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh
    db 3Fh, 3Fh, 3Fh
    ds 21

fcb_temp:
    db 00h
    db 20h, 20h, 20h, 20h, 20h, 20h, 20h, 20h
    db 20h, 20h, 20h
    ds 21

end
"""
    }
    
    // MARK: UIDocumentBrowserViewControllerDelegate
    
    // Create a new document.
    func documentBrowser(_ controller: UIDocumentBrowserViewController,
                         didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        
        os_log("==> Creating A New Document.", log: OSLog.default, type: .debug)
        
        let doc = TextDocument()
        let url = doc.fileURL
        
        // Create a new document in a temporary location.
        doc.save(to: url, for: .forCreating) { (saveSuccess) in
            
            // Make sure the document saved successfully.
            guard saveSuccess else {
                os_log("*** Unable to create a new document. ***", log: OSLog.default, type: .error)
                
                // Cancel document creation.
                importHandler(nil, .none)
                return
            }
            
            // Close the document.
            doc.close(completionHandler: { (closeSuccess) in
                
                // Make sure the document closed successfully.
                guard closeSuccess else {
                    os_log("*** Unable to create a new document. ***", log: OSLog.default, type: .error)
                    
                    // Cancel document creation.
                    importHandler(nil, .none)
                    return
                }
                
                // Pass the document's temporary URL to the import handler.
                importHandler(url, .move)
            })
        }
    }
    
    // Import a document.
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        os_log("==> Imported A Document from %@ to %@.",
               log: OSLog.default,
               type: .debug,
               sourceURL.path,
               destinationURL.path)
        
        presentDocument(at: destinationURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
        
        let alert = UIAlertController(
            title: "Unable to Import Document",
            message: "An error occurred while trying to import a document: \(error?.localizedDescription ?? "No Description")",
            preferredStyle: .alert)
        
        let action = UIAlertAction(
            title: "OK",
            style: .cancel,
            handler: nil)
        
        alert.addAction(action)
        
        controller.present(alert, animated: true, completion: nil)
    }
    
    // User selected a document.
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController,
                         didPickDocumentURLs documentURLs: [URL]) {
        
        assert(controller.allowsPickingMultipleItems == false)
        
        assert(!documentURLs.isEmpty,
               "*** We received an empty array of documents ***")
        
        assert(documentURLs.count <= 1,
               "*** We received more than one document ***")
        
        guard let url = documentURLs.first else {
            fatalError("*** No URL Found! ***")
        }
        
        presentDocument(at: url)
    }
    
    // MARK: Document Presentation
    /// - Tag: presentDocuments
    func presentDocument(at documentURL: URL) {
        
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        
        let tempController = storyBoard.instantiateViewController(withIdentifier: "TextDocumentViewController")
        
        guard let documentViewController = tempController as? TextDocumentViewController else {
            fatalError("*** Unable to cast \(tempController) into a TextDocumentViewController ***")
        }
        
        // Load the document view.
        documentViewController.loadViewIfNeeded()
        
        let doc = TextDocument(fileURL: documentURL)
        
        // Get the transition controller.
        let transitionController = self.transitionController(forDocumentURL: documentURL)
        
        // Set up the transition animation.
        transitionController.targetView = documentViewController.textView
        documentViewController.transitionController = transitionController
        
        // Set up the loading animation.
        transitionController.loadingProgress = doc.loadProgress
        
        // Set and open the document.
        documentViewController.document = doc

        doc.open { [weak self](success) in
            
            // Remove the loading animation.
            transitionController.loadingProgress = nil
            
            guard success else {
                fatalError("*** Unable to open the text file ***")
            }
            
            os_log("==> Document Opened!", log: OSLog.default, type: .debug)
            self?.present(documentViewController, animated: true, completion: nil)
        }
    }
}


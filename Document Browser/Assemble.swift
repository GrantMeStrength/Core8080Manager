//
//  Assemble.swift
//  8080Core
//
//  Created by John Kennedy on 4/4/19.
//  Copyright © 2019 craicdesign. All rights reserved.
//

import UIKit

class Assemble : NSObject {
    
    var sourceCode : String = ""
    var objectCode : String = ""
    var prettyCode : String = ""
    var objectHex : String = ""
    
    var pc : UInt16 = 0
    var opCounter : Int = 0
    
    // Store labels
    var Labels : Dictionary = [String:UInt16]()

    private func splitDBValues(_ valueString: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var inString = false

        for char in valueString {
            if char == "'" {
                inString.toggle()
                currentValue.append(char)
                continue
            }

            if char == "," && !inString {
                if !currentValue.isEmpty {
                    values.append(currentValue)
                    currentValue = ""
                }
                continue
            }

            currentValue.append(char)
        }

        if !currentValue.isEmpty {
            values.append(currentValue)
        }

        return values
    }
    
    
    // Turn as much into hex immediately to avoid having to parse anything. Commas = yuck
    func Tokenize (code : String) -> [String]
    {
        // Go through separate lines, deleting lines that are comments i.e. start with ;
        // Unfortunately they won't appear in the assembled code listing, so consider storing them and re-displaying them in the right location.
        let lineseparators = CharacterSet(charactersIn: "\n")
        let linesofcode = code.components(separatedBy: lineseparators)
        var uncommentedCode = ""
        
        for everyLine in linesofcode
        {
            // immediately ignore lines that begin with comments
            if everyLine.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: ";")
            {
               continue
            }
            
            // Get rid of comments after the opcodes, and comments on their own line
            let beforeComment = everyLine.split(separator: ";", maxSplits: 1)
            if beforeComment.count == 2
            {
                uncommentedCode.append(beforeComment[0] + "\n")
            }
            else
            {
                if !everyLine.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: ";")
                {
                    uncommentedCode.append(everyLine + "\n")
                }
            }
        }
        
        let protected = protectQuotedStrings(in: uncommentedCode)

        // Go through entire source code, and swap op-codes for hex codes.
        var tokenizedCode = protected.code.uppercased().removeExtraSpaces()

        // Remove spaces after commas FIRST so source matches opcode table format
        tokenizedCode = tokenizedCode.replacingOccurrences(of: ", ", with: ",")

        // Directives that should not be replaced with opcodes
        let directives = ["ORG", "END", "DB", "DS", "DW", "EQU"]

        // Sort opcodes by length (descending) to match longer opcodes first
        let sortedOpcodes = i8080.sorted { $0.opcode.count > $1.opcode.count }

        // Replace opcodes using word boundaries to avoid mangling labels
        for everyOpCode in sortedOpcodes {
            // Skip if this is a directive keyword
            if directives.contains(everyOpCode.opcode) {
                continue
            }

            if let index = i8080.firstIndex(where: {($0.opcode == everyOpCode.opcode)}) {
                let detailsHex = String(format: "%02X ", index)

                // Use regex to match only at word boundaries
                // Opcodes ending with comma can be followed by anything
                // Other opcodes must be followed by whitespace or end
                let escapedOpcode = NSRegularExpression.escapedPattern(for: everyOpCode.opcode)
                let pattern: String
                if everyOpCode.opcode.hasSuffix(",") {
                    pattern = "(^|\\s)" + escapedOpcode
                } else {
                    pattern = "(^|\\s)" + escapedOpcode + "(?=\\s|$)"
                }

                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(tokenizedCode.startIndex..., in: tokenizedCode)
                    tokenizedCode = regex.stringByReplacingMatches(
                        in: tokenizedCode,
                        options: [],
                        range: range,
                        withTemplate: "$1" + detailsHex
                    )
                }
            }
        }
        
        let simplerCode1 = tokenizedCode.replacingOccurrences(of: "\t", with: "")
        let simplerCode2 = simplerCode1.replacingOccurrences(of: ":", with: ":*")
        let restoredCode = restoreQuotedStrings(in: simplerCode2, strings: protected.strings)

        // Parse tokens while preserving quoted strings
        var tokens: [String] = []
        var currentToken = ""
        var inString = false

        for char in restoredCode {
            if char == "'" {
                inString.toggle()
                currentToken.append(char)
            } else if (char == " " || char == "*" || char == "\n") && !inString {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            } else {
                currentToken.append(char)
            }
        }

        // Add final token if any
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    private func protectQuotedStrings(in code: String) -> (code: String, strings: [String]) {
        var result = ""
        var strings: [String] = []
        var current = ""
        var inString = false

        for char in code {
            if char == "'" {
                if inString {
                    current.append(char)
                    strings.append(current)
                    result.append("__STR\(strings.count - 1)__")
                    current = ""
                    inString = false
                } else {
                    inString = true
                    current = "'"
                }
            } else if inString {
                current.append(char)
            } else {
                result.append(char)
            }
        }

        if inString {
            result.append(current)
        }

        return (result, strings)
    }

    private func restoreQuotedStrings(in code: String, strings: [String]) -> String {
        var restored = code
        for (index, string) in strings.enumerated() {
            restored = restored.replacingOccurrences(of: "__STR\(index)__", with: string)
        }
        return restored
    }
    
    
    func TwoPass (code : [String]) -> (String, String, String, Bool, UInt16)
    {
        Labels.removeAll()
        prettyCode.removeAll()

        var buildOK = true
        var orgAddress: UInt16 = 0  // Track the ORG address
        var orgFound = false

        // Check for empty file.. not a lot we can do with nothing.
        if code.isEmpty
        {
            return("\n\nNo code to assemble.","","", false, 0)
        }

        for pass in 1...2
        {
            pc = 0
            opCounter = 0
            objectCode = ""
            objectHex = ""
            
            repeat {
                
                if pass == 2
                {
                    prettyCode.append(String(format :"%04X:", pc) + " ")
                }
                
                let opcode = code[(opCounter)]
                
                
                // Check for label definition
                if opcode.contains(":")
                {
                    // Does label already exist?
                    if pass == 1 && Labels[opcode] != nil
                    {
                        prettyCode.append("\t\t\t Error: " + opcode.lowercased() + " is already defined.\n")
                        buildOK = false
                        continue
                    }
                    
                    Labels[opcode] = pc
                    opCounter = opCounter + 1
                    if pass == 2
                    {
                        prettyCode.append("\t\t\t" + opcode.lowercased() + "\n")
                    }
                    continue // Found a label so file it away.
                }
                
                // Process opcodes by length. Trap unknown ones! They'll appear as
                // non-HEX in the opcode string, as we tokenized everything and
                // already checked for labels. HOWEVER, they could be Directives
                
                // Bug: if the opcode is invalid but hex e.g. DEC then things fail.
                // Temp fix: If opcode number is out of range? Nope.
                // Need to fix at tokenizing stage.
                // OK, because I used labels as always having a : this failed.
                // What's the difference between a label reference and a bad opcode?
                
                // IMPORTANT: Check if it's a directive keyword first!
                // "DB" is valid hex (0xDB) but must be treated as directive
                let isDirective = (opcode == "END" || opcode == "ORG" || opcode == "DB" || opcode == "DS")

                var opcodeIndex = 0
                let opcodeData = isDirective ? (UInt16(0), false) : getNumberFromHexString(number: opcode)

                if opcodeData.1 // Number is good, therefore opcode is good
                {
                    opcodeIndex = Int(opcodeData.0)
                }
                else
                {
                    // Check for Directives (currently: END, ORG, DB, DS)
                    if opcode == "END"
                    {
                        if (pass == 2)
                        {
                            prettyCode.append("\t\t\t\t\tend")
                        }
                        // Skip to end of pass. Advance to go. Do not get $200.
                        opCounter = 0xffff
                        continue
                    }
                    
                    
                    if (pass == 1)
                    {
                        
                        if opcode == "ORG"
                        {
                            // In the first pass, the ORG command must be executed too.
                            opCounter = opCounter + 1
                            let dataTest = getNumberFromString(number:(code[(opCounter)]))
                            var data = 0
                            if dataTest.1
                            {
                                data = Int(dataTest.0)
                            }
                            else
                            {
                                data = 0
                            }

                            pc = UInt16(data)

                            // Capture the first ORG address
                            if !orgFound {
                                orgAddress = UInt16(data)
                                orgFound = true
                            }

                            opCounter = opCounter + 1
                            continue
                        }
                        
                        if opcode == "DB"
                        {
                            // Count comma-separated values (including strings)
                            opCounter = opCounter + 1
                            if opCounter < code.count {
                                let values = splitDBValues(code[opCounter])

                                var byteCount = 0

                                for value in values {
                                    let trimmed = value.trimmingCharacters(in: .whitespaces)
                                    // Check if it's a string literal
                                    if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") {
                                        // String: count characters between quotes
                                        let startIndex = trimmed.index(after: trimmed.startIndex)
                                        let endIndex = trimmed.index(before: trimmed.endIndex)
                                        if startIndex < endIndex {
                                            let stringContent = trimmed[startIndex..<endIndex]
                                            byteCount += stringContent.count
                                        }
                                    } else {
                                        // Single value
                                        byteCount += 1
                                    }
                                }
                                pc = pc + UInt16(byteCount)
                                opCounter = opCounter + 1
                            }
                            continue
                        }

                        if opcode == "DS"
                        {
                            // DS reserves space - increment PC by the specified amount
                            opCounter = opCounter + 1
                            let dataTest = getNumberFromString(number:(code[(opCounter)]))
                            if dataTest.1
                            {
                                pc = pc + UInt16(dataTest.0)
                            }
                            opCounter = opCounter + 1
                            continue
                        }


                    }
                    
                    if (pass == 2)
                    {
                        if opcode == "ORG"
                        {
                            opCounter = opCounter + 1
                            
                            let dataTest = getNumberFromString(number:(code[(opCounter)]))
                            var data = 0
                            if dataTest.1
                            {
                                data = Int(dataTest.0)
                            }
                            else
                            {
                                data = 0
                                prettyCode.append("\t\t\t\torg ???? Error. No value for org.\n")
                                buildOK = false
                                opCounter = opCounter + 1
                                continue
                            }
                            
                            
                            pc = UInt16(data)
                            prettyCode.append("\t\t\t\t\torg " + String(format :"%04Xh", data) + "\n")
                            opCounter = opCounter + 1
                            continue
                        }
                        
                        if opcode == "DB"
                        {
                            opCounter = opCounter + 1
                            var dataBytes: [Int] = []
                            var hasError = false
                            var displayParts: [String] = []

                            if opCounter < code.count {
                                let values = splitDBValues(code[opCounter])

                                for value in values {
                                    let trimmed = value.trimmingCharacters(in: .whitespaces)

                                    // Check if it's a string literal
                                    if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") {
                                        let startIndex = trimmed.index(after: trimmed.startIndex)
                                        let endIndex = trimmed.index(before: trimmed.endIndex)
                                        if startIndex < endIndex {
                                            let stringContent = String(trimmed[startIndex..<endIndex])
                                            // Convert each character to its ASCII value
                                            for char in stringContent {
                                                if let asciiValue = char.asciiValue {
                                                    dataBytes.append(Int(asciiValue))
                                                }
                                            }
                                            displayParts.append("'\(stringContent)'")
                                        }
                                    } else {
                                        // Regular numeric value
                                        let dataTest = getNumberFromString(number: trimmed)
                                        if dataTest.1 {
                                            dataBytes.append(Int(dataTest.0))
                                            displayParts.append(String(format: "%02Xh", Int(dataTest.0)))
                                        } else {
                                            hasError = true
                                            break
                                        }
                                    }
                                }
                                opCounter = opCounter + 1
                            }

                            if hasError || dataBytes.isEmpty {
                                prettyCode.append("\t\t\t\tdb ???? Error. Invalid data.\n")
                                buildOK = false
                                continue
                            }

                            // Output all bytes with mixed display
                            prettyCode.append("\t\t\t\tdb " + displayParts.joined(separator: ", ") + "\n")

                            for byte in dataBytes {
                                OutputByte(thebyte: byte)
                                pc = pc + 1
                            }
                            continue
                        }

                        if opcode == "DS"
                        {
                            // DS reserves space - output zeros
                            opCounter = opCounter + 1
                            let dataTest = getNumberFromString(number:(code[(opCounter)]))
                            var count = 0
                            if dataTest.1
                            {
                                count = Int(dataTest.0)
                            }
                            else
                            {
                                prettyCode.append("\t\t\t\tds ???? Error. No count.\n")
                                buildOK = false
                                opCounter = opCounter + 1
                                continue
                            }

                            prettyCode.append("\t\t\t\tds " + String(count) + "\n")
                            for _ in 0..<count
                            {
                                OutputByte(thebyte: 0)
                            }
                            pc = pc + UInt16(count)
                            opCounter = opCounter + 1
                            continue
                        }

                        // Check for any invalid opcodes or labels that
                        // are not defined.
                        
                        if Labels[opcode] == nil
                        {
                            prettyCode.append("Error. Unknown opcode: " + opcode + "\n")
                            buildOK = false
                            continue
                        }
                        
                        
                        
                    }
                    
                    
                    opCounter = opCounter + 1
                    continue
                }
                
                var length = 0
                if let oc = i8080[safe : opcodeIndex]
                {
                    length = oc.length
                }
                else
                {
                    prettyCode.append("Error. Unknown instruction: " + opcode + "\n")
                    buildOK = false
                    continue
                }
                
                
                // Single byte instruction
                if length == 1
                {
                    if pass == 2
                    {
                        OutputByte(thebyte: opcodeIndex)
                        pc = pc + 1
                        prettyCode.append(String(format :"%02X", opcodeIndex) + "    \t\t\t" + i8080[opcodeIndex].opcode.lowercased() + "\n")
                        opCounter = opCounter + 1
                    }
                    else
                    {
                        pc = pc + 1
                        opCounter = opCounter + 1
                    }
                    
                }
                
                // Double byte instruction
                if length == 2
                {
                    
                    if pass == 2
                    {
                        
                        OutputByte(thebyte: opcodeIndex)
                        pc = pc + 1
                        opCounter = opCounter + 1
                        
                        let dataTest = getNumberFromString(number:(code[(opCounter)]))
                        var data = 0
                        if dataTest.1 && Int(dataTest.0)<256
                        {
                            data = Int(dataTest.0)
                        }
                        else
                        {
                            data = 0
                            prettyCode.append("\t\t\t" )
                            if (Int(dataTest.0)>=256)
                            {
                                prettyCode.append(" Error: Out of range ")
                            }
                            else
                            {
                                prettyCode.append(" Error: Unknown opcode ")
                            }
                            
                            prettyCode.append(i8080[opcodeIndex].opcode.lowercased())
                            buildOK = false
                            opCounter = opCounter + 1
                            continue
                        }
                        
                        
                        OutputByte(thebyte: Int(data))
                        pc = pc + 1
                        
                        prettyCode.append(String(format :"%02X",opcodeIndex) + String(format :"%02X", data) + "  \t\t\t" + i8080[opcodeIndex].opcode.lowercased() + " " + String(format :"%02Xh", data) + "\n");
                        opCounter = opCounter + 1
                    }
                    else
                    {
                        pc = pc + 2
                        opCounter = opCounter + 2
                    }
                    
                }
                
                // Triple byte instruction
                if length == 3
                {
                    
                    if pass == 2
                    {
                        var dataFromLabel = false
                        
                        OutputByte(thebyte: opcodeIndex)
                        pc = pc + 1
                        opCounter = opCounter + 1
                        
                        // Check for presence of label
                        
                        var potentialLabel = code[opCounter]
                        
                        
                        if potentialLabel.last != ":"
                        {
                            potentialLabel = potentialLabel + ":"
                        }
                        
                        
                        var data : UInt16 = 0
                        
                        if let labelValue = Labels[potentialLabel]
                        {
                            // Found a label
                            data = labelValue
                            dataFromLabel = true
                        }
                        else
                        {
                            
                            let dataTest = getNumberFromString(number:(code[(opCounter)]))
                            
                            if dataTest.1 && Int(dataTest.0)<65536
                            {
                                data = UInt16(dataTest.0)
                            }
                            else
                            {
                                buildOK = false
                                
                                if (Int(dataTest.0)<65536)
                                {
                                prettyCode.append(String(format :"%02X", opcodeIndex) +  "?? ?? \t\t\t" + i8080[opcodeIndex].opcode.lowercased() + "????\n Error: Label not found.")
                                }
                                else
                                {
                                     prettyCode.append(String(format :"%02X", opcodeIndex) +  "?? ?? \t\t\t" + i8080[opcodeIndex].opcode.lowercased() + "????\n Error: Out of range")
                                }
                                opCounter = opCounter + 1
                                continue
                            }
                            
                            
                        }
                        
                        
                        // Break down value of label and display it.
                        let L = (data & 0b11111111)
                        let H = (data & 0b1111111100000000) >> 8
                        
                        OutputByte(thebyte: Int(L))
                        pc = pc + 1
                        OutputByte(thebyte: Int(H))
                        pc = pc + 1
                        
                        opCounter = opCounter + 1
                        
                        if L == 255 && H == 255 && dataFromLabel // Label not found - special case - Potential BUG! Although unlikely, labels should be allowed to be ffffh!
                        {
                            buildOK = false
                            prettyCode.append(String(format :"%02X", opcodeIndex) +  "?? ?? \t\t\t" + i8080[opcodeIndex].opcode.lowercased() + "????\n")
                        }
                        else
                        {
                            if dataFromLabel
                            {
                                prettyCode.append(String(format :"%02X", opcodeIndex) + String(format :"%02X", L) + String(format :"%02X", H) + "\t\t\t" + i8080[opcodeIndex].opcode.lowercased() + " " + potentialLabel.lowercased() + "\n")
                            }
                            else
                            {
                                prettyCode.append(String(format :"%02X", opcodeIndex) + String(format :"%02X", L) + String(format :"%02X", H) + "\t\t\t" + i8080[opcodeIndex].opcode.lowercased() + " " + String(format :"%04Xh", data) + "\n")
                            }
                        }
                    }
                    else
                    {
                        pc = pc + 3
                        opCounter = opCounter + 2
                    }
                    
                }
                
            } while (opCounter < code.count && buildOK)
            
        }
        
        
        
        if buildOK
        {
            prettyCode.append("\n\n; No errors found.");
            //   objectCode = objectCode + "\n\n\n\n\nOctal version of assembled code, ideal for devices which require entering codes manually via switches. If an ORG statement was used, remember to check addresses in case they changed from sequential ordering."
        }
        else
        {
            prettyCode.append("\n\nWarning, contains error(s)");
            objectCode.append("\n\nWarning: contains error(s)")
        }
        
        return (objectCode, prettyCode, objectHex, buildOK, orgAddress)
    }
    
    
    
    func OutputByte(thebyte : Int)
    {
        // Todo: Check for break in sequence, in case ORG statement occurs in code.
        
        if pc % 8 == 0
        {
            objectCode.append(String(format :"\n%03o: ", pc))
            
        }
        
        let CO = String(format :"%03o ", thebyte)
        let CH = String(format :"%02X", thebyte)
        objectCode.append(CO)
        objectHex.append(CH)
    }
    
    
    func getNumberFromHexString(number : String) -> (UInt16, Bool)
    {
        if let converted = UInt16(number, radix:16)
        {
            return (converted, true)
        }
        else
        {
            // Not a number. Maybe a label!
            return (0, false)
        }
        
    }
    
    func getNumberFromString(number : String) -> (UInt16, Bool)
    {

        // Label
        if number.contains(":")
        {
            return (0xffff, false)
        }

        // Character literal: 'X' -> ASCII value
        if number.hasPrefix("'") && number.hasSuffix("'") && number.count == 3 {
            let char = number[number.index(after: number.startIndex)]
            if let asciiValue = char.asciiValue {
                return (UInt16(asciiValue), true)
            } else {
                return (0, false)
            }
        }

        // Hex
        if number.contains("H") || number.contains("h")
        {
            var hex =  number.replacingOccurrences(of: "H", with: "")
            hex =  hex.replacingOccurrences(of: "h", with: "")
            if let converted = UInt16(hex, radix:16)
            {
                return (converted, true)
            }
            else
            {
                return (0, false)
            }
        }
        
        // Octal
        if number.contains("O")
        {
            let octal =  number.replacingOccurrences(of: "O", with: "")
            
            if let converted = UInt16(octal, radix:8)
            {
                return (converted, true)
            }
            else
            {
                return (0, false)
            }
            
        }
        
        // BINARY
        if number.contains("B")
        {
            let binary =  number.replacingOccurrences(of: "B", with: "")
            if let converted = UInt16(binary, radix:2)
            {
                return (converted, true)
            }
            else
            {
                return (0, false)
            }
            
        }
        
        // Decimal
        
        
        if let converted = UInt16(number, radix:10)
        {
            return (converted, true)
        }
        else
        {
            return (0, false)
        }
        
        
        
        //   return (UInt16(number)!, true)
        
    }
    
    func getOpcode(instructionByte : Int,  lowByte : Int, highByte : Int) -> String
    {
        let opcode = i8080[instructionByte].opcode
        let length = i8080[instructionByte].length
        
        if length == 1
        {
            return opcode
        }
        
        if length == 2
        {
            return opcode + " " + String(format :"%02Xh", lowByte)
        }
        
        if length == 3
        {
            return opcode + " " + String(format :"%02X", lowByte) + String(format :"%02Xh", highByte)
        }
        
        return "?"
    }
    
    
    let i8080 : [(opcode : String, length : Int)] =
        [
            ("NOP", 1),
            ("LXI B,", 3),
            ("STAX B", 1),
            ("INX B", 1),
            ("INR B", 1),
            ("DCR B", 1),
            ("MVI B,", 2),
            ("RLC", 1),
            ("-", 0),
            ("DAD B", 1),
            ("LDAX B", 1),
            ("DCX B", 1),
            ("INR C", 1),
            ("DCR C", 1),
            ("MVI C,", 2),
            ("RRC", 1),
            ("-", 0),
            ("LXI D,", 3),
            ("STAX D", 1),
            ("INX D", 1),
            ("INR D", 1),
            ("DCR D", 1),
            ("MVI D,", 2),
            ("RAL", 1),
            ("-", 0),
            ("DAD D", 1),
            ("LDAX D", 1),
            ("DCX D", 1),
            ("INR E", 1),
            ("DCR E", 1),
            ("MVI E,", 2),
            ("RAR", 1),
            ("-", 0),
            ("LXI H,", 3),
            ("SHLD", 3), //
            ("INX H", 1),
            ("INR H", 1),
            ("DCR H", 1),
            ("MVI H,", 2),
            ("DAA", 1),
            ("-", 0),
            ("DAD H", 1),
            ("LHLD", 3), //
            ("DCX H", 1),
            ("INR L", 1),
            ("DCR L", 1),
            ("MVI L,", 2),
            ("CMA", 1),
            ("-", 0),
            ("LXI SP,", 3),
            ("STA", 3), //
            ("INX SP", 1),
            ("INR M", 1),
            ("DCR M", 1),
            ("MVI M,", 2),
            ("STC", 1),
            ("-", 0),
            ("DAD SP", 1),
            ("LDA", 3), //
            ("DCX SP", 1),
            ("INR A", 1),
            ("DCR A", 1),
            ("MVI A,", 2),
            ("CMC", 1),
            ("MOV B,B", 1),
            ("MOV B,C", 1),
            ("MOV B,D", 1),
            ("MOV B,E", 1),
            ("MOV B,H", 1),
            ("MOV B,L", 1),
            ("MOV B,M", 1),
            ("MOV B,A", 1),
            ("MOV C,B", 1),
            ("MOV C,C", 1),
            ("MOV C,D", 1),
            ("MOV C,E", 1),
            ("MOV C,H", 1),
            ("MOV C,L", 1),
            ("MOV C,M", 1),
            ("MOV C,A", 1),
            ("MOV D,B", 1),
            ("MOV D,C", 1),
            ("MOV D,D", 1),
            ("MOV D,E", 1),
            ("MOV D,H", 1),
            ("MOV D,L", 1),
            ("MOV D,M", 1),
            ("MOV D,A", 1),
            ("MOV E,B", 1),
            ("MOV E,C", 1),
            ("MOV E,D", 1),
            ("MOV E,E", 1),
            ("MOV E,H", 1),
            ("MOV E,L", 1),
            ("MOV E,M", 1),
            ("MOV E,A", 1),
            ("MOV H,B", 1),
            ("MOV H,C", 1),
            ("MOV H,D", 1),
            ("MOV H,E", 1),
            ("MOV H,H", 1),
            ("MOV H,L", 1),
            ("MOV H,M", 1),
            ("MOV H,A", 1),
            ("MOV L,B", 1),
            ("MOV L,C", 1),
            ("MOV L,D", 1),
            ("MOV L,E", 1),
            ("MOV L,H", 1),
            ("MOV L,L", 1),
            ("MOV L,M", 1),
            ("MOV L,A", 1),
            ("MOV M,B", 1),
            ("MOV M,C", 1),
            ("MOV M,D", 1),
            ("MOV M,E", 1),
            ("MOV M,H", 1),
            ("MOV M,L", 1),
            ("HLT", 1),
            ("MOV M,A", 1),
            ("MOV A,B", 1),
            ("MOV A,C", 1),
            ("MOV A,D", 1),
            ("MOV A,E", 1),
            ("MOV A,H", 1),
            ("MOV A,L", 1),
            ("MOV A,M", 1),
            ("MOV A,A", 1),
            ("ADD B", 1),
            ("ADD C", 1),
            ("ADD D", 1),
            ("ADD E", 1),
            ("ADD H", 1),
            ("ADD L", 1),
            ("ADD M", 1),
            ("ADD A", 1),
            ("ADC B", 1),
            ("ADC C", 1),
            ("ADC D", 1),
            ("ADC E", 1),
            ("ADC H", 1),
            ("ADC L", 1),
            ("ADC M", 1),
            ("ADC A", 1),
            ("SUB B", 1),
            ("SUB C", 1),
            ("SUB D", 1),
            ("SUB E", 1),
            ("SUB H", 1),
            ("SUB L", 1),
            ("SUB M", 1),
            ("SUB A", 1),
            ("SBB B", 1),
            ("SBB C", 1),
            ("SBB D", 1),
            ("SBB E", 1),
            ("SBB H", 1),
            ("SBB L", 1),
            ("SBB M", 1),
            ("SBB A", 1),
            ("ANA B", 1),
            ("ANA C", 1),
            ("ANA D", 1),
            ("ANA E", 1),
            ("ANA H", 1),
            ("ANA L", 1),
            ("ANA M", 1),
            ("ANA A", 1),
            ("XRA B", 1),
            ("XRA C", 1),
            ("XRA D", 1),
            ("XRA E", 1),
            ("XRA H", 1),
            ("XRA L", 1),
            ("XRA M", 1),
            ("XRA A", 1),
            ("ORA B", 1),
            ("ORA C", 1),
            ("ORA D", 1),
            ("ORA E", 1),
            ("ORA H", 1),
            ("ORA L", 1),
            ("ORA M", 1),
            ("ORA A", 1),
            ("CMP B", 1),
            ("CMP C", 1),
            ("CMP D", 1),
            ("CMP E", 1),
            ("CMP H", 1),
            ("CMP L", 1),
            ("CMP M", 1),
            ("CMP A", 1),
            ("RNZ", 1),
            ("POP B", 1),
            ("JNZ", 3), //
            ("JMP", 3), //
            ("CNZ", 3), //
            ("PUSH B", 1),
            ("ADI", 2), //
            ("RST 0", 1),
            ("RZ", 1),
            ("RET", 1),
            ("JZ", 3), //
            ("-", 0),
            ("CZ", 3), //
            ("CALL", 3), //
            ("ACI", 2), //
            ("RST 1", 1),
            ("RNC", 1),
            ("POP D", 1),
            ("JNC", 3), //
            ("OUT", 2), //
            ("CNC", 3), //
            ("PUSH D", 1),
            ("SUI", 2), //
            ("RST 2", 1),
            ("RC", 1),
            ("-", 0),
            ("JC", 3), //
            ("IN", 2), //
            ("CC", 3), //
            ("-", 0),
            ("SBI", 2), //
            ("RST 3", 1),
            ("RPO", 1),
            ("POP H", 1),
            ("JPO", 3), //
            ("XTHL", 1),
            ("CPO", 3), //
            ("PUSH H", 1),
            ("ANI", 2), //
            ("RST 4", 1),
            ("RPE", 1),
            ("PCHL", 1),
            ("JPE", 3), //
            ("XCHG", 1),
            ("CPE", 3), //
            ("-", 0),
            ("XRI", 2), //
            ("RST 5", 1),
            ("RP", 1),
            ("POP PSW", 1),
            ("JP", 3), //
            ("DI", 1),
            ("CP", 3), //
            ("PUSH PSW", 1),
            ("ORI", 2), //
            ("RST 6", 1),
            ("RM", 1),
            ("SPHL", 1),
            ("JM", 3), //
            ("EI", 1),
            ("CM", 3), //
            ("-", 0),
            ("CPI", 2), //
            ("RST 7", 1)
    ]
    


// http://www.myquest.nl/z80undocumented/z80-documented-v0.91.pdf
// http://www.z80.info/z80-op.txt
/*
let z80 : [(opcode : String, length : Int)] =
    [
        ("NOP", 1),
        ("LD BC,nn", 3),
        ("LD (BC),A ", 1),
        ("INC BC", 1),
        ("INC B", 1),
        ("DEC B", 1),
        ("LD B,n", 2),
        ("RLCA", 1),
        ("EX AF,AF’ ", 0),
        ("ADD HL,BC ", 1),
        ("LD A,(BC) ", 1),
        ("DEC BC", 1),
        ("INC C", 1),
        ("DEC C", 1),
        ("LD C,n", 2),
        ("RRCA", 1),
        ("DJNZ (PC+e) ", 0),
        ("LD DE,nn", 3),
        ("LD (DE),A ", 1),
        ("INC DE", 1),
        ("INC D", 1),
        ("DEC D", 1),
        ("LD D,n", 2),
        ("RLA", 1),
        ("JR e", 0),
        ("ADD HL,DE ", 1),
        ("LD A,(DE) ", 1),
        ("DEC DE", 1),
        ("INC E", 1),
        ("DEC E", 1),
        ("LD E,n", 2),
        ("RRA", 1),
        ("JR NZ,e", 0),
        ("LD HL,nn", 3),
        ("LD (nn),HL ", 3),
        ("INC HL", 1),
        ("INC H", 1),
        ("DEC H", 1),
        ("LD H,n", 2),
        ("DAA", 1),
        ("JR Z,e", 0),
        ("ADD HL,HL ", 1),
        ("LD HL,(nn) ", 3),
        ("DEC HL", 1),
        ("INC L", 1),
        ("DEC L", 1),
        ("LD L,n", 2),
        ("CPL", 1),
        ("JR NC,e", 0),
        ("LD SP,nn", 3),
        ("LD (nn),A ", 3),
        ("INC SP", 1),
        ("INC (HL) ", 1),
        ("DEC (HL)", 1),
        ("LD (HL),", 2),
        ("SCF", 1),
        ("JR C,e ", 0),
        ("ADD HL,SP ", 1),
        ("LD A,(nn) ", 3),
        ("DEC SP ", 1),
        ("INC A", 1),
        ("DEC A", 1),
        ("LD A,n ", 2),
        ("CCF", 1),
        ("LD B,B", 1),
        ("LD B,C", 1),
        ("LD B,D", 1),
        ("LD B,E", 1),
        ("LD B,H", 1),
        ("LD B,L", 1),
        ("LD B,(HL) ", 1),
        ("LD B,A", 1),
        ("LD C,B", 1),
        ("LD C,C", 1),
        ("LD C,D", 1),
        ("LD C,E", 1),
        ("LD C,H", 1),
        ("LD C,L", 1),
        ("LD C,(HL) ", 1),
        ("LD C,A", 1),
        ("LD D,B", 1),
        ("LD D,C", 1),
        ("LD D,D", 1),
        ("LD D,E", 1),
        ("LD D,H", 1),
        ("LD D,L", 1),
        ("LD D,(HL) ", 1),
        ("LD D,A", 1),
        ("LD E,B", 1),
        ("LD E,C", 1),
        ("LD E,D", 1),
        ("LD E,E", 1),
        ("LD E,H", 1),
        ("LD E,L", 1),
        ("LD E,(HL) ", 1),
        ("LD E,A", 1),
        ("LD H,B", 1),
        ("LD H,C", 1),
        ("LD H,D", 1),
        ("LD H,E", 1),
        ("LD H,H", 1),
        ("LD H,L", 1),
        ("LD H,(HL) ", 1),
        ("LD H,A", 1),
        ("LD L,B", 1),
        ("LD L,C", 1),
        ("LD L,D", 1),
        ("LD L,E", 1),
        ("LD L,H", 1),
        ("LD L,L", 1),
        ("LD L,(HL) ", 1),
        ("LD L,A", 1),
        ("LD (HL),B ", 1),
        ("LD (HL),C ", 1),
        ("LD (HL),D ", 1),
        ("LD (HL),E ", 1),
        ("LD (HL),H ", 1),
        ("LD (HL),L ", 1),
        ("HALT", 1),
        ("LD (HL),A ", 1),
        ("LD A,B", 1),
        ("LD A,C", 1),
        ("LD A,D", 1),
        ("LD A,E", 1),
        ("LD A,H", 1),
        ("LD A,L", 1),
        ("LD A,(HL) ", 1),
        ("LD A,A", 1),
        ("ADD A,B", 1),
        ("ADD A,C", 1),
        ("ADD A,D", 1),
        ("ADD A,E", 1),
        ("ADD A,H", 1),
        ("ADD A,L", 1),
        ("ADD A,(HL) ", 1),
        ("ADD A,A", 1),
        ("ADC A,B", 1),
        ("ADC A,C", 1),
        ("ADC A,D", 1),
        ("ADC A,E", 1),
        ("ADC A,H", 1),
        ("ADC A,L", 1),
        ("ADC A,(HL) ", 1),
        ("ADC A,A", 1),
        ("SUB B", 1),
        ("SUB C", 1),
        ("SUB D", 1),
        ("SUB E", 1),
        ("SUB H", 1),
        ("SUB L", 1),
        ("SUB (HL) ", 1),
        ("SUB A", 1),
        ("SBC A,B", 1),
        ("SBC A,C", 1),
        ("SBC A,D", 1),
        ("SBC A,E", 1),
        ("SBC A,H", 1),
        ("SBC A,L", 1),
        ("SBC A,(HL) ", 1),
        ("SBC A,A", 1),
        ("AND B ", 1),
        ("AND C ", 1),
        ("AND D ", 1),
        ("AND E", 1),
        ("AND H", 1),
        ("AND L", 1),
        ("AND (HL) ", 1),
        ("AND A", 1),
        ("XOR B", 1),
        ("XOR C", 1),
        ("XOR D", 1),
        ("XOR E", 1),
        ("XOR H", 1),
        ("XOR L", 1),
        ("XOR (HL) ", 1),
        ("XOR A", 1),
        ("ORB", 1),
        ("ORC", 1),
        ("ORD", 1),
        ("ORE", 1),
        ("ORH", 1),
        ("ORL", 1),
        ("OR (HL) ", 1),
        ("ORA", 1),
        ("CPB", 1),
        ("CPC", 1),
        ("CPD", 1),
        ("CPE", 1),
        ("CPH", 1),
        ("CPL", 1),
        ("CP (HL) ", 1),
        ("CPA", 1),
        ("RET NZ", 1),
        ("POP BC", 1),
        ("JP NZ,nn ", 3),
        ("JP nn", 3),
        ("CALL NZ,nn ", 3),
        ("PUSH BC ", 1),
        ("ADD A,n ", 2),
        ("RST 0H", 1),
        ("RET Z", 1),
        ("RET", 1),
        ("JP Z,nn", 3),
        ("-", 0),
        ("CALL Z,nn", 3),
        ("CALL nn", 3),
        ("ADC A,n", 2),
        ("RST 8H", 1),
        ("RET NC", 1),
        ("POP DE", 1),
        ("JP NC,nn", 3),
        ("OUT (n),A", 2),
        ("CALL NC,n", 3),
        ("PUSH DE", 1),
        ("SUB n", 2),
        ("RST 10H", 1),
        ("RET C", 1),
        ("EXX", 0),
        ("JP C,nn", 3),
        ("IN A,(n)", 2),
        ("CALL C,nn", 3),
        ("LD SP,IX ", 0),
        ("SBC A,n ", 2),
        ("RST 18H ", 1),
        ("RET PO", 1),
        ("POP HL", 1),
        ("JP PO,nn", 3),
        ("EX (SP),HL", 1),
        ("CALL PO,nn", 3),
        ("PUSH HL", 1),
        ("AND n", 2),
        ("RST 20H", 1),
        ("RET PE", 1),
        ("JP (HL)", 1),
        ("JP PE,nn", 3),
        ("EX DE,HL", 1),
        ("CALL PE,nn", 3),
        ("-", 0),
        ("XOR n", 2),
        ("RST 28H", 1),
        ("RET P", 1),
        ("POP AF", 1),
        ("JP P,nn", 3),
        ("DI", 1),
        ("CALL P,nn", 3),
        ("PUSH AF", 1),
        ("ORn", 2),
        ("RST 30H", 1),
        ("RET M", 1),
        ("LD SP,HL", 1),
        ("JP M,nn", 3),
        ("EI", 1),
        ("CALL M,nn ", 3),
        ("-", 0),
        ("CP n", 2),
        ("RST 38H", 1)
    ]
*/
}

extension String {
    // Get rid of spaces and tabs to aid with tokenizing.
    func removeExtraSpaces() -> String {
        // Collapse whitespace outside of quoted strings to preserve literal spacing.
        var result = ""
        var inString = false
        var pendingSpace = false

        for char in self {
            if char == "'" {
                if pendingSpace {
                    result.append(" ")
                    pendingSpace = false
                }
                inString.toggle()
                result.append(char)
                continue
            }

            if !inString && (char == " " || char == "\t") {
                pendingSpace = true
                continue
            }

            if pendingSpace {
                result.append(" ")
                pendingSpace = false
            }
            result.append(char)
        }

        if pendingSpace {
            result.append(" ")
        }
        return result
    }
    
}

extension Collection {
    
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

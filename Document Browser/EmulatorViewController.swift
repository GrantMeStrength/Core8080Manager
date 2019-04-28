//
//  EmulatorViewController.swift
//  Core8080
//
//  Created by John Kennedy on 4/28/19.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit

class EmulatorViewController: UIViewController {

    
    var timer: Timer?
    var running = false
    var currentOpcode = ""
    var nextOpcode = ""
    
    let CPU = Assemble()
    var sourceCode : String = ""
    var assemblerOutput : String = ""
    var octalOutput : String = ""
    var hexOutput : String = ""
    
    
    // Blinkenlights
    
    @IBOutlet weak var led_a0: UIImageView!
    @IBOutlet weak var led_a1: UIImageView!
    @IBOutlet weak var led_a2: UIImageView!
    @IBOutlet weak var led_a3: UIImageView!
    @IBOutlet weak var led_a4: UIImageView!
    @IBOutlet weak var led_a5: UIImageView!
    @IBOutlet weak var led_a6: UIImageView!
    @IBOutlet weak var led_a7: UIImageView!
    
    @IBOutlet weak var led_a8: UIImageView!
    @IBOutlet weak var led_a9: UIImageView!
    @IBOutlet weak var led_a10: UIImageView!
    @IBOutlet weak var led_a11: UIImageView!
    @IBOutlet weak var led_a12: UIImageView!
    @IBOutlet weak var led_a13: UIImageView!
    @IBOutlet weak var led_a14: UIImageView!
    @IBOutlet weak var led_a15: UIImageView!
    
    @IBOutlet weak var led_wait: UIImageView!
    
    @IBOutlet weak var led_d0: UIImageView!
    @IBOutlet weak var led_d1: UIImageView!
    @IBOutlet weak var led_d2: UIImageView!
    @IBOutlet weak var led_d3: UIImageView!
    @IBOutlet weak var led_d4: UIImageView!
    @IBOutlet weak var led_d5: UIImageView!
    @IBOutlet weak var led_d6: UIImageView!
    @IBOutlet weak var led_d7: UIImageView!
    
    @IBOutlet weak var labelRegisters: UILabel!
    @IBOutlet weak var textViewSourceCode: UITextView!
    
    
    @IBOutlet weak var runButton: UIButton!
    
    @IBAction func tapDone(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func highlightCurrentOpcode(_ pc : UInt16)
    {
        // Display the current instruction by finding the address in the assembly listing
        // and putting a > at the start of the line.
        let hexPC = (String(format :"%04X:", pc) + " ")
        let text = assemblerOutput.replacingOccurrences(of: hexPC, with: String(format :"%04X:", pc) + ">")
        textViewSourceCode.text = text
    }

    
    @IBAction func tapReset(_ sender: Any) {
        labelRegisters.text = String(cString: codereset())
        highlightCurrentOpcode(0)
        led_wait.isHidden = false
        updateBlinkenlights()
    }
    
    @IBAction func tapRun(_ sender: Any) {
        if running
        {
            led_wait.isHidden = false
            runButton.setTitle("Run", for: .normal)
            running = false
            timer!.invalidate()
        }
        else
        {
            led_wait.isHidden = true
            runButton.setTitle("Stop", for: .normal)
            running = true
            timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        }
        
     }
    
    @objc func fireTimer() {
        let temp = currentAddress()
        coderun()
        updateBlinkenlights()
        highlightCurrentOpcode(UInt16(currentAddress()))
        if temp == currentAddress() || currentAddress() > 65536
        {
            tapRun(self)
        }
    }
    
    @IBAction func tapStep(_ sender: Any) {
        labelRegisters.text = String(cString: codestep())
        highlightCurrentOpcode(UInt16(currentAddress()))
        updateBlinkenlights()
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        codeload(hexOutput);
        labelRegisters.text = "OK: Code loaded"
        textViewSourceCode.text = assemblerOutput
        codereset()
        led_wait.isHidden = false
        updateBlinkenlights()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    

    
    func updateBlinkenlights()
    {
        let data = currentData()
        var address : Int32 = 0
        
        if running
        {
            address = currentAddressBus()
        }
        else
        {
            address = currentAddress()
        }
        
        led_a0.isHidden = (0 == (UInt(address) & 1))
        led_a1.isHidden = (0 == (UInt(address) & 2))
        led_a2.isHidden = (0 == (UInt(address) & 4))
        led_a3.isHidden = (0 == (UInt(address) & 8))
        led_a4.isHidden = (0 == (UInt(address) & 16))
        led_a5.isHidden = (0 == (UInt(address) & 32))
        led_a6.isHidden = (0 == (UInt(address) & 64))
        led_a7.isHidden = (0 == (UInt(address) & 128))
        
        led_a8.isHidden = (0 == (UInt(address) & 256))
        led_a9.isHidden = (0 == (UInt(address) & 512))
        led_a10.isHidden = (0 == (UInt(address) & 1024))
        led_a11.isHidden = (0 == (UInt(address) & 2048))
        led_a12.isHidden = (0 == (UInt(address) & 4096))
        led_a13.isHidden = (0 == (UInt(address) & 8192))
        led_a14.isHidden = (0 == (UInt(address) & 16384))
        led_a15.isHidden = (0 == (UInt(address) & 32768))
        
        led_d0.isHidden = (0 == (UInt(data) & 1))
        led_d1.isHidden = (0 == (UInt(data) & 2))
        led_d2.isHidden = (0 == (UInt(data) & 4))
        led_d3.isHidden = (0 == (UInt(data) & 8))
        led_d4.isHidden = (0 == (UInt(data) & 16))
        led_d5.isHidden = (0 == (UInt(data) & 32))
        led_d6.isHidden = (0 == (UInt(data) & 64))
        led_d7.isHidden = (0 == (UInt(data) & 128))
        
    }
    
    
    
}

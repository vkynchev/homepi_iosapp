//
//  DeviceTableViewController.swift
//  HomePi
//
//  Created by Viktor Kynchev on 11/17/16.
//  Copyright © 2016 Viktor Kynchev. All rights reserved.
//

import UIKit
import CoreData
import SwiftMQTT

var selectedDevice: NSManagedObject!
var selectedDevicePinState: [[Int]]!

class DeviceTableViewController: UITableViewController, MQTTSessionDelegate {

    var mqttSession: MQTTSession!
    
    var hiddenSections = [Int]()
    
    @IBOutlet var sliderElements: [UISlider]!
    @IBOutlet var switchElements: [UISwitch]!
    
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var deviceIDLabel: UILabel!
    @IBOutlet weak var deviceTypeLabel: UILabel!
    @IBOutlet weak var deviceFirmwareLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        sharedMQTTSingleton.subscribeToChannel(channel: selectedDevice.value(forKey: "topic") as! String + "/state")
        
        //Duplicate mqttSession
        mqttSession = sharedMQTTSingleton.mqttSession
        mqttSession.delegate = self
        
        //Set text for info fields
        let deviceID = selectedDevice.value(forKey: "id") as! Int
        deviceNameLabel.text = selectedDevice.value(forKey: "name") as! String?
        deviceIDLabel.text = String(deviceID)
        deviceFirmwareLabel.text = selectedDevice.value(forKey: "firmware") as! String?
        //nameTextField.text = selectedDevice.value(forKey: "name") as! String?
        
        switch selectedDevice.value(forKey: "type") as! Int {
        case 0:
            deviceTypeLabel.text = "Advanced Controller"
            hiddenSections.append(3)
        case 1:
            deviceTypeLabel.text = "Power Outlet"
            hiddenSections.append(1)
            hiddenSections.append(2)
        case 2:
            deviceTypeLabel.text = "LED Controller"
            hiddenSections.append(2)
            hiddenSections.append(3)
        default:
            deviceTypeLabel.text = "No device type"
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sharedMQTTSingleton.unsubscribeFromChannel(channel: selectedDevice.value(forKey: "topic") as! String + "/state")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Custom functions
    
    func updatePinStates() {
        for uislider in sliderElements {
            let sliderPin = uislider.tag
            
            for arrPins in selectedDevicePinState {
                if arrPins.index(of: sliderPin) == 0 {
                    uislider.value = Float(arrPins[1])
                }
            }
        }
        
        for uiswitch in switchElements {
            let switchPin = uiswitch.tag
            
            for arrPins in selectedDevicePinState {
                if arrPins.index(of: switchPin) == 0 {
                    if(arrPins[1] >= 512) {
                        uiswitch.setOn(true, animated: true)
                    } else {
                        uiswitch.setOn(false, animated: true)
                    }
                }
            }
        }
    }

    
    // MARK: IBActions
    
    @IBAction func sliderChanged(_ sender: Any) {
        guard let uislider = sender as? UISlider else {
            return
        }
        
        let pinNumber = uislider.tag
        let pinValue = round(uislider.value)
        let pinCommand = ["command": "set_pin", "pin": pinNumber, "value": Int(pinValue)] as [String : Any]
        
        let data = try! JSONSerialization.data(withJSONObject: pinCommand, options: [])
            
        mqttSession.publish(data, in: selectedDevice.value(forKey: "topic") as! String + "/set", delivering: .atMostOnce, retain: false) { (succeeded, error) -> Void in
            if succeeded {
                print("Published", pinCommand, "to", selectedDevice.value(forKey: "id") as! Int)
            }
        }
    }
    
    @IBAction func switchChanged(_ sender: Any) {
        guard let uiswitch = sender as? UISwitch else {
            return
        }
        
        let pinNumber = uiswitch.tag
        var pinCommand: [String: Any]!
        
        if(uiswitch.isOn) {
            pinCommand = ["command": "set_pin", "pin": pinNumber, "value": 1023]
        } else {
            pinCommand = ["command": "set_pin", "pin": pinNumber, "value": 0]
        }
        
        let data = try! JSONSerialization.data(withJSONObject: pinCommand, options: [])
        
        mqttSession.publish(data, in: selectedDevice.value(forKey: "topic") as! String + "/set", delivering: .atMostOnce, retain: false) { (succeeded, error) -> Void in
            if succeeded {
                print("Published", pinCommand, "to", selectedDevice.value(forKey: "id") as! Int)
            }
        }
    }
    
    // MARK: - UITableViewDelegate Methods
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // If the device name cell is selected
        if indexPath.section == 0 && indexPath.row == 0 {
            let alertController = UIAlertController(title: "Change Name", message: "", preferredStyle: .alert)
            
            let saveAction = UIAlertAction(title: "Save", style: .default, handler: {
                alert -> Void in
                
                let newDeviceNameField = alertController.textFields![0] as UITextField
                let newDeviceName = newDeviceNameField.text ?? ""
                
                let managedContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
                
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Device")
                let predicate = NSPredicate(format: "id == %ld", selectedDevice.value(forKey: "id") as! Int)
                fetchRequest.predicate = predicate
                
                do {
                    let results = try managedContext.fetch(fetchRequest) as! [Device]
                    if results.count > 0 {
                        if newDeviceName != "" {
                            results.first?.name = newDeviceName
                            self.deviceNameLabel.text = newDeviceName
                        } else {
                            let alertController2 = UIAlertController(title: "Device name cannot be empty", message: "", preferredStyle: .alert)
                            
                            let okAction2 = UIAlertAction(title: "OK", style: .default, handler: {
                                (action : UIAlertAction!) -> Void in
                                
                            })
                            
                            alertController2.addAction(okAction2)
                            
                            self.present(alertController2, animated: true, completion: nil)
                        }
                    }
                    
                    do {
                        try managedContext.save()
                    } catch let error as NSError  {
                        print("Could not save \(error), \(error.userInfo)")
                    }
                } catch let error as NSError {
                    print("Could not fetch \(error), \(error.userInfo)")
                }
            })
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: {
                (action : UIAlertAction!) -> Void in
                
            })
            
            alertController.addTextField { (textField : UITextField!) -> Void in
                textField.text = selectedDevice.value(forKey: "name") as! String?
                textField.placeholder = "Enter device name"
            }
            
            alertController.addAction(saveAction)
            alertController.addAction(cancelAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if hiddenSections.contains(section) {
            return 0.1
        }
        
        if hiddenSections.contains(section-1) {
            return 18
        }
        
        if section == 0 {
            return 56
        }
        
        return 36
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if hiddenSections.contains(section) {
            return ""
        }
        
        switch section {
        case 0:
            return "INFO"
        case 1:
            return "RGB LED"
        case 2:
            return "GPIO"
        default:
            return "OUTLETS"
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if hiddenSections.contains(section) {
            return 0
        }
        
        switch section {
        case 0:
            return 4
        case 1:
            return 3
        case 2:
            return 11
        case 3:
            return 1
        default:
            return 0
        }
    }

    // MARK: MQTTSessionProtocol
    
    func mqttDidReceive(message data: Data, in topic: String, from session: MQTTSession) {
        let stringData = String(data: data, encoding: .utf8)
        
        if topic == selectedDevice.value(forKey: "topic") as! String + "/state"  {
            let jsonData = stringData?.data(using: .utf8)!
            let json = try? JSONSerialization.jsonObject(with: jsonData!, options: [])
            if let devicePinState = json as? [String: Any] {
                if let pinStates = devicePinState["pinStates"] as? [[Int]] {
                    selectedDevicePinState = pinStates
                    
                    self.updatePinStates()
                    
                }
            }
        }
    }
    
    func mqttDidDisconnect(session: MQTTSession) {
        print("Disconnected!")
        print("Reconnecting...")
        sharedMQTTSingleton.establishConnection(host: "192.168.1.10")
        sharedMQTTSingleton.subscribeToChannel(channel: "devices")
        sharedMQTTSingleton.subscribeToChannel(channel: selectedDevice.value(forKey: "topic") as! String + "/state")
    }
    
    func mqttSocketErrorOccurred(session: MQTTSession) {
        print("Socket error!")
    }

}

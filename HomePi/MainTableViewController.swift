//
//  MainTableViewController.swift
//  HomePi
//
//  Created by Viktor Kynchev on 11/16/16.
//  Copyright © 2016 Viktor Kynchev. All rights reserved.
//

import UIKit
import CoreData
import SwiftMQTT

class MainTableViewController: UITableViewController, MQTTSessionDelegate {
    
    var mqttSession: MQTTSession!
    var devices = [NSManagedObject]()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let managedContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        let fetchRequest =  NSFetchRequest<NSFetchRequestResult>(entityName: "Device")
        
        do {
            let results = try managedContext.fetch(fetchRequest)
            //for managedObject in results {
            //    let managedObjectData:NSManagedObject = managedObject as! NSManagedObject
            //    managedContext.delete(managedObjectData)
            //}
            devices = results as! [NSManagedObject]
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        
        //Duplicate mqttSession
        mqttSession = sharedMQTTSingleton.mqttSession
        mqttSession.delegate = self
        
        tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        sharedMQTTSingleton.establishConnection(host: "192.168.1.10")
        sharedMQTTSingleton.subscribeToChannel(channel: "devices")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    /*
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "toDevice") {
            let deviceController = segue.destination as! DeviceViewController;
            
            deviceController.selectedDevice = selectedDevice
        }
    }
    */
    
    // MARK: MQTTSessionProtocol
    
    func mqttDidReceive(message data: Data, in topic: String, from session: MQTTSession) {
        let stringData = String(data: data, encoding: .utf8)
        let jsonData = stringData?.data(using: .utf8)!
        let json = try? JSONSerialization.jsonObject(with: jsonData!, options: [])
        
        if let device = json as? [String: Any] {
            if let id = device["id"] as? Int {
                let deviceName = device["name"] as! String
                let deviceTopic = device["topic"] as! String
                let deviceFirmware = device["firmware_version"] as! String
                
                self.addDevice(id: id, name: deviceName, topic: deviceTopic, firmware: deviceFirmware)
            }
        }
    }
    
    func mqttDidDisconnect(session: MQTTSession) {
        print("Disconnected!")
    }
    
    func mqttSocketErrorOccurred(session: MQTTSession) {
        print("Socket error!")
    }
    
    // MARK: Custom functions
    
    func addDevice(id: Int, name: String, topic: String, firmware: String) {
        let managedContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Device")
        let predicate = NSPredicate(format: "id == %ld", id)
        fetchRequest.predicate = predicate
        
        do {
            let results = try managedContext.fetch(fetchRequest) as! [Device]
            if results.count > 0 {
                results.first?.topic = topic
                results.first?.firmware = firmware
            } else {
                let entity =  NSEntityDescription.entity(forEntityName: "Device", in:managedContext)
                let device = NSManagedObject(entity: entity!, insertInto: managedContext)
                
                device.setValue(firmware, forKey: "firmware")
                device.setValue(id, forKey: "id")
                device.setValue(name, forKey: "name")
                device.setValue(topic, forKey: "topic")
                
                devices.append(device)
            }
            
            do {
                try managedContext.save()
            } catch let error as NSError  {
                print("Could not add \(error), \(error.userInfo)")
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        
        tableView.reloadData()
    }
    
    // MARK: UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Devices"
        default:
            return "Section \(section)"
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell")
        
        let device = devices[indexPath.row]
        
        cell?.textLabel!.text = device.value(forKey: "name") as? String
        //cell?.detailTextLabel!.text = "Firmware: \(device.value(forKey: "firmware") as! String)"
        
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            let managedContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
            
            managedContext.delete(devices[indexPath.row])
            
            do {
                try managedContext.save()
                devices.remove(at: indexPath.row)
            } catch let error as NSError  {
                print("Could not delete \(error), \(error.userInfo)")
            }
            
            tableView.reloadData()
        }
    }
    
    // MARK: - UITableViewDelegate Methods
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedDevice = devices[indexPath.row]
    }

}


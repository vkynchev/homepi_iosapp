//
//  MQTTSingleton.swift
//  HomePi
//
//  Created by Viktor Kynchev on 11/16/16.
//  Copyright © 2016 Viktor Kynchev. All rights reserved.
//

import Foundation
import SwiftMQTT

class MQTTSingleton: MQTTSessionDelegate {
    
    var mqttSession: MQTTSession!
    
    // MARK: Custom MQTT functions
    
    func establishConnection(host: String = "localhost", port: UInt16 = 1883) {
        let clientID = self.clientID()
        
        mqttSession = MQTTSession(host: host, port: port, clientID: clientID, cleanSession: true, keepAlive: 15, useSSL: false)
        mqttSession.delegate = self
        print("Trying to connect to \(host) on port \(port) for clientID \(clientID)")
        
        mqttSession.connect {
            if !$0 {
                print("Error Occurred During connection \($1)")
                return
            }
            print("Connected!")
        }
    }
    
    func subscribeToChannel(channel: String = "#") {
        mqttSession.subscribe(to: channel, delivering: .atMostOnce) {
            if !$0 {
                print("Error Occurred During subscription \($1)")
                return
            }
            print("Subscribed to \(channel)")
        }
    }
    
    func unsubscribeFromChannel(channel: String = "#") {
        mqttSession.unSubscribe(from: channel) {
            if !$0 {
                print("Error Occurred During unsubscription \($1)")
                return
            }
            print("Unsubscribed from \(channel)")
        }
    }
    
    // MARK: MQTTSessionProtocol
    
    func mqttDidReceive(message data: Data, in topic: String, from session: MQTTSession) {
        //let stringData = String(data: data, encoding: .utf8)
        //print("Received:", stringData ?? "", "in:", topic)
    }
    
    func mqttDidDisconnect(session: MQTTSession) {
        print("Disconnected!")
        print("Reconnecting...")
        self.establishConnection(host: "192.168.1.10");
        self.subscribeToChannel(channel: "devices")
    }
    
    func mqttSocketErrorOccurred(session: MQTTSession) {
        print("Socket error!")
    }
    
    // MARK: - Utilities
    
    func clientID() -> String {
        
        let userDefaults = UserDefaults.standard
        let clientIDPersistenceKey = "clientID"
        let clientID: String
        
        if let savedClientID = userDefaults.object(forKey: clientIDPersistenceKey) as? String {
            clientID = savedClientID
        } else {
            clientID = randomStringWithLength(5)
            userDefaults.set(clientID, forKey: clientIDPersistenceKey)
            userDefaults.synchronize()
        }
        
        return clientID
    }
    
    func randomStringWithLength(_ len: Int) -> String {
        let letters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".characters)
        
        var randomString = String()
        for _ in 0..<len {
            let length = UInt32(letters.count)
            let rand = arc4random_uniform(length)
            randomString += String(letters[Int(rand)])
        }
        return String(randomString)
    }
}

//Create singleton
let sharedMQTTSingleton = MQTTSingleton()

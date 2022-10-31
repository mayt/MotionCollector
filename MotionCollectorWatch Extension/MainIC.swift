//
//  InterfaceController.swift
//  MotionCollectorWatch Extension
//
//  Created by Aleksei Degtiarev on 01/04/2018.
//  Copyright © 2018 Aleksei Degtiarev. All rights reserved.
//

import WatchKit
import Foundation
import CoreMotion
import HealthKit
import WatchConnectivity


class MainIC: WKInterfaceController, WCSessionDelegate, CLLocationManagerDelegate {
    
    var locationManager: CLLocationManager?
    var currentLocation: CLLocation?
    var canRequestLocation: Bool = false

    // Statuses
    enum Status {
        case waiting
        case recording
    }
    
    var status: Status = Status.waiting {
        willSet(newStatus) {
            
            switch(newStatus) {
            case .waiting:
                waiting()
                break
                
            case .recording:
                recording()
                break
            }
        }
        didSet {
            
        }
    }
    
    // Outlets
    @IBOutlet var timer: WKInterfaceTimer!
    @IBOutlet var recIDLabel: WKInterfaceLabel!
    @IBOutlet var recNumberPicker: WKInterfacePicker!
    @IBOutlet var recordDataFromPhoneSwitch: WKInterfaceSwitch!
    
    // Constants
    let IDsAmount = 20
    let currentFrequency: Int = 60
    
    // For session saving
    var nextSessionid: Int = 0
    var recordTime: String = ""
    var sensorOutputs = [SensorOutput]()
    var isRecordDataFromPhone = true
    var recordID: Int = 0
    var currentSessionDate: NSDate = NSDate()
    
    // For motion getting
    let motion = CMMotionManager()
    let queue = OperationQueue()
    
    // For background work
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    
    
    // MARK - WKInterfaceController events
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // prepare recNumberPicker
        var items = [WKPickerItem]()
        for i in 0..<IDsAmount {
            let item = WKPickerItem()
            item.title = String (i)
            items.append(item)
        }
        recNumberPicker.setItems(items)
        
        // Step 3: initalise and configure CLLocationManager
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        
        // Step 4: request authorization
        locationManager?.requestAlwaysAuthorization()
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.activityType = .fitness
        
        // needs to be implemented
        // findLastSessionId()
        
        // Serial queue for sample handling and calculations.
        queue.maxConcurrentOperationCount = 1
        queue.name = "MotionManagerQueue"
        
        status = .waiting
        
        
        // Configure WCSessionDelegate objects
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }

    }

    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .denied: // Setting option: Never
          print("LocationManager didChangeAuthorization denied")
        case .notDetermined: // Setting option: Ask Next Time
          print("LocationManager didChangeAuthorization notDetermined")

        case .authorizedWhenInUse: // Setting option: While Using the App
          print("LocationManager didChangeAuthorization authorizedWhenInUse")
          
          // Stpe 6: Request a one-time location information
          //locationManager?.startUpdatingLocation()
            canRequestLocation = true
        case .authorizedAlways: // Setting option: Always
          print("LocationManager didChangeAuthorization authorizedAlways")
            canRequestLocation = true
          // Stpe 6: Request a one-time location information
          //locationManager?.requestLocation()
        case .restricted: // Restricted by parental control
          print("LocationManager didChangeAuthorization restricted")
        default:
          print("LocationManager didChangeAuthorization")
        }
      }

      // Step 7: Handle the location information
      func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        /*print("LocationManager didUpdateLocations: numberOfLocation: \(locations.count)")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        locations.forEach { (location) in
          print("LocationManager didUpdateLocations: \(dateFormatter.string(from: location.timestamp)); \(location.coordinate.latitude), \(location.coordinate.longitude)")
          print("LocationManager altitude: \(location.altitude)")
          print("LocationManager floor?.level: \(location.floor?.level)")
          print("LocationManager horizontalAccuracy: \(location.horizontalAccuracy)")
          print("LocationManager verticalAccuracy: \(location.verticalAccuracy)")
          print("LocationManager speedAccuracy: \(location.speedAccuracy)")
          print("LocationManager speed: \(location.speed)")
          print("LocationManager timestamp: \(location.timestamp)")
            if #available(watchOSApplicationExtension 6.2, *) {
                print("LocationManager courseAccuracy: \(location.courseAccuracy)")
            } else {
                // Fallback on earlier versions
            } // 13.4
          print("LocationManager course: \(location.course)")
            print("LocationManager accuracy level: \(manager.accuracyAuthorization)")
        }
         */
          locations.forEach { (location) in
              self.currentLocation = location
          }
      }
      
      func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager didFailWithError \(error.localizedDescription)")
        if let error = error as? CLError, error.code == .denied {
           // Location updates are not authorized.
          // To prevent forever looping of `didFailWithError` callback

           return
        }
      }
    
    
    // MARK - Control work of getting motion Data
    
    func startGettingData() {
        
        // send info to start data collecting on phone
        if (isRecordDataFromPhone) {
            let WCsession = WCSession.default
            if WCsession.isReachable {
                let data = ["Running": true, "RecordID": recordID] as [String : Any]
                
                WCsession.sendMessage(data, replyHandler: { (response) in
                    DispatchQueue.main.async {
                        print ("received response: \(response)")
                    }
                }, errorHandler: nil)
            }
        }
        
        // If we have already started the workout, then do nothing.
        if (session != nil) {
            return
        }
        
        if (canRequestLocation) {
            locationManager?.startUpdatingLocation()
        }
        
        // Configure the workout session.
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .walking
        workoutConfiguration.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(configuration: workoutConfiguration)
        } catch {
            fatalError("Unable to create the workout session!")
        }
        
        // Start the workout session and device motion updates.
        healthStore.start(session!)
        
        // Check motion availability
        if !motion.isDeviceMotionAvailable {
            print("Device Motion is not available.")
            return
        }
        
        motion.deviceMotionUpdateInterval = 1.0 / Double(currentFrequency)
        motion.startDeviceMotionUpdates(to: queue) { (deviceMotion: CMDeviceMotion?, error: Error?) in
            if error != nil {
                print("Encountered error: \(error!)")
            }
            
            if deviceMotion != nil {
                
                // let currenTime = self.returnCurrentTime()
                let GyroX = deviceMotion!.rotationRate.x
                let GyroY = deviceMotion!.rotationRate.y
                let GyroZ = deviceMotion!.rotationRate.z
                
                let AccX = deviceMotion!.userAcceleration.x;
                let AccY = deviceMotion!.userAcceleration.y;
                let AccZ = deviceMotion!.userAcceleration.z;
                
                // print ( "Gyro: \(currenTime) \(GyroX), \(GyroY), \(GyroZ)")
                // print ( "Acc : \(currenTime) \(AccX), \(AccY), \(AccZ)")
                
                
                let sensorOutput = SensorOutput()
                
                sensorOutput.timeStamp = Date()
                sensorOutput.gyroX = GyroX
                sensorOutput.gyroY = GyroY
                sensorOutput.gyroZ = GyroZ
                sensorOutput.accX = AccX
                sensorOutput.accY = AccY
                sensorOutput.accZ = AccZ
                sensorOutput.accGravX = deviceMotion!.gravity.x
                sensorOutput.accGravY = deviceMotion!.gravity.y
                sensorOutput.accGravZ = deviceMotion!.gravity.z
                
                sensorOutput.altitude = self.currentLocation?.altitude ?? -1
                sensorOutput.locX = self.currentLocation?.coordinate.longitude ?? -1
                sensorOutput.locY = self.currentLocation?.coordinate.latitude ?? -1
                sensorOutput.locXAcc = self.currentLocation?.horizontalAccuracy ?? -1
                sensorOutput.locYAcc = self.currentLocation?.verticalAccuracy ?? -1
                sensorOutput.speed = self.currentLocation?.speed ?? -1
                sensorOutput.speedAcc = self.currentLocation?.speedAccuracy ?? -1
                sensorOutput.locTimeDiff = sensorOutput.timeStamp!.timeIntervalSince1970 - (self.currentLocation?.timestamp.timeIntervalSince1970 ?? 0)
                sensorOutput.course = self.currentLocation?.course ?? -1
                sensorOutput.courseAcc = self.currentLocation?.courseAccuracy ?? -1
                
                self.sensorOutputs.append(sensorOutput)
                
            }
        }
    }
    
    func stopGettingData(handler: @escaping(_ finishedGettingData: Bool) -> ()) {
        
        // If we have already stopped the workout, then do nothing.
        if (session == nil) {
            return
        }
        
        // Stop the device motion updates and workout session.
        motion.stopDeviceMotionUpdates()
        healthStore.end(session!)
        
        if (canRequestLocation) {
            locationManager?.stopUpdatingLocation()
        }

        print("Ended health session")
        
        // send info to start data collecting on phone
        let WCsession = WCSession.default
        if WCsession.isReachable {
            let data = ["Running": false]
            
            WCsession.sendMessage(data, replyHandler: { (response) in
                DispatchQueue.main.async {
                    print ("received response: \(response)")
                }
            }, errorHandler: nil)
        }
        
        // Clear the workout session.
        session = nil
        
        handler(true)
    }
    
    
    func returnCurrentTime() -> String {
        let date = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minutes = calendar.component(.minute, from: date)
        let seconds = calendar.component(.second, from: date)
        let nanoseconds = calendar.component(.nanosecond, from: date)
        
        let currentTime = "\(hour):\(minutes):\(seconds):\(nanoseconds)"
        
        return currentTime
    }
    
    
    
    // MARK - Action controlls
    
    @IBAction func startButtonPressed() {
        // check status
        if status == Status.recording { return }
        
        startGettingData()
        status = .recording
        
        // Start session recording
        currentSessionDate = NSDate()
    }
    
    @IBAction func stopButtonPressed() {
        
        // check status
        if status == Status.waiting { return }
        
        timer.stop()
        
        stopGettingData { (finishedGettingData) in
            
            // Pack up data into container
            let sessionContainer = SessionContainer()
            sessionContainer.nextSessionid = self.nextSessionid
            sessionContainer.currentSessionDate = self.currentSessionDate as Date
            sessionContainer.currentFrequency = self.currentFrequency
            sessionContainer.recordID = self.recordID
            sessionContainer.duration = self.recordTime
            sessionContainer.sensorOutputs = self.sensorOutputs
            
            // Archiving data
            let mutableData = NSMutableData()
            let archiver = NSKeyedArchiver(forWritingWith: mutableData)
            try! archiver.encodeEncodable(sessionContainer, forKey: NSKeyedArchiveRootObjectKey)
            archiver.finishEncoding()
            
            
            // Saving data to file
            let sourceURL = self.getDocumentDirectory().appendingPathComponent("saveFile")
            mutableData.write(to: sourceURL, atomically: true)
            print ("Saved file")
            
            
            // Sending file
            let session = WCSession.default
            if session.activationState == .activated {
                
                // create a URL from where the file is/will be saved
                let fm = FileManager.default
                let sourceURL = self.getDocumentDirectory().appendingPathComponent("saveFile")
                
                if !fm.fileExists(atPath: sourceURL.path) {
                    
                    // the file doesn't exist - create it now
                    try? "Hello from Apple Watch!".write(to: sourceURL, atomically: true, encoding: String.Encoding.utf8)
                    
                }
                
                print ("Starting sending file")
                // the file exists now; send it across the session
                session.transferFile(sourceURL, metadata: nil)
                print ("File sent")
            }
            
            
            // Preparing watch for new session
            self.sensorOutputs.removeAll()
            self.nextSessionid += 1
            
            
        }
        
        
    }
    
    func getDocumentDirectory() -> URL {
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    @IBAction func recordDataFromPhoneSwitchChanged(_ value: Bool) {
        isRecordDataFromPhone = value
    }
    
    @IBAction func recNumberPickerChanged(_ value: Int) {
        recordID = value
    }
    
    
    
    // MARK - Update changing state
    
    func waiting() {
        recNumberPicker.setEnabled(true)
        timer.setDate(Date(timeIntervalSinceNow: 0.0))
        recordDataFromPhoneSwitch.setEnabled(true)
    }
    
    func recording() {
        recNumberPicker.setEnabled(false)
        timer.setDate(Date(timeIntervalSinceNow: 0.0))
        timer.start()
        recordDataFromPhoneSwitch.setEnabled(false)
    }
    
    
    
    // MARK - Work with WCSessionDelegate
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            
            if let isFinishedHanflingFile = userInfo["isFinishedHandling"] as? Bool {
                if isFinishedHanflingFile {
                    print("Finished handling file")
                    self.status = .waiting
                }
            }
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
}

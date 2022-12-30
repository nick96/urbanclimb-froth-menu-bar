//
//  urbanclimb_frothApp.swift
//  urbanclimb-froth
//
//  Created by Nick Spain on 20/12/2022.
//

import SwiftUI

@main
struct urbanclimb_frothApp: App {
    @State var currentVenue: String = "Collingwood"
    @State var collingwoodStatus = VenueStatus(name: "Collingwood", status: "unknown", froth: "unknown")
    @State var backgroundUpdater: DispatchWorkItem? = nil
    @State var updated: Bool = false
    
    init() {
        NSLog("Starting updater thread (current thread: \(Thread.current)")
        self.ensureBackgroundFrothUpdate()
    }
    
    var body: some Scene {
        MenuBarExtra("UrbanClimb Froth", systemImage: "figure.climbing") {
            Button(collingwoodStatus.to_s()) {
                NSLog("Collingwood, status: \(collingwoodStatus), updated: \(updated) (current thread: \(Thread.current)")
                currentVenue = "Collingwood"
            }
        }
    }
    
    func updateFrothStatus() async {
        NSLog("Updating froth status")
    }
    
    func getVenueStatus(venue: String, completion: @escaping (_ venueStatus: VenueStatusResponse) -> Void) {
        var uuid: String? = nil
        if venue == "Collingwood" {
            uuid = "8674E350-D340-4AB3-A462-5595061A6950"
        } else {
            uuid = "46E5373C-2310-4520-B576-CCB4E4EF548D"
        }
        let url = URL(string: "https://portal.urbanclimb.com.au/uc-services/ajax/gym/occupancy.ashx?branch=\(uuid!)")
        let task = URLSession.shared.dataTask(with: url!) {
            (data, response, error) in
            if let error = error {
                NSLog("Error: \(error)")
                return
            }
            let decoder = JSONDecoder()
            do {
                let body = try decoder.decode(VenueStatusResponse.self, from: data!)
                completion(body)
            } catch {
                NSLog("Deserialization failed: \(error)")
            }
            
        }
        task.resume()
    }
    
    func ensureBackgroundFrothUpdate() {
        if (self.backgroundUpdater == nil) {
            NSLog("No background updater found, creating one")
            let backgroundUpdater = DispatchWorkItem {
                NSLog("Background updater started")
                while true {
                    let work = DispatchWorkItem {
                        NSLog("Updating the status for each of our venues (current thread: \(Thread.current)")
                        getVenueStatus(venue: "Collingwood") {
                            response in
                                DispatchQueue.main.async {
                                    NSLog("Updating collingwood status on main thread to \(response) (current thread: \(Thread.current)")
                                    self.collingwoodStatus = VenueStatus.fromResponse(response: response)
                                    self.updated.toggle()
                                    NSLog("Updated collingwood status: \(self.collingwoodStatus.to_s()) (current thread: \(Thread.current)")
                                }
                        }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: work)
                    work.wait()
                    }
                }
            
            self.backgroundUpdater = backgroundUpdater
            NSLog("Putting background updater on the global dispatch queue")
            DispatchQueue.global().async(execute: backgroundUpdater)
            
        }
    }
}

struct VenueStatusResponse: Codable {
    var name: String
    var status: String
    var froth: String
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case status = "GoogleStatus"
        case froth = "Status"
    }
}

class VenueStatus {
    var name: String
    var status: String
    var froth: String
    
    init(name: String, status: String, froth: String) {
        self.name = name
        self.status = status
        self.froth = froth
    }
    
    func to_s() -> String {
        return "\(name) (\(status)) [\(froth)]"
    }
    
    static func fromResponse(response: VenueStatusResponse) -> VenueStatus {
        return VenueStatus(name: response.name, status: response.status, froth: response.froth)
    }
}


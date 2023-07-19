import SwiftUI

@main
struct urbanclimb_frothApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(vm: VenueStatusListViewModel())
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var venueStatusListVM: VenueStatusListViewModel!
    
    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        self.venueStatusListVM = VenueStatusListViewModel()
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let statusButton = statusItem.button {
            statusButton.image = NSImage(
                systemSymbolName: "figure.climbing",
                accessibilityDescription: "Climbing"
            )
            statusButton.action = #selector(togglePopover)
        }
        self.popover = NSPopover()
        self.popover.contentSize = NSSize(width: 300, height: 300)
        self.popover.behavior = .transient
        self.popover.contentViewController = NSHostingController(rootView: ContentView(vm: self.venueStatusListVM))
    }
    
    @objc func togglePopover() {
        Task {
            await self.venueStatusListVM.populateVenueStatus()
        }
        
        if let button = self.statusItem.button {
            if self.popover.isShown {
                self.popover.performClose(nil)
            } else {
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var vm: VenueStatusListViewModel
    
    init(vm: VenueStatusListViewModel) {
        self._vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Urban Climb Froth").padding()
            List(vm.venueStatuss, id: \.name) { venue in
                HStack(alignment: .center) {
                    Text(venue.name).fontWeight(.semibold)
                    Text("(\(venue.status)): ")
                    Text(venue.froth)
                    Text("(\(Int(floor(venue.capacity)))%)")
                }
            }.task {
                await vm.populateVenueStatus()
            }
        }.frame(width: 300, height: 300)
    }
}

struct ContentView_Preview: PreviewProvider {
    static var previews: some View {
        ContentView(vm: VenueStatusListViewModel())
    }
}

struct VenueStatus: Codable {
    let name: String
    let status: String
    let froth: String
    let capacity: Float
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case status = "GoogleStatus"
        case froth = "Status"
        case capacity = "CurrentPercentage"
    }
}

enum NetworkError: Error {
    case invalidResponse
}

class UrbanClimbFrothService {
    func getVenueStatuss() async throws -> [VenueStatus] {
        let venues = ["Collingwood"]
        let venueUUIDs = [
            "Collingwood": "8674E350-D340-4AB3-A462-5595061A6950",
        ]
        var statuss: [VenueStatus] = []
        for venue in venues {
            if let uuid = venueUUIDs[venue] {
                let url = URL(string: "https://portal.urbanclimb.com.au/uc-services/ajax/gym/occupancy.ashx?branch=\(uuid)")
                let (data, response) = try await URLSession.shared.data(from: url!)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw NetworkError.invalidResponse
                }
                let status = try JSONDecoder().decode(VenueStatus.self, from: data)
                statuss.append(status)
            }
        }
        return statuss
    }
}

@MainActor
class VenueStatusListViewModel: ObservableObject {
    @Published var venueStatuss: [VenueStatusViewModel] = []
    
    func populateVenueStatus() async {
        do {
            let statuss = try await UrbanClimbFrothService().getVenueStatuss()
            self.venueStatuss = statuss.map(VenueStatusViewModel.init)
        } catch {
            print(error)
        }
    }
}

struct VenueStatusViewModel {
    private var venueStatus: VenueStatus
    
    init(venueStatus: VenueStatus) {
        self.venueStatus = venueStatus
    }
    
    var name: String {
        venueStatus.name
    }
    
    var status: String {
        venueStatus.status
    }
    
    var froth: String {
        venueStatus.froth
    }
    
    var capacity: Float { venueStatus.capacity }
}

import CoreLocation
import Foundation
import SwiftUI

struct Place: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: String
    let distance: String
    /// Short street/area line shown under the name in search results.
    var address: String = ""
    let ratingLabel: String
    let summary: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let accentColor: Color
    let gallerySymbols: [String]
    let facilitySymbols: [String]
    let elevatorDetails: [ElevatorDetail]
    let reviewsSummary: String
    /// Overall accessibility grade used to color and filter the map pin.
    /// nil for live search results until the backend enrichment resolves.
    var grade: OverallAccessibility? = nil
    /// Populated for places from a real MKLocalSearch result once the
    /// backend enrichment call resolves — nil (and unused) for the mock
    /// mock detail fixtures. See PlaceDetailView's live grade loading.
    var isLiveResult: Bool = false

    struct ElevatorDetail: Hashable {
        let symbol: String
        let label: String
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }
}

extension Place {
    /// Builds a minimal Place from a real on-device MKLocalSearch result.
    /// The decorative mock fields (gallery, elevator details, canned
    /// reviews summary) don't exist for a real place, so they're left
    /// empty rather than faked — PlaceDetailView only renders them when
    /// non-empty, and shows the real, live Accessibility Grade instead.
    static func fromSearchResult(name: String, category: String, coordinate: CLLocationCoordinate2D, address: String = "", distance: String = "") -> Place {
        Place(
            id: UUID(),
            name: name,
            category: category,
            distance: distance,
            address: address,
            ratingLabel: "",
            summary: "",
            description: "",
            coordinate: coordinate,
            accentColor: .accentColor,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            isLiveResult: true
        )
    }

    /// The 12 major shopping malls in Bali.
    static let baliMalls: [Place] = [
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111101")!,
            name: "Beachwalk Shopping Center",
            category: "Shopping Mall",
            distance: "Kuta",
            address: "Jl. Pantai Kuta, Kuta, Badung, Bali",
            ratingLabel: "Accessible",
            summary: "Beachfront mall with wide accessible ramps and elevators.",
            description: "Beachwalk Shopping Center is an open-air shopping complex in Kuta with full wheelchair accessibility.",
            coordinate: CLLocationCoordinate2D(latitude: -8.7169, longitude: 115.1694),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .accessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111102")!,
            name: "Discovery Shopping Mall",
            category: "Shopping Mall",
            distance: "Kuta",
            address: "Jl. Kartika Plaza, Kuta, Badung, Bali",
            ratingLabel: "Accessible",
            summary: "Large oceanfront shopping center with accessible main entrances.",
            description: "Discovery Shopping Mall offers easy ramp access to beachfront dining and shops.",
            coordinate: CLLocationCoordinate2D(latitude: -8.7289, longitude: 115.1693),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .accessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111103")!,
            name: "Mal Bali Galeria",
            category: "Shopping Mall",
            distance: "Kuta",
            address: "Jl. By Pass Ngurah Rai, Kuta, Badung, Bali",
            ratingLabel: "Moderately Accessible",
            summary: "Major shopping mall with step-free concourses and spacious elevators.",
            description: "Mal Bali Galeria features wide corridors and accessible restrooms.",
            coordinate: CLLocationCoordinate2D(latitude: -8.7189, longitude: 115.1834),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111104")!,
            name: "Trans Studio Mall Bali",
            category: "Shopping Mall",
            distance: "Denpasar",
            address: "Jl. Imam Bonjol No.440, Pemecutan Klod, Denpasar, Bali",
            ratingLabel: "Accessible",
            summary: "Modern indoor mall and theme park complex with accessible elevators.",
            description: "Trans Studio Mall Bali has wide walkways, accessible toilets, and elevator access on every level.",
            coordinate: CLLocationCoordinate2D(latitude: -8.7073, longitude: 115.1882),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .accessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111105")!,
            name: "Living World Denpasar",
            category: "Shopping Mall",
            distance: "Denpasar",
            address: "Jl. Gajah Mada No.138, Denpasar, Bali",
            ratingLabel: "Accessible",
            summary: "New home living and shopping destination with full accessibility facilities.",
            description: "Living World Denpasar is equipped with accessible elevators, smooth flooring, and dedicated parking.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6324, longitude: 115.2285),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .accessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111106")!,
            name: "Icon Bali Mall",
            category: "Shopping Mall",
            distance: "Sanur",
            address: "Jl. Danau Tamblingan, Sanur, Denpasar, Bali",
            ratingLabel: "Moderately Accessible",
            summary: "Beachfront lifestyle center in Sanur with accessible boardwalk entrances.",
            description: "Icon Bali Mall offers step-free access across all retail and beachfront dining areas.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6853, longitude: 115.2625),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111107")!,
            name: "Level 21 Mall",
            category: "Shopping Mall",
            distance: "Denpasar",
            address: "Jl. Teuku Umar No.1, Dauh Puri Klod, Denpasar, Bali",
            ratingLabel: "Moderately Accessible",
            summary: "Urban shopping center in central Denpasar with elevator access to all floors.",
            description: "Level 21 Mall features accessible elevators, escalators, and nearby drop-off zones.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6738, longitude: 115.2131),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111108")!,
            name: "Lippo Mall Kuta",
            category: "Shopping Mall",
            distance: "Kuta",
            address: "Jl. Kartika Plaza, Kuta, Badung, Bali",
            ratingLabel: "Not Accessible",
            summary: "Family shopping mall near the airport with entrance steps.",
            description: "Lippo Mall Kuta features multi-level access with limited elevator coverage.",
            coordinate: CLLocationCoordinate2D(latitude: -8.7354, longitude: 115.1683),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .notAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111109")!,
            name: "Bali Collection",
            category: "Shopping Mall",
            distance: "Nusa Dua",
            address: "Nusa Dua Resort Complex, Benoa, Badung, Bali",
            ratingLabel: "No Data Available",
            summary: "Open-air shopping village in Nusa Dua.",
            description: "Bali Collection is an unverified open-air complex in Nusa Dua.",
            coordinate: CLLocationCoordinate2D(latitude: -8.8038, longitude: 115.2309),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .noData
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111110")!,
            name: "Seminyak Village",
            category: "Shopping Mall",
            distance: "Seminyak",
            address: "Jl. Kayu Jati No.8, Seminyak, Badung, Bali",
            ratingLabel: "Moderately Accessible",
            summary: "Boutique shopping mall in Seminyak with elevator and air conditioning.",
            description: "Seminyak Village has wide glass entrances, elevators, and accessible restrooms.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6823, longitude: 115.1554),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Park 23 Mall",
            category: "Shopping Mall",
            distance: "Tuban",
            address: "Jl. Kediri No.27, Tuban, Kuta, Badung, Bali",
            ratingLabel: "Moderately Accessible",
            summary: "Entertainment and retail mall near Kuta with accessible cinema and shops.",
            description: "Park 23 Mall offers flat ground-floor entry and accessible elevators.",
            coordinate: CLLocationCoordinate2D(latitude: -8.7410, longitude: 115.1783),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111112")!,
            name: "Sidewalk Jimbaran",
            category: "Shopping Mall",
            distance: "Jimbaran",
            address: "Jl. Raya Uluwatu No.88A, Jimbaran, Badung, Bali",
            ratingLabel: "No Data Available",
            summary: "Community shopping center with step-free entry.",
            description: "Sidewalk Jimbaran features accessible parking in front.",
            coordinate: CLLocationCoordinate2D(latitude: -8.7951, longitude: 115.1604),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .noData
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111113")!,
            name: "Plaza Renon",
            category: "Shopping Mall",
            distance: "Renon",
            address: "Jl. Raya Puputan, Renon, Denpasar, Bali",
            ratingLabel: "Moderately Accessible",
            summary: "Lifestyle mall in Renon with cinema and accessible ground-floor dining.",
            description: "Plaza Renon is a community shopping hub in Denpasar featuring step-free access and parking.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6748, longitude: 115.2268),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111114")!,
            name: "Samasta Lifestyle Village",
            category: "Lifestyle Village",
            distance: "Jimbaran",
            address: "Jl. Wanagiri No.1, Jimbaran, Badung, Bali",
            ratingLabel: "Accessible",
            summary: "Open-air tropical lifestyle village with wide accessible walkways.",
            description: "Samasta Lifestyle Village offers open-air shopping, accessible paths, and outdoor dining.",
            coordinate: CLLocationCoordinate2D(latitude: -8.7836, longitude: 115.1632),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .accessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111115")!,
            name: "Seminyak Square",
            category: "Shopping Complex",
            distance: "Seminyak",
            address: "Jl. Kayu Aya No.1, Seminyak, Badung, Bali",
            ratingLabel: "Moderately Accessible",
            summary: "Open-air shopping arcades and courtyard in central Seminyak.",
            description: "Seminyak Square features boutique retail shops, outdoor seating, and ground-level entry.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6828, longitude: 115.1557),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111116")!,
            name: "Matahari Duta Plaza",
            category: "Department Store",
            distance: "Denpasar",
            address: "Jl. Dewi Sartika No.4G, Dauh Puri Klod, Denpasar, Bali",
            ratingLabel: "Moderately Accessible",
            summary: "Legacy department store and retail arcade in central Denpasar.",
            description: "Matahari Duta Plaza is a multi-story retail center with elevator access to fashion floors.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6578, longitude: 115.2148),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111117")!,
            name: "Ramayana Mall Bali",
            category: "Department Store",
            distance: "Denpasar",
            address: "Jl. Diponegoro No.103, Dauh Puri Klod, Denpasar, Bali",
            ratingLabel: "Moderately Accessible",
            summary: "Legacy indoor retail mall and department store in Denpasar.",
            description: "Ramayana Mall Bali is a classic commercial shopping hub serving central Denpasar.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6579, longitude: 115.2128),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111118")!,
            name: "Sira Village Grand Outlet Bali",
            category: "Outlet Mall",
            distance: "Kuta",
            address: "Jl. Bypass Ngurah Rai, Kuta, Badung, Bali",
            ratingLabel: "Accessible",
            summary: "Brand new mega-outlet shopping village featuring international brand stores.",
            description: "Sira Village Grand Outlet Bali is a newly opened premier outdoor outlet complex with modern accessibility features.",
            coordinate: CLLocationCoordinate2D(latitude: -8.7312, longitude: 115.2348),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .accessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111119")!,
            name: "Sunset Point Shopping Centre",
            category: "Shopping Centre",
            distance: "Seminyak",
            address: "Jl. Sunset Road No.88, Seminyak, Badung, Bali",
            ratingLabel: "Accessible",
            summary: "Strip mall and dining plaza along Sunset Road with front ramp access.",
            description: "Sunset Point Shopping Centre features supermarket access, cafes, and ground-floor parking.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6852, longitude: 115.1648),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .accessible
        ),
        Place(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111120")!,
            name: "Tamora Gallery",
            category: "Lifestyle Shopping",
            distance: "Canggu",
            address: "Jl. Pantai Berawa No.99, Tibubeneng, Kuta Utara, Badung, Bali",
            ratingLabel: "No Data Available",
            summary: "Lifestyle retail village and family center in Berawa Canggu.",
            description: "Tamora Gallery is a lifestyle commercial center in Canggu with open-air shops and kids playground.",
            coordinate: CLLocationCoordinate2D(latitude: -8.6651, longitude: 115.1448),
            accentColor: .orange,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: .noData
        )
    ]
}


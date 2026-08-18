import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "English"
    case indonesia = "Indonesia"
    
    var id: String { rawValue }
    var code: String {
        switch self {
        case .english: return "en"
        case .indonesia: return "id"
        }
    }
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("app_language") var currentLanguage: AppLanguage = .english {
        willSet {
            objectWillChange.send()
        }
    }
    
    private let translations: [String: [AppLanguage: String]] = [
        // Home & General
        "Profile": [.english: "Profile", .indonesia: "Profil"],
        "Saved": [.english: "Saved", .indonesia: "Tersimpan"],
        "All reviews": [.english: "All reviews", .indonesia: "Semua ulasan"],
        "All Photos": [.english: "All Photos", .indonesia: "Semua Foto"],
        "ADD PHOTOS": [.english: "ADD PHOTOS", .indonesia: "TAMBAH FOTO"],
        "Add Photos": [.english: "Add Photos", .indonesia: "Tambah Foto"],
        "Browse": [.english: "Browse", .indonesia: "Jelajahi"],
        "Submit": [.english: "Submit", .indonesia: "Kirim"],
        "Update Review": [.english: "Update Review", .indonesia: "Perbarui Ulasan"],
        "Delete Review?": [.english: "Delete Review?", .indonesia: "Hapus Ulasan?"],
        "Your review will permanently removed. This action is irreversible.": [
            .english: "Your review will permanently removed. This action is irreversible.",
            .indonesia: "Ulasan Anda akan dihapus secara permanen. Tindakan ini tidak dapat dibatalkan."
        ],
        "Cancel": [.english: "Cancel", .indonesia: "Batal"],
        "Delete": [.english: "Delete", .indonesia: "Hapus"],
        "Review successfully removed": [.english: "Review successfully removed", .indonesia: "Ulasan berhasil dihapus"],
        "Your photos successfully added!": [.english: "Your photos successfully added!", .indonesia: "Foto Anda berhasil ditambahkan!"],
        
        // Profile Tabs
        "REVIEWS": [.english: "REVIEWS", .indonesia: "ULASAN"],
        "PHOTOS": [.english: "PHOTOS", .indonesia: "FOTO"],
        "SETTINGS": [.english: "SETTINGS", .indonesia: "PENGATURAN"],
        "Top Contributor": [.english: "Top Contributor", .indonesia: "Kontributor Teratas"],
        
        // Settings Menu
        "My Account": [.english: "My Account", .indonesia: "Akun Saya"],
        "Language": [.english: "Language", .indonesia: "Bahasa"],
        "Notifications": [.english: "Notifications", .indonesia: "Notifikasi"],
        "About App": [.english: "About App", .indonesia: "Tentang Aplikasi"],
        "Give Feedback": [.english: "Give Feedback", .indonesia: "Beri Masukan"],
        "Sign Out": [.english: "Sign Out", .indonesia: "Keluar"],
        "Delete Account": [.english: "Delete Account", .indonesia: "Hapus Akun"],
        "Delete Account?": [.english: "Delete Account?", .indonesia: "Hapus Akun?"],
        "Deleting your account will permanently remove it along with all your reviews. This action is irreversible.": [
            .english: "Deleting your account will permanently remove it along with all your reviews. This action is irreversible.",
            .indonesia: "Menghapus akun Anda akan menghapusnya secara permanen beserta semua ulasan Anda. Tindakan ini tidak dapat dibatalkan."
        ],
        "Account Deleted": [.english: "Account Deleted", .indonesia: "Akun Dihapus"],
        "We are sorry to hear you go... Tell us more about your experience for us to improve": [
            .english: "We are sorry to hear you go...\nTell us more about your experience for us to improve",
            .indonesia: "Kami sedih melihat Anda pergi...\nBeritahu kami lebih banyak tentang pengalaman Anda agar kami dapat berkembang"
        ],
        "Your feedbacks here (Optional)": [.english: "Your feedbacks here (Optional)", .indonesia: "Masukan Anda di sini (Opsional)"],
        "Back to Home": [.english: "Back to Home", .indonesia: "Kembali ke Beranda"],
        "What Provided:": [.english: "What Provided:", .indonesia: "Fasilitas Tersedia:"],
        "No reviews yet": [.english: "No reviews yet", .indonesia: "Belum ada ulasan"],

        // Search & Sheet
        "Search a place": [.english: "Search a place", .indonesia: "Cari tempat"],
        "Find nearby accessible spots": [.english: "Find nearby accessible spots", .indonesia: "Cari tempat aksesibel terdekat"],
        "Malls": [.english: "Malls", .indonesia: "Mall"],
        "Restaurants": [.english: "Restaurants", .indonesia: "Restoran"],
        "Cafes": [.english: "Cafes", .indonesia: "Kafe"],
        "Parks": [.english: "Parks", .indonesia: "Taman"],
        "Hotels": [.english: "Hotels", .indonesia: "Hotel"],
        "Transit": [.english: "Transit", .indonesia: "Transit"],
        "Malls of Bali": [.english: "Malls of Bali", .indonesia: "Mall di Bali"],
        "All accessibility": [.english: "All accessibility", .indonesia: "Semua aksesibilitas"],
        "Accessible": [.english: "Accessible", .indonesia: "Aksesibel"],
        "Moderately Accessible": [.english: "Moderately Accessible", .indonesia: "Cukup Aksesibel"],
        "Not Accessible": [.english: "Not Accessible", .indonesia: "Tidak Aksesibel"],
        "Inaccessible": [.english: "Inaccessible", .indonesia: "Tidak Aksesibel"],
        "No Data Available": [.english: "No Data Available", .indonesia: "Data Tidak Tersedia"],
        "No data available": [.english: "No data available", .indonesia: "Data tidak tersedia"],
        "No Data": [.english: "No Data", .indonesia: "Tidak Ada Data"],

        // Place Detail Screen
        "GALLERY": [.english: "GALLERY", .indonesia: "GALERI"],
        "NOT ACCESSIBLE": [.english: "NOT ACCESSIBLE", .indonesia: "TIDAK AKSESIBEL"],
        "ACCESSIBLE": [.english: "ACCESSIBLE", .indonesia: "AKSESIBEL"],
        "MODERATELY ACCESSIBLE": [.english: "MODERATELY ACCESSIBLE", .indonesia: "CUKUP AKSESIBEL"],
        "NO DATA AVAILABLE": [.english: "NO DATA AVAILABLE", .indonesia: "DATA TIDAK TERSEDIA"],
        "Add New Review": [.english: "Add New Review", .indonesia: "Tambah Ulasan Baru"],
        "Facilities": [.english: "Facilities", .indonesia: "Fasilitas"],
        "Entrance": [.english: "Entrance", .indonesia: "Pintu Masuk"],
        "Elevator": [.english: "Elevator", .indonesia: "Lift"],
        "Toilet": [.english: "Toilet", .indonesia: "Toilet"],
        "RAMP": [.english: "RAMP", .indonesia: "RAMP"],
        "HANDRAIL": [.english: "HANDRAIL", .indonesia: "PEGANGAN TANGAN (RAIL)"],
        "AUTOMATIC DOORS": [.english: "AUTOMATIC DOORS", .indonesia: "PINTU OTOMATIS"],
        "MANUAL DOORS": [.english: "MANUAL DOORS", .indonesia: "PINTU MANUAL"],
        "SECURITY ASSISTANCE": [.english: "SECURITY ASSISTANCE", .indonesia: "BANTUAN SATPAM"],
        "Security Assistance": [.english: "Security Assistance", .indonesia: "Bantuan Satpam"],
        "SECURITY": [.english: "SECURITY", .indonesia: "BANTUAN SATPAM"],
        "Handrail": [.english: "Handrail", .indonesia: "Pegangan Tangan (Rail)"],
        "RAIL": [.english: "RAIL", .indonesia: "PEGANGAN TANGAN (RAIL)"],
        "Rail": [.english: "Rail", .indonesia: "Pegangan Tangan (Rail)"],
        "Rails": [.english: "Rails", .indonesia: "Pegangan Tangan (Rail)"],
        "WIDE ENTRANCE": [.english: "WIDE ENTRANCE", .indonesia: "PINTU LEBAR"],
        "REACHABLE BUTTONS": [.english: "REACHABLE BUTTONS", .indonesia: "TOMBOL TERJANGKAU"],
        "This place doesn't has an accessible toilet yet": [
            .english: "This place doesn't has an accessible toilet yet",
            .indonesia: "Tempat ini belum memiliki toilet aksesibel"
        ],

        // Contribute & Review Screens
        "Contribute": [.english: "Contribute", .indonesia: "Kontribusi"],
        "What accessible facilities does": [.english: "What accessible facilities does", .indonesia: "Fasilitas aksesibel apa yang dimiliki"],
        "have?": [.english: "have?", .indonesia: "miliki?"],
        "You can select multiple answers": [.english: "You can select multiple answers", .indonesia: "Anda dapat memilih lebih dari satu jawaban"],
        "Entrances": [.english: "Entrances", .indonesia: "Pintu Masuk"],
        "Elevators": [.english: "Elevators", .indonesia: "Lift"],
        "Accessible Toilets": [.english: "Accessible Toilets", .indonesia: "Toilet Aksesibel"],
        "Continue": [.english: "Continue", .indonesia: "Lanjutkan"],
        "Where did you enter?": [.english: "Where did you enter?", .indonesia: "Di mana Anda masuk?"],
        "Lobby": [.english: "Lobby", .indonesia: "Lobi"],
        "Basement": [.english: "Basement", .indonesia: "Basemen"],
        "What did the entrance have?": [.english: "What did the entrance have?", .indonesia: "Apa saja fasilitas di pintu masuk?"],
        "What do the elevators have?": [.english: "What do the elevators have?", .indonesia: "Apa saja fasilitas di lift?"],
        "What does the toilet have?": [.english: "What does the toilet have?", .indonesia: "Apa saja fasilitas di toilet?"],
        "GRAB BARS": [.english: "GRAB BARS", .indonesia: "PEGANGAN TANGAN (RAIL)"],
        "EMERGENCY BUTTONS": [.english: "EMERGENCY BUTTONS", .indonesia: "TOMBOL DARURAT"],
        "Photos of": [.english: "Photos of", .indonesia: "Foto"],
        "(Optional)": [.english: "(Optional)", .indonesia: "(Opsional)"],
        "Choose Existing": [.english: "Choose Existing", .indonesia: "Pilih Foto yang Ada"],
        "Take New Photo": [.english: "Take New Photo", .indonesia: "Ambil Foto Baru"],
        "Add Photo": [.english: "Add Photo", .indonesia: "Tambah Foto"],
        "Notes": [.english: "Notes", .indonesia: "Catatan"],
        "Tell us more about your experience …": [.english: "Tell us more about your experience …", .indonesia: "Ceritakan lebih banyak tentang pengalaman Anda …"],
        "Review Submitted!": [.english: "Review Submitted!", .indonesia: "Ulasan Terkirim!"],
        "Thank you for helping out!": [.english: "Thank you for helping out!", .indonesia: "Terima kasih telah membantu!"],
        "Any dropoff or ramps?": [.english: "Any dropoff or ramps?", .indonesia: "Apakah ada dropoff atau ramp?"],
        "Look for a step-free path from the curb.": [.english: "Look for a step-free path from the curb.", .indonesia: "Cari jalur tanpa anak tangga dari trotoar."],
        "Is there a rails?": [.english: "Is there a rails?", .indonesia: "Apakah ada pegangan tangan (rail)?"],
        "How easy is it to go through?": [.english: "How easy is it to go through?", .indonesia: "Seberapa mudah untuk melaluinya?"],
        "Door entrance": [.english: "Door entrance", .indonesia: "Pintu masuk"],
        "What kind of door is it?": [.english: "What kind of door is it?", .indonesia: "Pintu jenis apa ini?"],
        "Is it wide enough for a wheelchair?": [.english: "Is it wide enough for a wheelchair?", .indonesia: "Apakah cukup lebar untuk kursi roda?"],
        "Is there an elevator?": [.english: "Is there an elevator?", .indonesia: "Apakah ada lift?"],
        "Can a wheelchair get inside?": [.english: "Can a wheelchair get inside?", .indonesia: "Apakah kursi roda bisa masuk ke dalam?"],
        "What's the issue?": [.english: "What's the issue?", .indonesia: "Apa kendalanya?"],
        "Is there a disabled/accessible toilet?": [.english: "Is there a disabled/accessible toilet?", .indonesia: "Apakah ada toilet difabel/aksesibel?"],
        "Add a note": [.english: "Add a note", .indonesia: "Tambah catatan"],
        "Optional": [.english: "Optional", .indonesia: "Opsional"],
        "Add photos or a note to help other users.": [.english: "Add photos or a note to help other users.", .indonesia: "Tambah foto atau catatan untuk membantu pengguna lain."],
        "Notes about": [.english: "Notes about", .indonesia: "Catatan tentang"],
        "What should other users know?": [.english: "What should other users know?", .indonesia: "Apa yang perlu diketahui pengguna lain?"],
        "Add More Photos": [.english: "Add More Photos", .indonesia: "Tambah Foto Lainnya"]
    ]
    
    func tr(_ text: String) -> String {
        guard let options = translations[text], let localized = options[currentLanguage] else {
            return text
        }
        return localized
    }
}

extension String {
    var localized: String {
        LanguageManager.shared.tr(self)
    }
}

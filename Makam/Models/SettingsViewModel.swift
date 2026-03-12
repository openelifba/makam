import Foundation

// MARK: - UserDefaults Keys

extension UserDefaults {
    static let districtIdKey      = "makam.selectedDistrictId"
    static let districtNameKey    = "makam.selectedDistrictName"
    static let stateNameKey       = "makam.selectedStateName"
    static let countryNameKey     = "makam.selectedCountryName"

    var savedDistrictId: String?   { string(forKey: Self.districtIdKey) }
    var savedDistrictName: String? { string(forKey: Self.districtNameKey) }
    var savedStateName: String?    { string(forKey: Self.stateNameKey) }
    var savedCountryName: String?  { string(forKey: Self.countryNameKey) }
}

// MARK: - SettingsViewModel

@MainActor
class SettingsViewModel: ObservableObject {

    // MARK: Data

    @Published var countries: [ImsakiyemCountry] = []
    @Published var states: [ImsakiyemState]       = []
    @Published var districts: [ImsakiyemDistrict] = []

    // MARK: Selection

    @Published var selectedCountry: ImsakiyemCountry?
    @Published var selectedState: ImsakiyemState?
    @Published var selectedDistrict: ImsakiyemDistrict?

    // MARK: UI State

    @Published var isLoadingCountries  = false
    @Published var isLoadingStates     = false
    @Published var isLoadingDistricts  = false
    @Published var errorMessage: String?

    // MARK: - Load Countries

    func loadCountries() async {
        isLoadingCountries = true
        errorMessage = nil
        do {
            countries = try await ImsakiyemService.fetchCountries()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCountries = false
    }

    // MARK: - Select Country → load its states

    func selectCountry(_ country: ImsakiyemCountry) async {
        selectedCountry = country
        selectedState = nil
        selectedDistrict = nil
        states = []
        districts = []

        isLoadingStates = true
        errorMessage = nil
        do {
            states = try await ImsakiyemService.fetchStates(countryId: country.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingStates = false
    }

    // MARK: - Select State → load its districts

    func selectState(_ state: ImsakiyemState) async {
        selectedState = state
        selectedDistrict = nil
        districts = []

        isLoadingDistricts = true
        errorMessage = nil
        do {
            districts = try await ImsakiyemService.fetchDistricts(stateId: state.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingDistricts = false
    }

    // MARK: - Select District

    func selectDistrict(_ district: ImsakiyemDistrict) {
        selectedDistrict = district
    }

    // MARK: - Persist Selection

    func saveSettings() {
        guard let district = selectedDistrict else { return }
        let defaults = UserDefaults.standard
        defaults.set(district.id,              forKey: UserDefaults.districtIdKey)
        defaults.set(district.name,            forKey: UserDefaults.districtNameKey)
        defaults.set(selectedState?.name ?? "", forKey: UserDefaults.stateNameKey)
        defaults.set(selectedCountry?.name ?? "", forKey: UserDefaults.countryNameKey)
    }

    // MARK: - Read Current Saved Location Name (static, no instance needed)

    static func savedLocationLabel() -> String {
        let defaults = UserDefaults.standard
        if let district = defaults.savedDistrictName, !district.isEmpty { return district }
        if let state    = defaults.savedStateName,    !state.isEmpty    { return state }
        return "Ankara"
    }
}

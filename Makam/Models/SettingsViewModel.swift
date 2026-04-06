import Foundation
import WidgetKit

// MARK: - App Group

private let makamAppGroupID = "group.com.yaysoftwares.makam"

extension UserDefaults {
    static let districtIdKey      = "makam.selectedDistrictId"
    static let districtNameKey    = "makam.selectedDistrictName"
    static let stateNameKey       = "makam.selectedStateName"
    static let countryNameKey     = "makam.selectedCountryName"

    var savedDistrictId: String?   { string(forKey: Self.districtIdKey) }
    var savedDistrictName: String? { string(forKey: Self.districtNameKey) }
    var savedStateName: String?    { string(forKey: Self.stateNameKey) }
    var savedCountryName: String?  { string(forKey: Self.countryNameKey) }

    /// Shared suite used by both the app and the widget extension.
    static var appGroup: UserDefaults {
        UserDefaults(suiteName: makamAppGroupID) ?? .standard
    }
}

// MARK: - SettingsViewModel

@MainActor
class SettingsViewModel: ObservableObject {

    // MARK: Data

    @Published var countries: [EzanVaktiUlke] = []
    @Published var cities: [EzanVaktiSehir]   = []
    @Published var districts: [EzanVaktiIlce] = []

    // MARK: Selection

    @Published var selectedCountry: EzanVaktiUlke?
    @Published var selectedCity: EzanVaktiSehir?
    @Published var selectedDistrict: EzanVaktiIlce?

    // MARK: UI State

    @Published var isLoadingCountries = false
    @Published var isLoadingCities    = false
    @Published var isLoadingDistricts = false
    @Published var errorMessage: String?

    // MARK: - Load Countries

    func loadCountries() async {
        isLoadingCountries = true
        errorMessage = nil
        do {
            countries = try await EzanVaktiService.fetchCountries()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCountries = false
    }

    // MARK: - Select Country → load its cities

    func selectCountry(_ country: EzanVaktiUlke) async {
        selectedCountry = country
        selectedCity = nil
        selectedDistrict = nil
        cities = []
        districts = []

        isLoadingCities = true
        errorMessage = nil
        do {
            cities = try await EzanVaktiService.fetchCities(countryId: country.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCities = false
    }

    // MARK: - Select City → load its districts

    func selectCity(_ city: EzanVaktiSehir) async {
        selectedCity = city
        selectedDistrict = nil
        districts = []

        isLoadingDistricts = true
        errorMessage = nil
        do {
            districts = try await EzanVaktiService.fetchDistricts(cityId: city.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingDistricts = false
    }

    // MARK: - Select District

    func selectDistrict(_ district: EzanVaktiIlce) {
        selectedDistrict = district
    }

    // MARK: - Persist Selection

    func saveSettings() {
        guard let district = selectedDistrict else { return }
        for defaults in [UserDefaults.standard, UserDefaults.appGroup] {
            defaults.set(district.id,                forKey: UserDefaults.districtIdKey)
            defaults.set(district.name,              forKey: UserDefaults.districtNameKey)
            defaults.set(selectedCity?.name ?? "",   forKey: UserDefaults.stateNameKey)
            defaults.set(selectedCountry?.name ?? "", forKey: UserDefaults.countryNameKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read Current Saved Location Name (static, no instance needed)

    static func savedLocationLabel() -> String {
        let defaults = UserDefaults.standard
        if let district = defaults.savedDistrictName, !district.isEmpty { return district }
        if let city     = defaults.savedStateName,    !city.isEmpty     { return city }
        return "İstanbul"
    }

    // MARK: - Seed Default Location (Istanbul) on First Launch

    static func setDefaultLocationIfNeeded() {
        guard UserDefaults.standard.savedDistrictId == nil else { return }
        for defaults in [UserDefaults.standard, UserDefaults.appGroup] {
            defaults.set("9541",      forKey: UserDefaults.districtIdKey)
            defaults.set("İstanbul",  forKey: UserDefaults.districtNameKey)
            defaults.set("İstanbul",  forKey: UserDefaults.stateNameKey)
            defaults.set("Türkiye",   forKey: UserDefaults.countryNameKey)
        }
    }
}

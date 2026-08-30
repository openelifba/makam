import Foundation
import Combine

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
//
// NOTE: This file is compiled into BOTH the Makam app target and the
// MakamWidget extension target (see project.yml). Keep it free of
// networking/CoreLocation imports and calls — those live in
// SettingsViewModel+Location.swift, which is NOT part of MakamWidget's
// sources. Only stored properties, `@Published` declarations, and the two
// UserDefaults-only static funcs belong here.

@MainActor
class SettingsViewModel: ObservableObject {

    // MARK: Data

    @Published var countries: [Country]   = []
    @Published var cities: [City]         = []
    @Published var districts: [District]  = []

    // MARK: Selection

    @Published var selectedCountry: Country?
    @Published var selectedCity: City?
    @Published var selectedDistrict: District?

    // MARK: UI State

    @Published var isLoadingCountries = false
    @Published var isLoadingCities    = false
    @Published var isLoadingDistricts = false
    @Published var errorMessage: String?

    // MARK: Location (device coordinate, used to sort location lists nearest-first)

    /// Plain tuple (not CLLocationCoordinate2D) so this file stays free of
    /// CoreLocation — required for the MakamWidget build. See
    /// SettingsViewModel+Location.swift for how this gets populated.
    var currentLocationCoordinate: (latitude: Double, longitude: Double)?

    /// In-flight (or completed) location resolution, shared across every
    /// `loadCountries()` caller so concurrent calls join the same resolution
    /// instead of racing independent `CurrentLocationProvider` requests.
    /// Declared here (not a plain `Bool` latch) — see
    /// SettingsViewModel+Location.swift for how this gets populated/awaited.
    var locationResolutionTask: Task<(latitude: Double, longitude: Double)?, Never>?

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

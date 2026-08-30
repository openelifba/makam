// MARK: - SettingsViewModel+Location.swift
// Networking + location-resolving instance methods for SettingsViewModel.
//
// Split out of SettingsViewModel.swift because that file is also compiled
// into the MakamWidget extension target (see project.yml), which must not
// pull in MakamAPI/NetworkClient/CoreLocation. This file is NOT part of
// MakamWidget's sources.

import Foundation
import CoreLocation
import WidgetKit

extension SettingsViewModel {

    // MARK: - Load Countries

    func loadCountries() async {
        if !hasResolvedLocation {
            hasResolvedLocation = true
            if let coord = await CurrentLocationProvider().requestOneShotLocation() {
                currentLocationCoordinate = (coord.latitude, coord.longitude)
            }
        }

        isLoadingCountries = true
        errorMessage = nil
        do {
            countries = try await MakamAPI.shared.fetchCountries(
                lat: currentLocationCoordinate?.latitude,
                lon: currentLocationCoordinate?.longitude
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCountries = false
    }

    // MARK: - Select Country → load its cities

    func selectCountry(_ country: Country) async {
        selectedCountry = country
        selectedCity = nil
        selectedDistrict = nil
        cities = []
        districts = []

        isLoadingCities = true
        errorMessage = nil
        do {
            cities = try await MakamAPI.shared.fetchCities(
                countryId: country.id,
                lat: currentLocationCoordinate?.latitude,
                lon: currentLocationCoordinate?.longitude
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCities = false
    }

    // MARK: - Select City → load its districts

    func selectCity(_ city: City) async {
        selectedCity = city
        selectedDistrict = nil
        districts = []

        isLoadingDistricts = true
        errorMessage = nil
        do {
            districts = try await MakamAPI.shared.fetchDistricts(
                cityId: city.id,
                lat: currentLocationCoordinate?.latitude,
                lon: currentLocationCoordinate?.longitude
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingDistricts = false
    }

    // MARK: - Select District

    func selectDistrict(_ district: District) {
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
}

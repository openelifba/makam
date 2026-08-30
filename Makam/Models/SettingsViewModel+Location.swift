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
        isLoadingCountries = true
        errorMessage = nil

        let coordinate = await resolvedLocation()

        do {
            countries = try await MakamAPI.shared.fetchCountries(
                lat: coordinate?.latitude,
                lon: coordinate?.longitude
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCountries = false
    }

    // MARK: - Resolve Current Location (shared across concurrent callers)
    //
    // `loadCountries()` is called from two places in quick succession (the
    // Settings root `.task` and the CountryPickerView `.task`). Rather than
    // each call racing its own `CurrentLocationProvider` request — which let
    // a fast second caller see a "resolved" flag before the first request's
    // location had actually arrived — every caller awaits the SAME in-flight
    // `Task`, so they all resolve to the same coordinate (or all correctly
    // get `nil` together if location isn't available).

    private func resolvedLocation() async -> (latitude: Double, longitude: Double)? {
        if let existing = locationResolutionTask {
            return await existing.value
        }
        let task = Task<(latitude: Double, longitude: Double)?, Never> {
            guard let coord = await CurrentLocationProvider().requestOneShotLocation() else { return nil }
            return (coord.latitude, coord.longitude)
        }
        locationResolutionTask = task
        let result = await task.value
        currentLocationCoordinate = result
        return result
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

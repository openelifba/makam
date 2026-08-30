// MARK: - LocationModels.swift
// Location hierarchy models (Country → City → District) returned by the
// Makam backend's `/locations/*` endpoints. These replace the previous
// direct-to-third-party (`EzanVaktiUlke`/`EzanVaktiSehir`/`EzanVaktiIlce`) models.
//
// NOTE: This file is also compiled into the MakamWidget extension target
// (see project.yml) because SettingsViewModel.swift references these types
// and is itself shared with the widget. Keep this file free of any
// networking/CoreLocation dependencies.

import Foundation

struct Country: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String
}

struct City: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String
}

struct District: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String
    let latitude: Double?
    let longitude: Double?
}
